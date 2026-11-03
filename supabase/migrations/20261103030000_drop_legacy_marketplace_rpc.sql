-- The frontend uses get_anuncios_marketplace_paginado_v2 exclusively.
-- Remove the older public RPC so it cannot remain an unintended attack surface.
DROP FUNCTION IF EXISTS public.get_anuncios_marketplace_paginado(
  uuid, integer, integer, text, uuid, text, text, numeric, numeric,
  double precision, double precision, numeric, text, text
);
