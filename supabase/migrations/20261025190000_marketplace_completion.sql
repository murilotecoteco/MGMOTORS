-- Fechamento dos casos de uso do marketplace (UC09, UC15, UC20, UC22 e UC25).
-- As operações administrativas permanecem protegidas por is_admin().

CREATE OR REPLACE FUNCTION public.proteger_status_anuncios()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NOT public.is_admin() THEN
      NEW.status := 'pendente';
    END IF;
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status AND NOT public.is_admin() THEN
    -- O proprietário pode concluir a venda, mas não pode aprovar, rejeitar ou
    -- reabrir o anúncio por alteração direta no cliente.
    IF NEW.status = 'vendido'::public.status_anuncio
       AND OLD.status = 'ativo'::public.status_anuncio
       AND OLD.usuario_id = auth.uid() THEN
      NEW.data_venda := COALESCE(NEW.data_venda, now());
    ELSE
      NEW.status := OLD.status;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.marcar_anuncio_vendido(p_anuncio_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  alterado integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN false;
  END IF;

  UPDATE public.anuncios
     SET status = 'vendido'::public.status_anuncio,
         data_venda = COALESCE(data_venda, now()),
         pausado = false
   WHERE id = p_anuncio_id
     AND usuario_id = auth.uid()
     AND status = 'ativo'::public.status_anuncio
     AND COALESCE(excluido_em IS NULL, true);

  GET DIAGNOSTICS alterado = ROW_COUNT;
  RETURN alterado = 1;
END;
$function$;

REVOKE ALL ON FUNCTION public.marcar_anuncio_vendido(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.marcar_anuncio_vendido(uuid) TO authenticated;

-- UC15: o painel pode administrar a taxonomia já usada pelo cadastro.
DROP POLICY IF EXISTS "marcas admin insert" ON public.marcas;
DROP POLICY IF EXISTS "marcas admin update" ON public.marcas;
DROP POLICY IF EXISTS "marcas admin delete" ON public.marcas;
CREATE POLICY "marcas admin insert" ON public.marcas FOR INSERT TO authenticated
  WITH CHECK (public.is_admin());
CREATE POLICY "marcas admin update" ON public.marcas FOR UPDATE TO authenticated
  USING (public.is_admin()) WITH CHECK (public.is_admin());
CREATE POLICY "marcas admin delete" ON public.marcas FOR DELETE TO authenticated
  USING (public.is_admin());

DROP POLICY IF EXISTS "modelos admin insert" ON public.modelos;
DROP POLICY IF EXISTS "modelos admin update" ON public.modelos;
DROP POLICY IF EXISTS "modelos admin delete" ON public.modelos;
CREATE POLICY "modelos admin insert" ON public.modelos FOR INSERT TO authenticated
  WITH CHECK (public.is_admin());
CREATE POLICY "modelos admin update" ON public.modelos FOR UPDATE TO authenticated
  USING (public.is_admin()) WITH CHECK (public.is_admin());
CREATE POLICY "modelos admin delete" ON public.modelos FOR DELETE TO authenticated
  USING (public.is_admin());

-- UC25: formulário público, leitura apenas pelo painel administrativo.
CREATE TABLE IF NOT EXISTS public.contatos_site (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id uuid REFERENCES public.usuarios(id) ON DELETE SET NULL,
  nome text NOT NULL CHECK (char_length(trim(nome)) BETWEEN 2 AND 120),
  email text NOT NULL CHECK (char_length(trim(email)) BETWEEN 5 AND 254),
  assunto text NOT NULL CHECK (char_length(trim(assunto)) BETWEEN 2 AND 120),
  mensagem text NOT NULL CHECK (char_length(trim(mensagem)) BETWEEN 10 AND 4000),
  status text NOT NULL DEFAULT 'pendente' CHECK (status IN ('pendente', 'em_atendimento', 'respondido', 'arquivado')),
  criado_em timestamptz NOT NULL DEFAULT now(),
  atualizado_em timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.contatos_site ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "contatos site insert publico" ON public.contatos_site;
DROP POLICY IF EXISTS "contatos site admin select" ON public.contatos_site;
DROP POLICY IF EXISTS "contatos site admin update" ON public.contatos_site;
CREATE POLICY "contatos site insert publico" ON public.contatos_site
  FOR INSERT TO anon, authenticated
  WITH CHECK (
    status = 'pendente'
    AND (usuario_id IS NULL OR usuario_id = auth.uid())
  );
CREATE POLICY "contatos site admin select" ON public.contatos_site
  FOR SELECT TO authenticated USING (public.is_admin());
CREATE POLICY "contatos site admin update" ON public.contatos_site
  FOR UPDATE TO authenticated
  USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP TRIGGER IF EXISTS contatos_site_updated_at ON public.contatos_site;
CREATE TRIGGER contatos_site_updated_at
  BEFORE UPDATE ON public.contatos_site
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

GRANT INSERT ON public.contatos_site TO anon, authenticated;
GRANT SELECT, UPDATE ON public.contatos_site TO authenticated;

-- RPC versionada para filtros avançados, mantendo a RPC antiga compatível.
CREATE OR REPLACE FUNCTION public.get_anuncios_marketplace_paginado_v2(
  p_usuario_id uuid DEFAULT NULL,
  p_limit integer DEFAULT 12,
  p_offset integer DEFAULT 0,
  p_tipo_veiculo text DEFAULT NULL,
  p_marca_id uuid DEFAULT NULL,
  p_modelo_id uuid DEFAULT NULL,
  p_estado text DEFAULT NULL,
  p_busca text DEFAULT NULL,
  p_preco_min numeric DEFAULT NULL,
  p_preco_max numeric DEFAULT NULL,
  p_ano_min integer DEFAULT NULL,
  p_ano_max integer DEFAULT NULL,
  p_quilometragem_max integer DEFAULT NULL,
  p_combustivel text DEFAULT NULL,
  p_cambio text DEFAULT NULL,
  p_cor text DEFAULT NULL,
  p_latitude double precision DEFAULT NULL,
  p_longitude double precision DEFAULT NULL,
  p_raio_km numeric DEFAULT NULL,
  p_ordenacao text DEFAULT 'recente',
  p_seed text DEFAULT ''
)
RETURNS TABLE (
  id uuid, usuario_id uuid, marca_id uuid, modelo_id uuid, preco numeric,
  ano_fabricacao integer, ano_modelo integer, quilometragem integer, cor text,
  cidade text, estado text, cidade_display text, status text, curtidas integer,
  pausado boolean, latitude double precision, longitude double precision,
  criado_em timestamptz, marca_nome text, modelo_nome text, marca_texto text,
  modelo_texto text, foto_principal text, vendedor_foto text,
  usuario_curtiu boolean, tipo_veiculo text, total_count bigint
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT a.id, a.usuario_id, a.marca_id, a.modelo_id, a.preco,
    a.ano_fabricacao, a.ano_modelo, a.quilometragem, a.cor, a.cidade,
    a.estado::text, a.cidade_display, a.status::text, a.curtidas, a.pausado,
    a.latitude, a.longitude, a.criado_em, marc.nome, mod.nome,
    a.marca_texto, a.modelo_texto, foto.url_foto, u.foto,
    CASE WHEN p_usuario_id IS NULL THEN false ELSE EXISTS (
      SELECT 1 FROM public.curtidas_anuncio ca
       WHERE ca.anuncio_id = a.id AND ca.usuario_id = p_usuario_id
    ) END,
    COALESCE(a.tipo_veiculo, 'carro'), count(*) OVER ()
  FROM public.anuncios a
  LEFT JOIN public.marcas marc ON marc.id = a.marca_id
  LEFT JOIN public.modelos mod ON mod.id = a.modelo_id
  LEFT JOIN public.usuarios u ON u.id = a.usuario_id
  LEFT JOIN LATERAL (
    SELECT fa.url_foto FROM public.fotos_anuncio fa
     WHERE fa.anuncio_id = a.id ORDER BY fa.ordem ASC LIMIT 1
  ) foto ON true
  WHERE a.status = 'ativo'::public.status_anuncio
    AND COALESCE(a.pausado, false) = false
    AND (p_tipo_veiculo IS NULL OR a.tipo_veiculo = p_tipo_veiculo)
    AND (p_marca_id IS NULL OR a.marca_id = p_marca_id)
    AND (p_modelo_id IS NULL OR a.modelo_id = p_modelo_id)
    AND (p_estado IS NULL OR a.estado::text = upper(p_estado))
    AND (p_preco_min IS NULL OR a.preco >= p_preco_min)
    AND (p_preco_max IS NULL OR a.preco <= p_preco_max)
    AND (p_ano_min IS NULL OR a.ano_modelo >= p_ano_min)
    AND (p_ano_max IS NULL OR a.ano_modelo <= p_ano_max)
    AND (p_quilometragem_max IS NULL OR a.quilometragem <= p_quilometragem_max)
    AND (p_combustivel IS NULL OR a.combustivel::text = p_combustivel)
    AND (p_cambio IS NULL OR a.cambio::text = p_cambio)
    AND (p_cor IS NULL OR a.cor ILIKE '%' || p_cor || '%')
    AND (p_busca IS NULL OR p_busca = '' OR
      concat_ws(' ', a.marca_texto, a.modelo_texto, marc.nome, mod.nome) ILIKE '%' || p_busca || '%')
    AND (p_latitude IS NULL OR p_longitude IS NULL OR p_raio_km IS NULL OR
      a.latitude IS NULL OR a.longitude IS NULL OR
      6371.0 * acos(least(1.0, greatest(-1.0,
        cos(radians(p_latitude)) * cos(radians(a.latitude)) * cos(radians(a.longitude) - radians(p_longitude)) +
        sin(radians(p_latitude)) * sin(radians(a.latitude))
      ))) <= greatest(0, p_raio_km))
  ORDER BY
    CASE WHEN p_ordenacao = 'curtidas' THEN a.curtidas END DESC NULLS LAST,
    CASE WHEN p_ordenacao = 'preco_asc' THEN a.preco END ASC NULLS LAST,
    CASE WHEN p_ordenacao = 'preco_desc' THEN a.preco END DESC NULLS LAST,
    CASE WHEN p_ordenacao = 'recente' THEN a.criado_em END DESC NULLS LAST,
    CASE WHEN p_ordenacao = 'aleatorio' THEN md5(a.id::text || p_seed) END ASC,
    a.id ASC
  LIMIT least(greatest(coalesce(p_limit, 12), 1), 50)
  OFFSET greatest(coalesce(p_offset, 0), 0);
$$;

REVOKE ALL ON FUNCTION public.get_anuncios_marketplace_paginado_v2(uuid, integer, integer, text, uuid, uuid, text, text, numeric, numeric, integer, integer, integer, text, text, text, double precision, double precision, numeric, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_anuncios_marketplace_paginado_v2(uuid, integer, integer, text, uuid, uuid, text, text, numeric, numeric, integer, integer, integer, text, text, text, double precision, double precision, numeric, text, text) TO anon, authenticated;
