-- Mantém o histórico do anúncio, mas diferencia uma remoção voluntária de uma
-- pausa temporária. Anúncios removidos não devem aparecer como reativáveis.
ALTER TABLE public.anuncios
  ADD COLUMN IF NOT EXISTS excluido_em timestamptz;

CREATE INDEX IF NOT EXISTS anuncios_usuario_excluido_em_idx
  ON public.anuncios (usuario_id, excluido_em)
  WHERE excluido_em IS NULL;

COMMENT ON COLUMN public.anuncios.excluido_em IS
  'Momento da exclusão lógica solicitada pelo proprietário; preserva histórico sem permitir reativação pela interface.';
