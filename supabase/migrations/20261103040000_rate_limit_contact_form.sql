-- Persisted anti-abuse state for the public contact form.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.contato_rate_limits (
  chave text PRIMARY KEY,
  janela_inicio timestamptz NOT NULL DEFAULT now(),
  tentativas integer NOT NULL DEFAULT 0 CHECK (tentativas >= 0),
  atualizado_em timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.contato_rate_limits ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.contato_rate_limits FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.enviar_contato(
  p_nome text,
  p_email text,
  p_assunto text,
  p_mensagem text,
  p_website text DEFAULT ''
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $$
DECLARE
  headers jsonb;
  ip_text text;
  ip_hash text;
  email_key text;
  ip_key text;
  agora timestamptz := clock_timestamp();
  janela timestamptz;
  tentativas integer;
  contato_id uuid;
BEGIN
  IF nullif(trim(p_website), '') IS NOT NULL THEN
    RETURN jsonb_build_object('accepted', false, 'reason', 'invalid_submission');
  END IF;

  IF length(trim(coalesce(p_nome, ''))) NOT BETWEEN 2 AND 120
     OR length(trim(coalesce(p_email, ''))) NOT BETWEEN 5 AND 254
     OR length(trim(coalesce(p_assunto, ''))) NOT BETWEEN 1 AND 120
     OR length(trim(coalesce(p_mensagem, ''))) NOT BETWEEN 10 AND 4000
     OR trim(p_email) !~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' THEN
    RETURN jsonb_build_object('accepted', false, 'reason', 'invalid_submission');
  END IF;

  headers := coalesce(nullif(current_setting('request.headers', true), '')::jsonb, '{}'::jsonb);
  ip_text := split_part(coalesce(headers->>'x-forwarded-for', headers->>'x-real-ip', 'unknown'), ',', 1);
  ip_hash := encode(digest(trim(ip_text), 'sha256'), 'hex');
  email_key := 'email:' || lower(trim(p_email));
  ip_key := 'ip:' || ip_hash;

  INSERT INTO public.contato_rate_limits (chave, janela_inicio, tentativas, atualizado_em)
  VALUES (email_key, agora, 1, agora)
  ON CONFLICT (chave) DO UPDATE SET
    janela_inicio = CASE WHEN public.contato_rate_limits.janela_inicio <= agora - interval '15 minutes' THEN agora ELSE public.contato_rate_limits.janela_inicio END,
    tentativas = CASE WHEN public.contato_rate_limits.janela_inicio <= agora - interval '15 minutes' THEN 1 ELSE public.contato_rate_limits.tentativas + 1 END,
    atualizado_em = agora
  RETURNING janela_inicio, tentativas INTO janela, tentativas;
  IF tentativas > 3 AND janela > agora - interval '15 minutes' THEN
    RETURN jsonb_build_object('accepted', false, 'reason', 'rate_limited', 'retry_after_seconds', 900);
  END IF;

  INSERT INTO public.contato_rate_limits (chave, janela_inicio, tentativas, atualizado_em)
  VALUES (ip_key, agora, 1, agora)
  ON CONFLICT (chave) DO UPDATE SET
    janela_inicio = CASE WHEN public.contato_rate_limits.janela_inicio <= agora - interval '15 minutes' THEN agora ELSE public.contato_rate_limits.janela_inicio END,
    tentativas = CASE WHEN public.contato_rate_limits.janela_inicio <= agora - interval '15 minutes' THEN 1 ELSE public.contato_rate_limits.tentativas + 1 END,
    atualizado_em = agora
  RETURNING janela_inicio, tentativas INTO janela, tentativas;
  IF tentativas > 12 AND janela > agora - interval '15 minutes' THEN
    RETURN jsonb_build_object('accepted', false, 'reason', 'rate_limited', 'retry_after_seconds', 900);
  END IF;

  INSERT INTO public.contatos_site (usuario_id, nome, email, assunto, mensagem, status)
  VALUES (auth.uid(), trim(p_nome), trim(p_email), trim(p_assunto), trim(p_mensagem), 'pendente')
  RETURNING id INTO contato_id;

  RETURN jsonb_build_object('accepted', true, 'id', contato_id);
END;
$$;

REVOKE ALL ON FUNCTION public.enviar_contato(text, text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.enviar_contato(text, text, text, text, text) TO anon, authenticated;
REVOKE INSERT ON public.contatos_site FROM anon, authenticated;
