-- Speed up the substring searches used by the marketplace RPC.
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_anuncios_marca_texto_trgm
  ON public.anuncios USING gin (marca_texto gin_trgm_ops)
  WHERE marca_texto IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_anuncios_modelo_texto_trgm
  ON public.anuncios USING gin (modelo_texto gin_trgm_ops)
  WHERE modelo_texto IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_anuncios_cor_trgm
  ON public.anuncios USING gin (cor gin_trgm_ops)
  WHERE cor IS NOT NULL;
