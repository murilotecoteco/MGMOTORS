-- RF14/UC21: notificacoes persistentes geradas por mensagens novas.
-- Aplicar primeiro em staging e executar supabase/tests/rls-security-check.sh.
DO $$
BEGIN
  IF to_regclass('public.usuarios') IS NULL
     OR to_regclass('public.mensagens') IS NULL THEN
    RAISE EXCEPTION 'RF14/UC21 abortado: public.usuarios e public.mensagens são pré-requisitos.';
  END IF;
END
$$;

CREATE TABLE IF NOT EXISTS public.notificacoes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id uuid NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  tipo text NOT NULL DEFAULT 'mensagem',
  titulo text NOT NULL,
  mensagem text NOT NULL,
  link text,
  lida boolean NOT NULL DEFAULT false,
  criado_em timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.notificacoes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS notificacoes_select_proprias ON public.notificacoes;
CREATE POLICY notificacoes_select_proprias ON public.notificacoes
  FOR SELECT TO authenticated USING (usuario_id = auth.uid());

DROP POLICY IF EXISTS notificacoes_update_proprias ON public.notificacoes;
CREATE POLICY notificacoes_update_proprias ON public.notificacoes
  FOR UPDATE TO authenticated USING (usuario_id = auth.uid())
  WITH CHECK (usuario_id = auth.uid());

CREATE INDEX IF NOT EXISTS idx_notificacoes_usuario_data
  ON public.notificacoes (usuario_id, criado_em DESC);

CREATE OR REPLACE FUNCTION public.criar_notificacao_mensagem()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.destinatario_id IS NOT NULL AND NEW.remetente_id IS DISTINCT FROM NEW.destinatario_id THEN
    INSERT INTO public.notificacoes (usuario_id, tipo, titulo, mensagem, link)
    VALUES (
      NEW.destinatario_id,
      'mensagem',
      'Nova mensagem',
      left(COALESCE(NEW.conteudo, 'Você recebeu uma nova mensagem.'), 160),
      '/MG-MENSAGENS/mensagens.html'
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notificar_nova_mensagem ON public.mensagens;
CREATE TRIGGER trg_notificar_nova_mensagem
  AFTER INSERT ON public.mensagens
  FOR EACH ROW EXECUTE FUNCTION public.criar_notificacao_mensagem();

GRANT SELECT, UPDATE ON public.notificacoes TO authenticated;
