-- Keep the public RPC signature compatible with the existing frontend, but do
-- not trust the caller-provided user id inside a SECURITY DEFINER function.
-- The liked-state must always be evaluated for the authenticated session.
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
    CASE WHEN auth.uid() IS NULL THEN false ELSE EXISTS (
      SELECT 1 FROM public.curtidas_anuncio ca
       WHERE ca.anuncio_id = a.id AND ca.usuario_id = auth.uid()
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
