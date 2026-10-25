-- Registra a origem da pausa para que desbanir um usuário não reative
-- anúncios pausados voluntariamente ou removidos por moderação.
ALTER TABLE public.anuncios
  ADD COLUMN IF NOT EXISTS pausado_por_ban boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_anuncios_usuario_pausados_por_ban
  ON public.anuncios (usuario_id)
  WHERE pausado_por_ban = true;
