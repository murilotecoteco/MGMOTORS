ALTER TABLE public.usuarios
  ADD COLUMN IF NOT EXISTS terms_accepted_at timestamptz,
  ADD COLUMN IF NOT EXISTS privacy_accepted_at timestamptz,
  ADD COLUMN IF NOT EXISTS terms_version text,
  ADD COLUMN IF NOT EXISTS privacy_version text;

-- Mantém a migration aplicável também em projetos cujo dump de contexto não
-- incluiu as funções auxiliares do schema.
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT coalesce(
    (SELECT moderador FROM public.usuarios WHERE id = auth.uid()),
    false
  );
$function$;

-- O perfil é criado pelo trigger após o cadastro no Auth. Clientes anônimos
-- não precisam ter permissão para inserir linhas arbitrárias em usuarios.
DROP POLICY IF EXISTS "Sistema cria usuarios" ON public.usuarios;
REVOKE INSERT ON public.usuarios FROM anon;

-- O frontend público precisa apenas dos dados de apresentação do perfil.
-- E-mail, telefone, preferências e flags administrativas permanecem na tabela
-- original para uso do próprio usuário e da administração.
DROP POLICY IF EXISTS "Todos veem usuarios" ON public.usuarios;
DROP POLICY IF EXISTS "usuarios select publico" ON public.usuarios;

CREATE POLICY "usuarios select proprio ou admin" ON public.usuarios
  FOR SELECT
  TO authenticated
  USING ((id = auth.uid()) OR public.is_admin());

DROP VIEW IF EXISTS public.usuarios_publicos;
CREATE VIEW public.usuarios_publicos AS
SELECT
  id,
  nome,
  foto,
  capa_foto,
  cidade,
  estado,
  bio,
  site,
  instagram,
  seguidores,
  seguindo,
  nota_media,
  total_avaliacoes,
  criado_em
FROM public.usuarios;

GRANT SELECT ON public.usuarios_publicos TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.proteger_consentimento_legal()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_admin()
     AND current_setting('app.legal_consent_update', true) IS DISTINCT FROM 'on' THEN
    NEW.terms_accepted_at := OLD.terms_accepted_at;
    NEW.privacy_accepted_at := OLD.privacy_accepted_at;
    NEW.terms_version := OLD.terms_version;
    NEW.privacy_version := OLD.privacy_version;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_proteger_consentimento_legal ON public.usuarios;
CREATE TRIGGER trg_proteger_consentimento_legal
  BEFORE UPDATE ON public.usuarios
  FOR EACH ROW
  EXECUTE FUNCTION public.proteger_consentimento_legal();

CREATE OR REPLACE FUNCTION public.registrar_aceite_legal(
  p_terms_version text,
  p_privacy_version text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'É necessário estar autenticado para registrar o aceite.';
  END IF;

  IF nullif(trim(p_terms_version), '') IS NULL
     OR nullif(trim(p_privacy_version), '') IS NULL THEN
    RAISE EXCEPTION 'As versões dos documentos são obrigatórias.';
  END IF;

  PERFORM set_config('app.legal_consent_update', 'on', true);

  UPDATE public.usuarios
  SET terms_accepted_at = now(),
      privacy_accepted_at = now(),
      terms_version = trim(p_terms_version),
      privacy_version = trim(p_privacy_version),
      atualizado_em = now()
  WHERE id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Perfil do usuário não encontrado.';
  END IF;
END;
$function$;

REVOKE ALL ON FUNCTION public.registrar_aceite_legal(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.registrar_aceite_legal(text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  INSERT INTO public.usuarios (
    id,
    email,
    nome,
    terms_accepted_at,
    privacy_accepted_at,
    terms_version,
    privacy_version
  )
  VALUES (
    new.id,
    new.email,
    COALESCE(
      new.raw_user_meta_data->>'nome',
      new.raw_user_meta_data->>'full_name',
      new.raw_user_meta_data->>'name',
      split_part(new.email, '@', 1)
    ),
    CASE WHEN new.raw_user_meta_data->>'legal_terms_accepted' = 'true' THEN now() END,
    CASE WHEN new.raw_user_meta_data->>'legal_privacy_accepted' = 'true' THEN now() END,
    NULLIF(new.raw_user_meta_data->>'terms_version', ''),
    NULLIF(new.raw_user_meta_data->>'privacy_version', '')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN new;
END;
$function$;
