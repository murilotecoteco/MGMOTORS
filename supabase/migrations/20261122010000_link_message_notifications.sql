-- Liga cada notificação de mensagem à sua origem para que a leitura da conversa
-- diminua apenas o badge daquela conversa.
ALTER TABLE public.notificacoes
  ADD COLUMN IF NOT EXISTS mensagem_id uuid
  REFERENCES public.mensagens(id) ON DELETE CASCADE;

-- Recupera a relação para alertas antigos somente quando há uma única mensagem
-- compatível: mesmo destinatário, mesmo conteúdo exibido e mesmo instante de
-- criação. Linhas ambíguas continuam sem vínculo para não marcar uma conversa
-- errada como lida.
WITH candidatos AS (
  SELECT n.id AS notificacao_id, min(m.id) AS mensagem_id
  FROM public.notificacoes AS n
  JOIN public.mensagens AS m
    ON m.destinatario_id = n.usuario_id
   AND left(coalesce(m.conteudo, 'Você recebeu uma nova mensagem.'), 160) = n.mensagem
   AND m.data_envio BETWEEN n.criado_em - interval '1 second' AND n.criado_em + interval '1 second'
  WHERE n.tipo = 'mensagem' AND n.mensagem_id IS NULL
  GROUP BY n.id
  HAVING count(*) = 1
), mensagens_unicas AS (
  SELECT mensagem_id
  FROM candidatos
  GROUP BY mensagem_id
  HAVING count(*) = 1
)
UPDATE public.notificacoes AS n
SET mensagem_id = c.mensagem_id
FROM candidatos AS c
JOIN mensagens_unicas AS mu ON mu.mensagem_id = c.mensagem_id
WHERE n.id = c.notificacao_id;

CREATE UNIQUE INDEX IF NOT EXISTS idx_notificacoes_mensagem_id
  ON public.notificacoes (mensagem_id)
  WHERE mensagem_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.criar_notificacao_mensagem()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.destinatario_id IS NOT NULL AND NEW.remetente_id IS DISTINCT FROM NEW.destinatario_id THEN
    INSERT INTO public.notificacoes (usuario_id, tipo, titulo, mensagem, link, mensagem_id)
    VALUES (
      NEW.destinatario_id,
      'mensagem',
      'Nova mensagem',
      left(COALESCE(NEW.conteudo, 'Você recebeu uma nova mensagem.'), 160),
      '/MG-MENSAGENS/mensagens.html',
      NEW.id
    );
  END IF;
  RETURN NEW;
END;
$$;

-- Um usuário só precisa reconhecer a leitura; os demais campos são produzidos
-- pelo trigger e não devem ser alteráveis pelo navegador.
REVOKE UPDATE ON public.notificacoes FROM authenticated;
GRANT UPDATE (lida) ON public.notificacoes TO authenticated;
