-- Policies de SELECT da mesma tabela se combinam com OR: a policy
-- "anuncios select" (USING apenas status = 'ativo') anulava a restrição de
-- pausado da policy "Todos veem anuncios ativos". Resultado: anúncio pausado
-- ou removido logicamente (status ainda 'ativo') continuava legível por
-- .eq("id", ...) para qualquer anon, inclusive na página de detalhe por
-- link direto. A policy única abaixo une as duas regras.
DO $$
BEGIN
  IF to_regclass('public.anuncios') IS NULL THEN
    RAISE EXCEPTION 'pre-condicao falhou: tabela public.anuncios inexistente';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc
    WHERE proname = 'is_admin' AND pronamespace = 'public'::regnamespace
  ) THEN
    RAISE EXCEPTION 'pre-condicao falhou: funcao public.is_admin() inexistente';
  END IF;
END
$$;

DROP POLICY IF EXISTS "anuncios select" ON public.anuncios;
CREATE POLICY "anuncios select" ON public.anuncios
  FOR SELECT
  TO "anon", "authenticated"
  USING (
    ((status = 'ativo'::public.status_anuncio) AND (pausado IS NULL OR pausado = false))
    OR (usuario_id = auth.uid())
    OR (public.is_admin() = true)
  );

-- A policy "Todos veem anuncios ativos" (TO PUBLIC) já carrega a mesma
-- regra visível para o público: status ativo e não pausado, mais a leitura
-- do próprio anúncio pelo dono. Nenhuma policy de SELECT com USING(true)
-- pode ser criada daqui em diante, senão ela anula estas duas.

DO $$
DECLARE
  policy_using text;
BEGIN
  SELECT pg_get_expr(pol.polqual, pol.polrelid)
    INTO policy_using
    FROM pg_policy pol
   WHERE pol.polname = 'anuncios select'
     AND pol.polrelid = 'public.anuncios'::regclass;
  IF policy_using IS NULL THEN
    RAISE EXCEPTION 'validacao falhou: policy "anuncios select" nao encontrada';
  END IF;
  IF policy_using NOT LIKE '%pausado%' THEN
    RAISE EXCEPTION 'validacao falhou: policy "anuncios select" sem filtro de pausado: %', policy_using;
  END IF;
END
$$;
