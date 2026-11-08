-- =============================================================================
-- ENCONTROS DE CARROS
-- Usuário marca encontro -> administrador aprova/recusa -> aparece na lista e
-- no mapa -> outros usuários ingressam (limite de vagas + requisitos).
-- Idempotente. Aplicar primeiro em staging.
-- =============================================================================
DO $$
BEGIN
  IF to_regclass('public.usuarios') IS NULL
     OR to_regclass('public.encontros') IS NULL
     OR to_regclass('public.encontros_confirmados') IS NULL
     OR to_regclass('public.notificacoes') IS NULL THEN
    RAISE EXCEPTION 'Migration encontros abortada: usuarios, encontros, encontros_confirmados e notificacoes são pré-requisitos.';
  END IF;
END
$$;

-- -----------------------------------------------------------------------------
-- 1. Colunas novas
-- -----------------------------------------------------------------------------
ALTER TABLE public.encontros
  ADD COLUMN IF NOT EXISTS limite_participantes integer,
  ADD COLUMN IF NOT EXISTS requisitos_lista text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS motivo_recusa text,
  ADD COLUMN IF NOT EXISTS moderado_por uuid,
  ADD COLUMN IF NOT EXISTS moderado_em timestamptz,
  ADD COLUMN IF NOT EXISTS atualizado_em timestamptz NOT NULL DEFAULT now();

ALTER TABLE public.encontros_confirmados
  ADD COLUMN IF NOT EXISTS veiculo_info text,
  ADD COLUMN IF NOT EXISTS requisitos_aceitos_em timestamptz;

-- Todo encontro novo nasce pendente (antes o padrão era 'approved').
ALTER TABLE public.encontros ALTER COLUMN status SET DEFAULT 'pending';

ALTER TABLE public.encontros DROP CONSTRAINT IF EXISTS encontros_limite_check;
ALTER TABLE public.encontros ADD CONSTRAINT encontros_limite_check
  CHECK (limite_participantes IS NULL OR limite_participantes BETWEEN 1 AND 5000) NOT VALID;

ALTER TABLE public.encontros DROP CONSTRAINT IF EXISTS encontros_coord_check;
ALTER TABLE public.encontros ADD CONSTRAINT encontros_coord_check
  CHECK ((lat IS NULL OR lat BETWEEN -90 AND 90) AND (lng IS NULL OR lng BETWEEN -180 AND 180)) NOT VALID;

ALTER TABLE public.encontros DROP CONSTRAINT IF EXISTS encontros_requisitos_lista_check;
ALTER TABLE public.encontros ADD CONSTRAINT encontros_requisitos_lista_check
  CHECK (cardinality(requisitos_lista) <= 8) NOT VALID;

CREATE INDEX IF NOT EXISTS idx_encontros_listagem ON public.encontros (status, ativo, data);
CREATE INDEX IF NOT EXISTS idx_encontros_criador ON public.encontros (criador_id);
CREATE INDEX IF NOT EXISTS idx_encontros_conf_user ON public.encontros_confirmados (user_id);

-- -----------------------------------------------------------------------------
-- 2. Consentimento legal vigente (LGPD) — versão exigida pelo banco.
--    Ao publicar novos Termos/Privacidade, altere aqui e em legalConsent.js.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.consentimento_legal_atual(p_uid uuid DEFAULT auth.uid())
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $$
  SELECT coalesce((
    SELECT terms_version = '2.0' AND privacy_version = '2.0'
       AND terms_accepted_at IS NOT NULL AND privacy_accepted_at IS NOT NULL
    FROM public.usuarios WHERE id = p_uid
  ), false);
