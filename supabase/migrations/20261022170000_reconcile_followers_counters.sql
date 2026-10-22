-- Recalcula os agregados de seguidores a partir da relação canônica.
-- Evita que exclusões repetidas ou dados antigos deixem contadores negativos.
UPDATE public.usuarios AS u
SET
  seguidores = (
    SELECT count(*)::integer
    FROM public.seguidores AS s
    WHERE s.seguido_id = u.id
  ),
  seguindo = (
    SELECT count(*)::integer
    FROM public.seguidores AS s
    WHERE s.seguidor_id = u.id
  );

CREATE OR REPLACE FUNCTION public.atualizar_contador_seguidores()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.usuarios
    SET seguidores = GREATEST(0, COALESCE(seguidores, 0) + 1)
    WHERE id = NEW.seguido_id;
    UPDATE public.usuarios
    SET seguindo = GREATEST(0, COALESCE(seguindo, 0) + 1)
    WHERE id = NEW.seguidor_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.usuarios
    SET seguidores = GREATEST(0, COALESCE(seguidores, 0) - 1)
    WHERE id = OLD.seguido_id;
    UPDATE public.usuarios
    SET seguindo = GREATEST(0, COALESCE(seguindo, 0) - 1)
    WHERE id = OLD.seguidor_id;
  END IF;
  RETURN NULL;
END;
$function$;