$$;
REVOKE ALL ON FUNCTION public.consentimento_legal_atual(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.consentimento_legal_atual(uuid) TO authenticated;

-- -----------------------------------------------------------------------------
-- 3. Triggers de validação / proteção da moderação
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.encontros_validar_insert()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE
  item text;
  hoje date := (now() AT TIME ZONE 'America/Sao_Paulo')::date;
BEGIN
  IF NOT public.is_admin() THEN
    IF NOT public.consentimento_legal_atual(NEW.criador_id) THEN
      RAISE EXCEPTION 'MG: aceite os Termos de Uso e a Política de Privacidade atuais para marcar um encontro.';
    END IF;
    IF EXISTS (SELECT 1 FROM public.usuarios WHERE id = NEW.criador_id AND banido IS TRUE) THEN
      RAISE EXCEPTION 'MG: conta suspensa.';
    END IF;
    IF (SELECT count(*) FROM public.encontros
        WHERE criador_id = NEW.criador_id AND ativo IS TRUE
          AND status IN ('pending','approved') AND data >= hoje) >= 5 THEN
      RAISE EXCEPTION 'MG: você já tem 5 encontros ativos. Aguarde a realização ou cancele algum.';
    END IF;
  END IF;

  NEW.status := 'pending';
  NEW.motivo_recusa := NULL;
  NEW.moderado_por := NULL;
  NEW.moderado_em := NULL;
  NEW.ativo := true;

  IF NEW.data < hoje THEN RAISE EXCEPTION 'MG: a data do encontro não pode estar no passado.'; END IF;
  IF NEW.lat IS NULL OR NEW.lng IS NULL THEN RAISE EXCEPTION 'MG: marque o local exato no mapa.'; END IF;
  IF length(trim(coalesce(NEW.nome,''))) NOT BETWEEN 3 AND 100 THEN RAISE EXCEPTION 'MG: o nome deve ter de 3 a 100 caracteres.'; END IF;
  IF length(trim(coalesce(NEW.local_nome,''))) NOT BETWEEN 3 AND 140 THEN RAISE EXCEPTION 'MG: informe o nome do local (3 a 140 caracteres).'; END IF;
  IF length(trim(coalesce(NEW.cidade,''))) < 2 OR NEW.estado IS NULL THEN RAISE EXCEPTION 'MG: informe cidade e estado.'; END IF;
  IF length(coalesce(NEW.descricao,'')) > 1500 OR length(coalesce(NEW.regras,'')) > 1500 OR length(coalesce(NEW.requisitos,'')) > 600 THEN
    RAISE EXCEPTION 'MG: texto muito longo.';
  END IF;
  FOREACH item IN ARRAY NEW.requisitos_lista LOOP
    IF length(trim(item)) NOT BETWEEN 2 AND 120 THEN RAISE EXCEPTION 'MG: cada requisito deve ter de 2 a 120 caracteres.'; END IF;
  END LOOP;
  NEW.estado := upper(NEW.estado);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_encontros_validar_insert ON public.encontros;
CREATE TRIGGER trg_encontros_validar_insert
  BEFORE INSERT ON public.encontros
  FOR EACH ROW EXECUTE FUNCTION public.encontros_validar_insert();

CREATE OR REPLACE FUNCTION public.encontros_proteger_update()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE
  item text;
  total integer;
  conteudo_mudou boolean;
BEGIN
  NEW.atualizado_em := now();
  -- Moderação só pelo RPC moderar_encontro (que liga a flag abaixo) ou por service_role.
  IF current_setting('app.encontro_moderacao', true) IS DISTINCT FROM 'on'
     AND coalesce(auth.role(), '') <> 'service_role' THEN
    NEW.status := OLD.status;
    NEW.motivo_recusa := OLD.motivo_recusa;
    NEW.moderado_por := OLD.moderado_por;
    NEW.moderado_em := OLD.moderado_em;
    NEW.criador_id := OLD.criador_id;

    conteudo_mudou :=
      NEW.nome IS DISTINCT FROM OLD.nome OR NEW.descricao IS DISTINCT FROM OLD.descricao
      OR NEW.regras IS DISTINCT FROM OLD.regras OR NEW.requisitos IS DISTINCT FROM OLD.requisitos
      OR NEW.requisitos_lista IS DISTINCT FROM OLD.requisitos_lista
      OR NEW.tipo_veiculo IS DISTINCT FROM OLD.tipo_veiculo OR NEW.data IS DISTINCT FROM OLD.data
      OR NEW.hora IS DISTINCT FROM OLD.hora OR NEW.local_nome IS DISTINCT FROM OLD.local_nome
      OR NEW.cidade IS DISTINCT FROM OLD.cidade OR NEW.estado IS DISTINCT FROM OLD.estado
      OR NEW.lat IS DISTINCT FROM OLD.lat OR NEW.lng IS DISTINCT FROM OLD.lng;

    -- Mudou algo relevante de um encontro já avaliado: volta para análise.
    IF conteudo_mudou AND OLD.status <> 'pending' THEN
      NEW.status := 'pending';
    END IF;
  END IF;

  IF NEW.limite_participantes IS NOT NULL THEN
    SELECT count(*) INTO total FROM public.encontros_confirmados WHERE encontro_id = NEW.id;
    IF NEW.limite_participantes < total THEN
      RAISE EXCEPTION 'MG: o limite não pode ser menor que o número de inscritos (%).', total;
    END IF;
  END IF;
  IF NEW.requisitos_lista IS DISTINCT FROM OLD.requisitos_lista THEN
    FOREACH item IN ARRAY NEW.requisitos_lista LOOP
      IF length(trim(item)) NOT BETWEEN 2 AND 120 THEN RAISE EXCEPTION 'MG: cada requisito deve ter de 2 a 120 caracteres.'; END IF;
    END LOOP;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_encontros_proteger_update ON public.encontros;
CREATE TRIGGER trg_encontros_proteger_update
  BEFORE UPDATE ON public.encontros
  FOR EACH ROW EXECUTE FUNCTION public.encontros_proteger_update();

-- Conta excluída: encontros dela deixam de aparecer.
CREATE OR REPLACE FUNCTION public.encontros_desativar_da_conta()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
BEGIN
  UPDATE public.encontros SET ativo = false WHERE criador_id = OLD.id;
  RETURN OLD;
END;
$$;
DROP TRIGGER IF EXISTS trg_encontros_desativar_da_conta ON public.usuarios;
CREATE TRIGGER trg_encontros_desativar_da_conta
  BEFORE DELETE ON public.usuarios
  FOR EACH ROW EXECUTE FUNCTION public.encontros_desativar_da_conta();

-- -----------------------------------------------------------------------------
-- 4. RLS e privilégios mínimos
-- -----------------------------------------------------------------------------
ALTER TABLE public.encontros ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.encontros_confirmados ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "enc_insert" ON public.encontros;
CREATE POLICY "enc_insert" ON public.encontros FOR INSERT TO authenticated
  WITH CHECK (criador_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "enc_select" ON public.encontros;
CREATE POLICY "enc_select" ON public.encontros FOR SELECT TO authenticated
  USING ((ativo = true AND status = 'approved') OR criador_id = (SELECT auth.uid()) OR public.is_admin());

DROP POLICY IF EXISTS "enc_update" ON public.encontros;
CREATE POLICY "enc_update" ON public.encontros FOR UPDATE TO authenticated
  USING (criador_id = (SELECT auth.uid()))
  WITH CHECK (criador_id = (SELECT auth.uid()));

-- Inscrições: ninguém lista inscritos de terceiros. Cada um vê as suas; o
-- organizador vê as do próprio encontro; admin vê tudo. Inserir só via RPC.
DROP POLICY IF EXISTS "conf_select" ON public.encontros_confirmados;
CREATE POLICY "conf_select" ON public.encontros_confirmados FOR SELECT TO authenticated
  USING (
    user_id = (SELECT auth.uid()) OR public.is_admin()
    OR EXISTS (SELECT 1 FROM public.encontros e
               WHERE e.id = encontro_id AND e.criador_id = (SELECT auth.uid()))
  );
DROP POLICY IF EXISTS "conf_insert" ON public.encontros_confirmados;
DROP POLICY IF EXISTS "conf_delete" ON public.encontros_confirmados;
CREATE POLICY "conf_delete" ON public.encontros_confirmados FOR DELETE TO authenticated
  USING (user_id = (SELECT auth.uid()));

REVOKE ALL ON TABLE public.encontros, public.encontros_confirmados FROM anon, authenticated;
GRANT SELECT ON public.encontros TO authenticated;
GRANT INSERT (criador_id, nome, descricao, regras, requisitos, requisitos_lista, tipo_veiculo,
              data, hora, local_nome, cidade, estado, lat, lng, limite_participantes)
  ON public.encontros TO authenticated;
GRANT UPDATE (nome, descricao, regras, requisitos, requisitos_lista, tipo_veiculo, data, hora,
              local_nome, cidade, estado, lat, lng, limite_participantes, ativo)
  ON public.encontros TO authenticated;
GRANT SELECT, DELETE ON public.encontros_confirmados TO authenticated;

-- -----------------------------------------------------------------------------
-- 5. RPCs
-- -----------------------------------------------------------------------------
-- Lista pública (anônimo inclusive): só aprovados, ativos e de hoje em diante.
CREATE OR REPLACE FUNCTION public.listar_encontros_publicos()
RETURNS TABLE (
  id uuid, criador_id uuid, criador_nome text, nome text, descricao text, regras text,
  requisitos text, requisitos_lista text[], tipo_veiculo text, data date, hora time,
  local_nome text, cidade text, estado text, lat numeric, lng numeric,
  limite_participantes integer, total_participantes integer, usuario_participa boolean
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $$
  SELECT e.id, e.criador_id, u.nome, e.nome, e.descricao, e.regras, e.requisitos,
         e.requisitos_lista, e.tipo_veiculo, e.data, e.hora, e.local_nome, e.cidade,
         e.estado::text, e.lat, e.lng, e.limite_participantes,
         (SELECT count(*)::int FROM public.encontros_confirmados c WHERE c.encontro_id = e.id),
         EXISTS (SELECT 1 FROM public.encontros_confirmados c
                 WHERE c.encontro_id = e.id AND c.user_id = auth.uid())
  FROM public.encontros e
  LEFT JOIN public.usuarios_publicos u ON u.id = e.criador_id
  WHERE e.ativo IS TRUE AND e.status = 'approved'
    AND e.lat IS NOT NULL AND e.lng IS NOT NULL
    AND e.data >= (now() AT TIME ZONE 'America/Sao_Paulo')::date
  ORDER BY e.data, e.hora NULLS LAST
  LIMIT 500;
$$;
REVOKE ALL ON FUNCTION public.listar_encontros_publicos() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.listar_encontros_publicos() TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.entrar_encontro(
  p_encontro_id uuid, p_veiculo_info text DEFAULT NULL, p_aceita_requisitos boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE
  uid uuid := auth.uid();
  enc public.encontros%ROWTYPE;
  total integer;
  tem_requisito boolean;
  nome_user text;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'MG: faça login para participar.'; END IF;
  IF NOT public.consentimento_legal_atual(uid) THEN
    RAISE EXCEPTION 'MG: aceite os Termos de Uso e a Política de Privacidade atuais para participar.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.usuarios WHERE id = uid AND banido IS TRUE) THEN
    RAISE EXCEPTION 'MG: conta suspensa.';
  END IF;

  SELECT * INTO enc FROM public.encontros WHERE id = p_encontro_id FOR UPDATE;
  IF NOT FOUND OR enc.ativo IS NOT TRUE OR enc.status <> 'approved' THEN
    RAISE EXCEPTION 'MG: encontro indisponível.';
  END IF;
  IF enc.data < (now() AT TIME ZONE 'America/Sao_Paulo')::date THEN
    RAISE EXCEPTION 'MG: este encontro já aconteceu.';
  END IF;
  IF enc.criador_id = uid THEN
    RAISE EXCEPTION 'MG: você é o organizador deste encontro.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.encontros_confirmados WHERE encontro_id = enc.id AND user_id = uid) THEN
    RETURN jsonb_build_object('ok', true, 'ja_inscrito', true);
  END IF;

  tem_requisito := cardinality(enc.requisitos_lista) > 0 OR enc.tipo_veiculo <> 'todos'
                   OR nullif(trim(coalesce(enc.requisitos,'')), '') IS NOT NULL;
  IF tem_requisito AND p_aceita_requisitos IS NOT TRUE THEN
    RAISE EXCEPTION 'MG: confirme que leu e vai cumprir os requisitos do encontro.';
  END IF;
  IF enc.tipo_veiculo <> 'todos' AND length(trim(coalesce(p_veiculo_info,''))) < 3 THEN
    RAISE EXCEPTION 'MG: informe o veículo que você levará (modelo e ano).';
  END IF;
  IF length(coalesce(p_veiculo_info,'')) > 120 THEN
    RAISE EXCEPTION 'MG: descrição do veículo muito longa.';
  END IF;

  SELECT count(*) INTO total FROM public.encontros_confirmados WHERE encontro_id = enc.id;
  IF enc.limite_participantes IS NOT NULL AND total >= enc.limite_participantes THEN
    RAISE EXCEPTION 'MG: encontro lotado.';
  END IF;

  INSERT INTO public.encontros_confirmados (encontro_id, user_id, veiculo_info, requisitos_aceitos_em)
  VALUES (enc.id, uid, nullif(trim(p_veiculo_info), ''), CASE WHEN tem_requisito THEN now() END);

  SELECT nome INTO nome_user FROM public.usuarios WHERE id = uid;
  IF enc.criador_id IS NOT NULL THEN
    INSERT INTO public.notificacoes (usuario_id, tipo, titulo, mensagem, link)
    VALUES (enc.criador_id, 'encontro', 'Novo participante',
            left(coalesce(nome_user, 'Alguém') || ' vai ao seu encontro "' || enc.nome || '".', 160),
            '/MG-ENCONTROS/encontros.html');
  END IF;

  RETURN jsonb_build_object('ok', true, 'total_participantes', total + 1);
END;
$$;
REVOKE ALL ON FUNCTION public.entrar_encontro(uuid, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.entrar_encontro(uuid, text, boolean) TO authenticated;

CREATE OR REPLACE FUNCTION public.moderar_encontro(
  p_encontro_id uuid, p_decisao text, p_motivo text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE
  enc public.encontros%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'MG: apenas administradores podem moderar encontros.';
  END IF;
  IF p_decisao NOT IN ('approved', 'rejected') THEN
    RAISE EXCEPTION 'MG: decisão inválida.';
  END IF;
  IF p_decisao = 'rejected' AND length(trim(coalesce(p_motivo, ''))) < 3 THEN
    RAISE EXCEPTION 'MG: informe o motivo da recusa.';
  END IF;

  SELECT * INTO enc FROM public.encontros WHERE id = p_encontro_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'MG: encontro não encontrado.'; END IF;

  PERFORM set_config('app.encontro_moderacao', 'on', true);
  UPDATE public.encontros
  SET status = p_decisao,
      motivo_recusa = CASE WHEN p_decisao = 'rejected' THEN left(trim(p_motivo), 300) END,
      moderado_por = auth.uid(), moderado_em = now()
  WHERE id = p_encontro_id;

  IF enc.criador_id IS NOT NULL THEN
    INSERT INTO public.notificacoes (usuario_id, tipo, titulo, mensagem, link)
    VALUES (
      enc.criador_id, 'encontro',
      CASE WHEN p_decisao = 'approved' THEN 'Encontro aprovado' ELSE 'Encontro recusado' END,
      left(CASE WHEN p_decisao = 'approved'
                THEN 'Seu encontro "' || enc.nome || '" já aparece na lista e no mapa.'
                ELSE 'Seu encontro "' || enc.nome || '" foi recusado: ' || trim(p_motivo) END, 160),
      '/MG-ENCONTROS/encontros.html');
  END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.moderar_encontro(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.moderar_encontro(uuid, text, text) TO authenticated;

DO $$
BEGIN
  IF has_function_privilege('anon', 'public.entrar_encontro(uuid, text, boolean)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.moderar_encontro(uuid, text, text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'hardening falhou: anon pode executar RPC de encontros';
  END IF;
END
$$;

