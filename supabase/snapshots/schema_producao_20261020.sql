


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE SCHEMA IF NOT EXISTS "storage";


ALTER SCHEMA "storage" OWNER TO "supabase_admin";


CREATE TYPE "public"."status_anuncio" AS ENUM (
    'ativo',
    'pendente',
    'vendido',
    'expirado'
);


ALTER TYPE "public"."status_anuncio" OWNER TO "postgres";


CREATE TYPE "public"."status_proposta" AS ENUM (
    'pendente',
    'aceita',
    'recusada',
    'cancelada'
);


ALTER TYPE "public"."status_proposta" OWNER TO "postgres";


CREATE TYPE "public"."tipo_cambio" AS ENUM (
    'manual',
    'automatico',
    'automatizado'
);


ALTER TYPE "public"."tipo_cambio" OWNER TO "postgres";


CREATE TYPE "public"."tipo_combustivel" AS ENUM (
    'gasolina',
    'alcool',
    'flex',
    'diesel',
    'eletrico',
    'hibrido'
);


ALTER TYPE "public"."tipo_combustivel" OWNER TO "postgres";


CREATE TYPE "storage"."buckettype" AS ENUM (
    'STANDARD',
    'ANALYTICS',
    'VECTOR'
);


ALTER TYPE "storage"."buckettype" OWNER TO "supabase_storage_admin";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."usuarios" (
    "id" "uuid" NOT NULL,
    "email" "text",
    "nome" "text",
    "foto" "text",
    "idade" integer,
    "cidade" "text",
    "estado" "text",
    "telefone" "text",
    "bio" "text",
    "criado_em" timestamp with time zone DEFAULT "now"(),
    "atualizado_em" timestamp with time zone DEFAULT "now"(),
    "capa_foto" "text",
    "data_nascimento" "date",
    "site" "text",
    "instagram" "text",
    "seguidores" integer DEFAULT 0,
    "seguindo" integer DEFAULT 0,
    "bloqueado" boolean DEFAULT false,
    "moderador" boolean DEFAULT false,
    "banido" boolean DEFAULT false,
    "preferencias" "jsonb" DEFAULT '{}'::"jsonb",
    "nota_media" numeric(3,2) DEFAULT 0,
    "total_avaliacoes" integer DEFAULT 0,
    "is_admin" boolean DEFAULT false,
    "terms_accepted_at" timestamp with time zone,
    "privacy_accepted_at" timestamp with time zone,
    "terms_version" "text",
    "privacy_version" "text"
);


ALTER TABLE "public"."usuarios" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_atualizar_usuario"("p_email" "text", "p_moderador" boolean DEFAULT NULL::boolean, "p_banido" boolean DEFAULT NULL::boolean, "p_nota_media" numeric DEFAULT NULL::numeric, "p_total_avaliacoes" integer DEFAULT NULL::integer) RETURNS "public"."usuarios"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  resultado public.usuarios;
begin
  alter table public.usuarios disable trigger trg_proteger_campos_usuarios;

  update public.usuarios
  set
    moderador        = coalesce(p_moderador, moderador),
    banido           = coalesce(p_banido, banido),
    nota_media       = coalesce(p_nota_media, nota_media),
    total_avaliacoes = coalesce(p_total_avaliacoes, total_avaliacoes)
  where email = p_email
  returning * into resultado;

  alter table public.usuarios enable trigger trg_proteger_campos_usuarios;

  if resultado.id is null then
    raise notice 'Nenhum usuário encontrado com email %', p_email;
  end if;

  return resultado;
exception when others then
  -- garante que o trigger volta a ligar mesmo se o update falhar
  alter table public.usuarios enable trigger trg_proteger_campos_usuarios;
  raise;
end;
$$;


ALTER FUNCTION "public"."admin_atualizar_usuario"("p_email" "text", "p_moderador" boolean, "p_banido" boolean, "p_nota_media" numeric, "p_total_avaliacoes" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."atualizar_contador_seguidores"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE usuarios SET seguidores = COALESCE(seguidores, 0) + 1 WHERE id = NEW.seguido_id;
        UPDATE usuarios SET seguindo = COALESCE(seguindo, 0) + 1 WHERE id = NEW.seguidor_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE usuarios SET seguidores = COALESCE(seguidores, 0) - 1 WHERE id = OLD.seguido_id;
        UPDATE usuarios SET seguindo = COALESCE(seguindo, 0) - 1 WHERE id = OLD.seguidor_id;
    END IF;
    RETURN NULL;
END;
$$;


ALTER FUNCTION "public"."atualizar_contador_seguidores"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."atualizar_conversa"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    u1 UUID;
    u2 UUID;
BEGIN
    u1 := LEAST(NEW.remetente_id, NEW.destinatario_id);
    u2 := GREATEST(NEW.remetente_id, NEW.destinatario_id);
    INSERT INTO conversas (usuario1_id, usuario2_id, anuncio_id, carro_info, ultima_mensagem, ultima_mensagem_data)
    VALUES (u1, u2, NEW.anuncio_id, NEW.carro_info, NEW.conteudo, NEW.data_envio)
    ON CONFLICT (usuario1_id, usuario2_id, anuncio_id)
    DO UPDATE SET ultima_mensagem = NEW.conteudo, ultima_mensagem_data = NEW.data_envio;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."atualizar_conversa"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."checar_cooldown_anuncio"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  ultimo_anuncio TIMESTAMPTZ;
  segundos_passados NUMERIC;
BEGIN
  SELECT MAX(criado_em) INTO ultimo_anuncio
  FROM public.anuncios
  WHERE usuario_id = NEW.usuario_id;

  IF ultimo_anuncio IS NOT NULL THEN
    segundos_passados := EXTRACT(EPOCH FROM (NOW() - ultimo_anuncio));
    IF segundos_passados < 15 THEN
      RAISE EXCEPTION 'Aguarde % segundos antes de publicar outro anúncio.', CEIL(15 - segundos_passados);
    END IF;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."checar_cooldown_anuncio"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."criar_config_usuario"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    INSERT INTO config_usuario (usuario_id, tema) VALUES (NEW.id, 'claro')
    ON CONFLICT (usuario_id) DO NOTHING;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."criar_config_usuario"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."criar_tabela_carrinho"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    CREATE TABLE IF NOT EXISTS carrinho_itens (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        usuario_id uuid REFERENCES usuarios(id) ON DELETE CASCADE NOT NULL,
        anuncio_id uuid REFERENCES anuncios(id) ON DELETE CASCADE NOT NULL,
        criado_em timestamp DEFAULT now(),
        UNIQUE(usuario_id, anuncio_id)
    );

    ALTER TABLE carrinho_itens ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "Usuarios gerenciam seus carrinhos" ON carrinho_itens;
    CREATE POLICY "Usuarios gerenciam seus carrinhos" ON carrinho_itens FOR ALL USING (auth.uid() = usuario_id);
    
    -- Força reload do schema
    NOTIFY pgrst, 'reload schema';
END;
$$;


ALTER FUNCTION "public"."criar_tabela_carrinho"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."decrementar_curtidas"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    UPDATE anuncios SET curtidas = GREATEST(COALESCE(curtidas, 0) - 1, 0) WHERE id = OLD.anuncio_id;
    RETURN OLD;
END;
$$;


ALTER FUNCTION "public"."decrementar_curtidas"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."decrementar_curtidas_anuncio"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    UPDATE anuncios SET curtidas = curtidas - 1 WHERE id = OLD.anuncio_id;
    RETURN OLD;
END;
$$;


ALTER FUNCTION "public"."decrementar_curtidas_anuncio"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."decrementar_curtidas_post"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    UPDATE posts_usuario SET curtidas = curtidas - 1 WHERE id = OLD.post_id;
    RETURN OLD;
END;
$$;


ALTER FUNCTION "public"."decrementar_curtidas_post"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_anuncios_marketplace"("usuario_id_param" "uuid" DEFAULT NULL::"uuid") RETURNS TABLE("id" "uuid", "usuario_id" "uuid", "marca_id" "uuid", "modelo_id" "uuid", "preco" numeric, "ano_fabricacao" integer, "ano_modelo" integer, "quilometragem" integer, "cor" "text", "cidade" "text", "estado" "text", "cidade_display" "text", "status" "text", "curtidas" integer, "pausado" boolean, "latitude" double precision, "longitude" double precision, "criado_em" timestamp with time zone, "marca_nome" "text", "modelo_nome" "text", "marca_texto" "text", "modelo_texto" "text", "foto_principal" "text", "vendedor_foto" "text", "usuario_curtiu" boolean, "tipo_veiculo" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    a.id,
    a.usuario_id,
    a.marca_id,
    a.modelo_id,
    a.preco,
    a.ano_fabricacao,
    a.ano_modelo,
    a.quilometragem,
    a.cor,
    a.cidade,
    a.estado::text,
    a.cidade_display,
    a.status::text,
    a.curtidas,
    a.pausado,
    a.latitude,
    a.longitude,
    a.criado_em,
    marc.nome    AS marca_nome,
    mod.nome     AS modelo_nome,
    a.marca_texto,
    a.modelo_texto,
    (
      SELECT fa.url_foto
      FROM public.fotos_anuncio fa
      WHERE fa.anuncio_id = a.id
      ORDER BY fa.ordem ASC
      LIMIT 1
    ) AS foto_principal,
    u.foto       AS vendedor_foto,
    CASE
      WHEN usuario_id_param IS NULL THEN FALSE
      ELSE EXISTS(
        SELECT 1
        FROM public.curtidas_anuncio ca
        WHERE ca.anuncio_id = a.id
          AND ca.usuario_id = usuario_id_param
      )
    END AS usuario_curtiu,
    COALESCE(a.tipo_veiculo, 'carro') AS tipo_veiculo
  FROM public.anuncios a
  LEFT JOIN public.marcas marc ON marc.id = a.marca_id
  LEFT JOIN public.modelos mod  ON mod.id  = a.modelo_id
  LEFT JOIN public.usuarios u   ON u.id    = a.usuario_id
  WHERE a.status = 'ativo'
    AND (a.pausado = FALSE OR a.pausado IS NULL)
  ORDER BY a.criado_em DESC;
END;
$$;


ALTER FUNCTION "public"."get_anuncios_marketplace"("usuario_id_param" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."incrementar_curtidas"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    UPDATE anuncios SET curtidas = COALESCE(curtidas, 0) + 1 WHERE id = NEW.anuncio_id;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."incrementar_curtidas"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."incrementar_curtidas_anuncio"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    UPDATE anuncios SET curtidas = curtidas + 1 WHERE id = NEW.anuncio_id;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."incrementar_curtidas_anuncio"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."incrementar_curtidas_post"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    UPDATE posts_usuario SET curtidas = curtidas + 1 WHERE id = NEW.post_id;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."incrementar_curtidas_post"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_admin"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT coalesce(
    (SELECT moderador FROM public.usuarios WHERE id = auth.uid()),
    false
  );
$$;


ALTER FUNCTION "public"."is_admin"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."limpar_dependencias_antes_excluir_anuncio"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  delete from public.mensagens        where anuncio_id = old.id;
  delete from public.curtidas_anuncio where anuncio_id = old.id;
  delete from public.fotos_anuncio    where anuncio_id = old.id;
  -- Limpa denúncias feitas sobre esse anúncio (tipo='anuncio' e alvo_id = id
  -- do anúncio). Sem isso não bloqueia o delete (alvo_id é polimórfico, sem
  -- FK de verdade), mas fica lixo referenciando um anúncio que não existe
  -- mais e pode confundir a tela de denúncias do MG-DEV.
  delete from public.denuncias where tipo = 'anuncio' and alvo_id = old.id;
  return old;
end;
$$;


ALTER FUNCTION "public"."limpar_dependencias_antes_excluir_anuncio"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."promover_moderador"("p_email" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  -- Se foi chamada por alguém autenticado via API que NÃO é admin,
  -- barra aqui (dupla proteção, além do fix do trigger acima).
  if auth.uid() is not null and not public.is_admin() then
    raise exception 'Apenas administradores podem promover moderadores.';
  end if;

  update public.usuarios
  set moderador = true
  where email = p_email;
end;
$$;


ALTER FUNCTION "public"."promover_moderador"("p_email" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."proteger_campos_sensiveis_usuarios"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not public.is_admin() then
    new.banido := old.banido;
    new.moderador := old.moderador;
    new.nota_media := old.nota_media;
    new.total_avaliacoes := old.total_avaliacoes;
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."proteger_campos_sensiveis_usuarios"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."proteger_consentimento_legal"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."proteger_consentimento_legal"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."proteger_conteudo_mensagens"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not public.is_admin() then
    new.conteudo := old.conteudo;
    new.remetente_id := old.remetente_id;
    new.destinatario_id := old.destinatario_id;
    new.anuncio_id := old.anuncio_id;
    new.carro_info := old.carro_info;
    new.tipo := old.tipo;
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."proteger_conteudo_mensagens"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."proteger_status_anuncios"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if tg_op = 'INSERT' then
    if not public.is_admin() then
      new.status := 'pendente';
    end if;
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if new.status is distinct from old.status and not public.is_admin() then
      new.status := old.status;
    end if;
    return new;
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."proteger_status_anuncios"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."registrar_aceite_legal"("p_terms_version" "text", "p_privacy_version" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."registrar_aceite_legal"("p_terms_version" "text", "p_privacy_version" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.atualizado_em = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."verificar_cooldown_anuncio"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  ultimo_anuncio timestamptz;
  segundos_restantes numeric;
begin
  -- Admin/moderador pode publicar sem cooldown (útil pra teste e suporte)
  if public.is_admin() then
    return new;
  end if;

  select max(criado_em) into ultimo_anuncio
  from public.anuncios
  where usuario_id = new.usuario_id;

  if ultimo_anuncio is not null and now() - ultimo_anuncio < interval '15 seconds' then
    segundos_restantes := ceil(extract(epoch from (interval '15 seconds' - (now() - ultimo_anuncio))));
    raise exception 'Aguarde % segundos antes de publicar outro anúncio.', segundos_restantes;
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."verificar_cooldown_anuncio"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "storage"."allow_any_operation"("expected_operations" "text"[]) RETURNS boolean
    LANGUAGE "sql" STABLE
    AS $$
  WITH current_operation AS (
    SELECT storage.operation() AS raw_operation
  ),
  normalized AS (
    SELECT CASE
      WHEN raw_operation LIKE 'storage.%' THEN substr(raw_operation, 9)
      ELSE raw_operation
    END AS current_operation
    FROM current_operation
  )
  SELECT EXISTS (
    SELECT 1
    FROM normalized n
    CROSS JOIN LATERAL unnest(expected_operations) AS expected_operation
    WHERE expected_operation IS NOT NULL
      AND expected_operation <> ''
      AND n.current_operation = CASE
        WHEN expected_operation LIKE 'storage.%' THEN substr(expected_operation, 9)
        ELSE expected_operation
      END
  );
$$;


ALTER FUNCTION "storage"."allow_any_operation"("expected_operations" "text"[]) OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."allow_only_operation"("expected_operation" "text") RETURNS boolean
    LANGUAGE "sql" STABLE
    AS $$
  WITH current_operation AS (
    SELECT storage.operation() AS raw_operation
  ),
  normalized AS (
    SELECT
      CASE
        WHEN raw_operation LIKE 'storage.%' THEN substr(raw_operation, 9)
        ELSE raw_operation
      END AS current_operation,
      CASE
        WHEN expected_operation LIKE 'storage.%' THEN substr(expected_operation, 9)
        ELSE expected_operation
      END AS requested_operation
    FROM current_operation
  )
  SELECT CASE
    WHEN requested_operation IS NULL OR requested_operation = '' THEN FALSE
    ELSE COALESCE(current_operation = requested_operation, FALSE)
  END
  FROM normalized;
$$;


ALTER FUNCTION "storage"."allow_only_operation"("expected_operation" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."can_insert_object"("bucketid" "text", "name" "text", "owner" "uuid", "metadata" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  INSERT INTO "storage"."objects" ("bucket_id", "name", "owner", "metadata") VALUES (bucketid, name, owner, metadata);
  -- hack to rollback the successful insert
  RAISE sqlstate 'PT200' using
  message = 'ROLLBACK',
  detail = 'rollback successful insert';
END
$$;


ALTER FUNCTION "storage"."can_insert_object"("bucketid" "text", "name" "text", "owner" "uuid", "metadata" "jsonb") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."enforce_bucket_lifecycle_service_role"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'pg_catalog'
    AS $$
BEGIN
  IF current_user::text IS DISTINCT FROM TG_ARGV[0]
     AND (
       OLD.lifecycle_configuration IS DISTINCT FROM NEW.lifecycle_configuration
       OR OLD.lifecycle_configuration_generation IS DISTINCT FROM NEW.lifecycle_configuration_generation
     ) THEN
    -- AFTER runs only after caller RLS has accepted the proposed row. The API
    -- recognizes this specific error after rolling back its permission probe;
    -- direct non-service writes still fail and cannot persist the change.
    RAISE EXCEPTION 'bucket control columns may only be changed by the configured storage service role'
      USING ERRCODE = 'PST01',
            SCHEMA = TG_TABLE_SCHEMA,
            TABLE = TG_TABLE_NAME,
            CONSTRAINT = TG_NAME;
  END IF;

  RETURN NULL;
END;
$$;


ALTER FUNCTION "storage"."enforce_bucket_lifecycle_service_role"() OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."enforce_bucket_name_length"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
    if length(new.name) > 100 then
        raise exception 'bucket name "%" is too long (% characters). Max is 100.', new.name, length(new.name);
    end if;
    return new;
end;
$$;


ALTER FUNCTION "storage"."enforce_bucket_name_length"() OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."extension"("name" "text") RETURNS "text"
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
DECLARE
    _parts text[];
    _filename text;
BEGIN
    -- Split on "/" to get path segments
    SELECT string_to_array(name, '/') INTO _parts;
    -- Get the last path segment (the actual filename)
    SELECT _parts[array_length(_parts, 1)] INTO _filename;
    -- Extract extension: reverse, split on '.', then reverse again
    RETURN reverse(split_part(reverse(_filename), '.', 1));
END
$$;


ALTER FUNCTION "storage"."extension"("name" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."filename"("name" "text") RETURNS "text"
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
DECLARE
    _parts text[];
BEGIN
    SELECT string_to_array(name, '/') INTO _parts;
    RETURN _parts[array_length(_parts, 1)];
END
$$;


ALTER FUNCTION "storage"."filename"("name" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."foldername"("name" "text") RETURNS "text"[]
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
DECLARE
    _parts text[];
BEGIN
    -- Split on "/" to get path segments
    SELECT string_to_array(name, '/') INTO _parts;
    -- Return everything except the last segment
    RETURN _parts[1 : array_length(_parts,1) - 1];
END
$$;


ALTER FUNCTION "storage"."foldername"("name" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."get_common_prefix"("p_key" "text", "p_prefix" "text", "p_delimiter" "text") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE
    AS $$
SELECT CASE
    WHEN p_delimiter <> ''
         AND position(p_delimiter IN substring(p_key FROM length(p_prefix) + 1)) > 0
    THEN left(
        p_key,
        length(p_prefix)
            + position(p_delimiter IN substring(p_key FROM length(p_prefix) + 1))
            + length(p_delimiter) - 1
    )
    ELSE NULL
END;
$$;


ALTER FUNCTION "storage"."get_common_prefix"("p_key" "text", "p_prefix" "text", "p_delimiter" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."get_size_by_bucket"("noncurrent_versions" "text" DEFAULT 'include'::"text", "delete_markers" "text" DEFAULT 'include'::"text") RETURNS TABLE("size" bigint, "bucket_id" "text")
    LANGUAGE "plpgsql" STABLE
    AS $$
BEGIN
    -- COALESCE first: NULL NOT IN (...) evaluates to NULL (not TRUE), so a
    -- bare NOT IN check silently leaves an explicit NULL argument unreset.
    noncurrent_versions := COALESCE(noncurrent_versions, 'include');
    delete_markers := COALESCE(delete_markers, 'include');
    IF noncurrent_versions NOT IN ('exclude', 'only', 'include') THEN
        noncurrent_versions := 'include';
    END IF;
    IF delete_markers NOT IN ('exclude', 'only', 'include') THEN
        delete_markers := 'include';
    END IF;

    return query
        select sum((metadata->>'size')::bigint)::bigint as size, obj.bucket_id
        from "storage".objects as obj
        where (noncurrent_versions != 'exclude' OR obj.archived_at IS NULL)
          and (noncurrent_versions != 'only' OR obj.archived_at IS NOT NULL)
          and (delete_markers != 'exclude' OR NOT obj.is_delete_marker)
          and (delete_markers != 'only' OR obj.is_delete_marker)
        group by obj.bucket_id;
END
$$;


ALTER FUNCTION "storage"."get_size_by_bucket"("noncurrent_versions" "text", "delete_markers" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."list_multipart_uploads_with_delimiter"("bucket_id" "text", "prefix_param" "text", "delimiter_param" "text", "max_keys" integer DEFAULT 100, "next_key_token" "text" DEFAULT ''::"text", "next_upload_token" "text" DEFAULT ''::"text", "raw_prefix_param" "text" DEFAULT NULL::"text") RETURNS TABLE("key" "text", "id" "text", "created_at" timestamp with time zone)
    LANGUAGE "sql" STABLE
    AS $_$
WITH candidates AS (
    SELECT
        upload.key AS object_key,
        CASE
            WHEN position($3 IN substring(upload.key FROM length(coalesce($7, $2)) + 1)) > 0
            THEN left(
                upload.key,
                length(coalesce($7, $2))
                    + position($3 IN substring(upload.key FROM length(coalesce($7, $2)) + 1))
                    + length($3) - 1
            )
            ELSE upload.key
        END AS result_key,
        upload.id,
        upload.created_at,
        position($3 IN substring(upload.key FROM length(coalesce($7, $2)) + 1)) > 0 AS is_common_prefix
    FROM storage.s3_multipart_uploads AS upload
    WHERE upload.bucket_id = $1
      AND upload.key COLLATE "C" LIKE $2 || '%'
), filtered AS (
    SELECT candidate.*
    FROM candidates AS candidate
    WHERE $5 = ''
       OR candidate.result_key COLLATE "C" > $5
       OR (
           candidate.result_key COLLATE "C" = $5
           AND NOT candidate.is_common_prefix
           AND $6 <> ''
           -- A completed or aborted marker repeats the remaining same-key uploads.
           AND COALESCE(
               (candidate.created_at, candidate.id COLLATE "C") > (
                   SELECT marker.created_at, marker.id COLLATE "C"
                   FROM storage.s3_multipart_uploads AS marker
                   WHERE marker.bucket_id = $1
                     AND marker.key COLLATE "C" = $5
                     AND marker.id = $6
               ),
               TRUE
           )
       )
), ranked AS (
    SELECT
        filtered.*,
        row_number() OVER (
            PARTITION BY filtered.result_key COLLATE "C"
            ORDER BY filtered.created_at, filtered.id COLLATE "C"
        ) AS prefix_rank
    FROM filtered
)
SELECT ranked.result_key, ranked.id, ranked.created_at
FROM ranked
WHERE NOT ranked.is_common_prefix OR ranked.prefix_rank = 1
ORDER BY ranked.result_key COLLATE "C", ranked.created_at, ranked.id COLLATE "C"
LIMIT $4;
$_$;


ALTER FUNCTION "storage"."list_multipart_uploads_with_delimiter"("bucket_id" "text", "prefix_param" "text", "delimiter_param" "text", "max_keys" integer, "next_key_token" "text", "next_upload_token" "text", "raw_prefix_param" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."list_objects_with_delimiter"("_bucket_id" "text", "prefix_param" "text", "delimiter_param" "text", "max_keys" integer DEFAULT 100, "start_after" "text" DEFAULT ''::"text", "next_token" "text" DEFAULT ''::"text", "sort_order" "text" DEFAULT 'asc'::"text", "noncurrent_versions" "text" DEFAULT 'exclude'::"text", "delete_markers" "text" DEFAULT 'exclude'::"text", "next_token_archived_at" timestamp with time zone DEFAULT NULL::timestamp with time zone, "next_token_version" "text" DEFAULT ''::"text") RETURNS TABLE("name" "text", "id" "uuid", "metadata" "jsonb", "updated_at" timestamp with time zone, "created_at" timestamp with time zone, "last_accessed_at" timestamp with time zone, "version" "text", "archived_at" timestamp with time zone, "is_delete_marker" boolean, "is_versioned" boolean)
    LANGUAGE "plpgsql" STABLE
    AS $_$
DECLARE
    v_peek_name TEXT;
    v_current RECORD;
    v_common_prefix TEXT;

    -- Configuration
    v_is_asc BOOLEAN;
    v_prefix TEXT;
    v_start TEXT;
    v_start_relative TEXT;
    v_upper_bound TEXT;
    v_file_batch_size INT;
    v_version_filter TEXT;

    -- true when noncurrent_versions can return >1 row per name; keeps them
    -- ordered most-recent-first and lets pagination resume mid-key
    v_multi_row BOOLEAN;
    v_name_order TEXT;
    v_exact_range_predicate TEXT;
    v_strict_range_predicate TEXT;
    v_inclusive_range_predicate TEXT;

    -- Seek state for the current name. archived_at is normalized to JavaScript's
    -- millisecond precision and version breaks ties within the same millisecond.
    -- Current rows use 'infinity'; NULL means no tiebreak has been established.
    v_next_seek TEXT;
    v_next_seek_at TIMESTAMPTZ;
    v_next_seek_version TEXT;
    v_next_seek_strict BOOLEAN := false;
    v_cursor_is_folder BOOLEAN;
    v_count INT := 0;
    v_previous_seek TEXT;
    v_previous_seek_at TIMESTAMPTZ;
    v_previous_seek_version TEXT;
    v_previous_count INT;

    -- Dynamic SQL for batch query only
    v_batch_query TEXT;
    v_batch_query_strict TEXT;
    v_delete_marker_peek_query TEXT;
    v_delete_marker_peek_query_strict TEXT;

BEGIN
    -- ========================================================================
    -- INITIALIZATION
    -- ========================================================================
    v_is_asc := lower(coalesce(sort_order, 'asc')) = 'asc';
    v_prefix := coalesce(prefix_param, '');
    v_start := CASE WHEN coalesce(next_token, '') <> '' THEN next_token ELSE coalesce(start_after, '') END;
    v_file_batch_size := LEAST(GREATEST(max_keys * 2, 100), 1000);
    v_next_seek_at := NULL;
    v_next_seek_version := '';

    -- COALESCE first: NULL NOT IN (...) evaluates to NULL (not TRUE), so a
    -- bare NOT IN check silently leaves an explicit NULL argument unreset.
    noncurrent_versions := COALESCE(noncurrent_versions, 'exclude');
    delete_markers := COALESCE(delete_markers, 'exclude');
    IF noncurrent_versions NOT IN ('exclude', 'only', 'include') THEN
        noncurrent_versions := 'exclude';
    END IF;
    IF delete_markers NOT IN ('exclude', 'only', 'include') THEN
        delete_markers := 'exclude';
    END IF;

    v_multi_row := noncurrent_versions IN ('only', 'include');
    v_name_order := CASE WHEN v_is_asc THEN 'ASC' ELSE 'DESC' END;

    v_version_filter := '';
    IF noncurrent_versions = 'exclude' THEN
        v_version_filter := v_version_filter || ' AND o.archived_at IS NULL';
    ELSIF noncurrent_versions = 'only' THEN
        v_version_filter := v_version_filter || ' AND o.archived_at IS NOT NULL';
    END IF;
    IF delete_markers = 'exclude' THEN
        v_version_filter := v_version_filter || ' AND NOT o.is_delete_marker';
    ELSIF delete_markers = 'only' THEN
        v_version_filter := v_version_filter || ' AND o.is_delete_marker';
    END IF;

    -- Calculate upper bound for prefix filtering (bytewise, using COLLATE "C")
    IF v_prefix = '' THEN
        v_upper_bound := NULL;
    ELSE
        v_upper_bound := left(v_prefix, -1) || chr(ascii(right(v_prefix, 1)) + 1);
    END IF;

    -- Keep caller-provided cursors inside the requested prefix range.
    IF v_start <> '' AND v_upper_bound IS NOT NULL THEN
        IF v_is_asc THEN
            IF v_start COLLATE "C" < v_prefix COLLATE "C" THEN
                v_start := '';
            ELSIF v_start COLLATE "C" >= v_upper_bound COLLATE "C" THEN
                RETURN;
            END IF;
        ELSE
            IF v_start COLLATE "C" < v_prefix COLLATE "C" THEN
                RETURN;
            ELSIF v_start COLLATE "C" >= v_upper_bound COLLATE "C" THEN
                v_start := '';
            END IF;
        END IF;
    END IF;

    v_start_relative := substring(v_start FROM length(v_prefix) + 1);

    -- Direction affects only the indexed name range and its ordering. Cursor
    -- state transitions and within-key version ordering stay shared.
    IF v_is_asc THEN
        v_exact_range_predicate := 'TRUE';
        v_strict_range_predicate := 'o.name COLLATE "C" > $2';
        v_inclusive_range_predicate := 'o.name COLLATE "C" >= $2';
        IF v_upper_bound IS NOT NULL THEN
            v_exact_range_predicate := 'o.name COLLATE "C" < $3';
            v_strict_range_predicate := v_strict_range_predicate || ' AND o.name COLLATE "C" < $3';
            v_inclusive_range_predicate := v_inclusive_range_predicate || ' AND o.name COLLATE "C" < $3';
        END IF;
    ELSE
        v_exact_range_predicate := 'TRUE';
        v_strict_range_predicate := 'o.name COLLATE "C" < $2';
        v_inclusive_range_predicate := 'o.name COLLATE "C" < $2';
        IF v_prefix <> '' THEN
            v_exact_range_predicate := 'o.name COLLATE "C" >= $3';
            v_strict_range_predicate := v_strict_range_predicate || ' AND o.name COLLATE "C" >= $3';
            v_inclusive_range_predicate := v_inclusive_range_predicate || ' AND o.name COLLATE "C" >= $3';
        END IF;
    END IF;

    -- Build batch query (dynamic SQL - called infrequently, amortized over many rows)
    -- The multi-row order matches the externally serialized cursor exactly:
    -- archived_at at millisecond precision, then version as the final tiebreak.
    --
    -- When v_multi_row, the seek is a keyset tuple comparison ("name > $2 OR
    -- (name = $2 AND tiebreak)") - Postgres won't split that OR into indexable
    -- form (confirmed even with fully literal values), so as one WHERE clause
    -- it forces a full bucket scan filtered row-by-row. Splitting it into two
    -- independently-indexable branches (exact name match with the tiebreak
    -- filter, vs. strictly-past names) combined with UNION ALL lets each
    -- branch keep name as a real index condition; the outer ORDER BY/LIMIT
    -- re-merges them into the same page the single query used to produce.
    IF v_multi_row THEN
        v_batch_query := format(
            $sql$
            SELECT *
            FROM (
                (
                    SELECT o.name, o.id, o.updated_at, o.created_at,
                           o.last_accessed_at, o.metadata, o.version,
                           o.archived_at, o.is_delete_marker, o.is_versioned
                    FROM storage.objects o
                    WHERE o.bucket_id = $1
                      AND o.name COLLATE "C" = $2
                      AND %s
                      AND NOT $7::boolean
                      AND (
                          $5::timestamptz IS NULL
                          OR COALESCE(date_trunc('milliseconds', o.archived_at), 'infinity'::timestamptz) < $5
                          OR (
                              COALESCE(date_trunc('milliseconds', o.archived_at), 'infinity'::timestamptz) = $5
                              AND COALESCE(o.version, '') > $6
                          )
                      )
                      %s
                    ORDER BY
                        COALESCE(date_trunc('milliseconds', o.archived_at), 'infinity'::timestamptz) DESC,
                        COALESCE(o.version, '') ASC
                    LIMIT $4
                )
                UNION ALL
                (
                    SELECT o.name, o.id, o.updated_at, o.created_at,
                           o.last_accessed_at, o.metadata, o.version,
                           o.archived_at, o.is_delete_marker, o.is_versioned
                    FROM storage.objects o
                    WHERE o.bucket_id = $1
                      AND %s
                      %s
                    ORDER BY
                        o.name COLLATE "C" %s,
                        COALESCE(date_trunc('milliseconds', o.archived_at), 'infinity'::timestamptz) DESC,
                        COALESCE(o.version, '') ASC
                    LIMIT $4
                )
            ) sub
            ORDER BY
                sub.name COLLATE "C" %s,
                COALESCE(date_trunc('milliseconds', sub.archived_at), 'infinity'::timestamptz) DESC,
                COALESCE(sub.version, '') ASC
            LIMIT $4
            $sql$,
            v_exact_range_predicate,
            v_version_filter,
            v_strict_range_predicate,
            v_version_filter,
            v_name_order,
            v_name_order
        );
    ELSE
        v_batch_query := format(
            $sql$
            SELECT o.name, o.id, o.updated_at, o.created_at,
                   o.last_accessed_at, o.metadata, o.version,
                   o.archived_at, o.is_delete_marker, o.is_versioned
            FROM storage.objects o
            WHERE o.bucket_id = $1
              AND %s
              %s
            ORDER BY o.name COLLATE "C" %s, o.archived_at DESC
            LIMIT $4
            $sql$,
            v_inclusive_range_predicate,
            v_version_filter,
            v_name_order
        );

        -- Strict counterpart of the query above: used once the single-row
        -- ASC batch advance (below) has left v_next_seek pointing at the
        -- last row already emitted, so an inclusive predicate would
        -- re-match it forever. Only single-row mode ever sets strict mode,
        -- so this variant is never needed when v_multi_row.
        v_batch_query_strict := format(
            $sql$
            SELECT o.name, o.id, o.updated_at, o.created_at,
                   o.last_accessed_at, o.metadata, o.version,
                   o.archived_at, o.is_delete_marker, o.is_versioned
            FROM storage.objects o
            WHERE o.bucket_id = $1
              AND %s
              %s
            ORDER BY o.name COLLATE "C" %s, o.archived_at DESC
            LIMIT $4
            $sql$,
            v_strict_range_predicate,
            v_version_filter,
            v_name_order
        );
    END IF;

    -- The static peek predicates cannot use the partial delete-marker index
    -- once PL/pgSQL switches to a generic plan because whether
    -- is_delete_marker is required remains parameter-dependent. Reuse the
    -- already-specialized batch query with a one-row limit for this sparse
    -- filter so the plan sees a literal `o.is_delete_marker` predicate.
    IF delete_markers = 'only' THEN
        v_delete_marker_peek_query :=
            'SELECT marker_page.name FROM (' || v_batch_query || ') marker_page LIMIT 1';
        IF NOT v_multi_row THEN
            v_delete_marker_peek_query_strict :=
                'SELECT marker_page.name FROM (' || v_batch_query_strict || ') marker_page LIMIT 1';
        END IF;
    END IF;

    -- ========================================================================
    -- SEEK INITIALIZATION: Determine starting position
    -- ========================================================================
    IF v_start = '' THEN
        IF v_is_asc THEN
            v_next_seek := v_prefix;
        ELSE
            -- DESC without cursor performs one specialized initial seek so
            -- partial current-version and delete-marker indexes remain available.
            EXECUTE format(
                'SELECT o.name FROM storage.objects o WHERE o.bucket_id = $1%s%s ORDER BY o.name COLLATE "C" DESC LIMIT 1',
                CASE WHEN v_upper_bound IS NOT NULL
                    THEN ' AND o.name COLLATE "C" >= $2 AND o.name COLLATE "C" < $3'
                    ELSE ''
                END,
                v_version_filter
            )
            INTO v_next_seek
            USING _bucket_id, v_prefix, v_upper_bound;

            IF v_next_seek IS NOT NULL THEN
                v_next_seek := v_next_seek || delimiter_param;
            ELSE
                RETURN;
            END IF;
        END IF;
    ELSE
        -- Folder continuation tokens retain their trailing delimiter. A
        -- delimiter-less startAfter is always a literal key boundary.
        v_cursor_is_folder := delimiter_param <> ''
            AND v_start_relative <> ''
            AND right(v_start_relative, length(delimiter_param)) = delimiter_param;

        IF v_cursor_is_folder THEN
            v_next_seek := CASE
                WHEN right(v_start, length(delimiter_param)) = delimiter_param
                    THEN v_start
                ELSE v_start || delimiter_param
            END;
            IF v_is_asc THEN
                v_next_seek := left(v_next_seek, -1)
                    || chr(ascii(right(v_next_seek, 1)) + 1);
            END IF;
            v_next_seek_strict := NOT v_is_asc;
        ELSE
            -- leaf object: when v_multi_row, stay on v_start with the
            -- caller-supplied tiebreak so a page boundary mid-key resumes
            -- that key's remaining rows instead of skipping them. Truncate
            -- to milliseconds like every other v_next_seek_at assignment -
            -- harmless today since object.ts's cursor always round-trips
            -- through JS Date first, but this shouldn't rely on that.
            IF v_multi_row THEN
                v_next_seek := v_start;
                v_next_seek_at := date_trunc('milliseconds', next_token_archived_at);
                v_next_seek_version := coalesce(next_token_version, '');
                v_next_seek_strict := coalesce(next_token, '') = '';
            ELSIF v_is_asc THEN
                v_next_seek := v_start;
                v_next_seek_strict := true;
            ELSE
                v_next_seek := v_start;
            END IF;
        END IF;
    END IF;

    -- ========================================================================
    -- MAIN LOOP: Hybrid peek-then-batch algorithm
    -- Uses STATIC SQL for peek (hot path) and DYNAMIC SQL for batch
    -- ========================================================================
    LOOP
        EXIT WHEN v_count >= max_keys;

        v_previous_seek := v_next_seek;
        v_previous_seek_at := v_next_seek_at;
        v_previous_seek_version := v_next_seek_version;
        v_previous_count := v_count;

        -- STEP 1: PEEK using STATIC SQL (plan cached, very fast)
        -- v_multi_row is branched here (rather than folded into the WHERE
        -- clause as a bound parameter) so each concrete query keeps an
        -- unconditional seek predicate - once PL/pgSQL switches to its
        -- cached generic plan (after 5 calls), a parameter-gated
        -- "(NOT v_multi_row AND name >= $x) OR (v_multi_row AND ...)"
        -- predicate stops the planner from using name as an index
        -- condition at all, degrading every subsequent peek to a full
        -- index scan filtered row-by-row instead of a bounded range scan.
        -- v_multi_row's seek predicate is a keyset tuple comparison
        -- ("name > x OR (name = x AND tiebreak)") - Postgres does not
        -- split this OR into indexable form even with fully literal
        -- values, so it falls back to a full scan filtered row-by-row.
        -- Splitting it into two independently-indexable branches (exact
        -- name match with the tiebreak filter, vs. strictly-past name)
        -- combined with UNION ALL lets each branch keep name as a real
        -- index condition; the outer ORDER BY/LIMIT picks whichever of
        -- the (at most 2) rows sorts first.
        IF delete_markers = 'only' THEN
            EXECUTE CASE WHEN v_next_seek_strict AND NOT v_multi_row
                THEN v_delete_marker_peek_query_strict
                ELSE v_delete_marker_peek_query
            END
                INTO v_peek_name
                USING _bucket_id, v_next_seek,
                    CASE WHEN v_is_asc THEN COALESCE(v_upper_bound, v_prefix) ELSE v_prefix END,
                    1, v_next_seek_at, v_next_seek_version, v_next_seek_strict;
        ELSIF v_multi_row THEN
            IF v_is_asc THEN
                IF v_upper_bound IS NOT NULL THEN
                    SELECT sub.name INTO v_peek_name FROM (
                        (SELECT o.name FROM storage.objects o
                         WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" = v_next_seek
                           AND o.name COLLATE "C" < v_upper_bound
                           AND NOT v_next_seek_strict
                           AND (v_next_seek_at IS NULL
                                OR COALESCE(date_trunc('milliseconds', o.archived_at), 'infinity'::timestamptz) < v_next_seek_at
                                OR (COALESCE(date_trunc('milliseconds', o.archived_at), 'infinity'::timestamptz) = v_next_seek_at
                                    AND COALESCE(o.version, '') > v_next_seek_version))
                           AND (noncurrent_versions != 'exclude' OR o.archived_at IS NULL)
                           AND (noncurrent_versions != 'only' OR o.archived_at IS NOT NULL)
                           AND (delete_markers != 'exclude' OR NOT o.is_delete_marker)
                           AND (delete_markers != 'only' OR o.is_delete_marker)
                         ORDER BY COALESCE(date_trunc('milliseconds', o.archived_at), 'infinity'::timestamptz) DESC, COALESCE(o.version, '') ASC LIMIT 1)
                        UNION ALL
                        (SELECT o.name FROM storage.objects o
                         WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" > v_next_seek AND o.name COLLATE "C" < v_upper_bound
                           AND (noncurrent_versions != 'exclude' OR o.archived_at IS NULL)
                           AND (noncurrent_versions != 'only' OR o.archived_at IS NOT NULL)
                           AND (delete_markers != 'exclude' OR NOT o.is_delete_marker)
                           AND (delete_markers != 'only' OR o.is_delete_marker)
                         ORDER BY o.name COLLATE "C" ASC LIMIT 1)
                    ) sub ORDER BY sub.name COLLATE "C" ASC LIMIT 1;
                ELSE
                    SELECT sub.name INTO v_peek_name FROM (
                        (SELECT o.name FROM storage.objects o
                         WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" = v_next_seek
                           AND NOT v_next_seek_strict
                           AND (v_next_seek_at IS NULL
                                OR COALESCE(date_trunc('milliseconds', o.archived_at), 'infinity'::timestamptz) < v_next_seek_at
                                OR (COALESCE(date_trunc('milliseconds', o.archived_at), 'infinity'::timestamptz) = v_next_seek_at
                                    AND COALESCE(o.version, '') > v_next_seek_version))
                           AND (noncurrent_versions != 'exclude' OR o.archived_at IS NULL)
                           AND (noncurrent_versions != 'only' OR o.archived_at IS NOT NULL)
                           AND (delete_markers != 'exclude' OR NOT o.is_delete_marker)
                           AND (delete_markers != 'only' OR o.is_delete_marker)
                         ORDER BY COALESCE(date_trunc('milliseconds', o.archived_at), 'infinity'::timestamptz) DESC, COALESCE(o.version, '') ASC LIMIT 1)
                        UNION ALL
                        (SELECT o.name FROM storage.objects o
                         WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" > v_next_seek
                           AND (noncurrent_versions != 'exclude' OR o.archived_at IS NULL)
                           AND (noncurrent_versions != 'only' OR o.archived_at IS NOT NULL)
                           AND (delete_markers != 'exclude' OR NOT o.is_delete_marker)
                           AND (delete_markers != 'only' OR o.is_delete_marker)
                         ORDER BY o.name COLLATE "C" ASC LIMIT 1)
                    ) sub ORDER BY sub.name COLLATE "C" ASC LIMIT 1;
                END IF;
            ELSE
                IF v_upper_bound IS NOT NULL THEN
                    SELECT sub.name INTO v_peek_name FROM (
                        (SELECT o.name FROM storage.objects o
                         WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" = v_next_seek
                           AND o.name COLLATE "C" >= v_prefix
                           AND NOT v_next_seek_strict
                           AND (v_next_seek_at IS NULL
                                OR COALESCE(date_trunc('milliseconds', o.archived_at), 'infinity'::timestamptz) < v_next_seek_at
                                OR (COALESCE(date_trunc('milliseconds', o.archived_at), 'infinity'::timestamptz) = v_next_seek_at
                                    AND COALESCE(o.version, '') > v_next_seek_version))
                           AND (noncurrent_versions != 'exclude' OR o.archived_at IS NULL)
                           AND (noncurrent_versions != 'only' OR o.archived_at IS NOT NULL)
                           AND (delete_markers != 'exclude' OR NOT o.is_delete_marker)
                           AND (delete_markers != 'only' OR o.is_delete_marker)
                         ORDER BY COALESCE(date_trunc('milliseconds', o.archived_at), 'infinity'::timestamptz) DESC, COALESCE(o.version, '') ASC LIMIT 1)
                        UNION ALL
                        (SELECT o.name FROM storage.objects o
                         WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" < v_next_seek AND o.name COLLATE "C" >= v_prefix
                           AND (noncurrent_versions != 'exclude' OR o.archived_at IS NULL)
                           AND (noncurrent_versions != 'only' OR o.archived_at IS NOT NULL)
                           AND (delete_markers != 'exclude' OR NOT o.is_delete_marker)
                           AND (delete_markers != 'only' OR o.is_delete_marker)
                         ORDER BY o.name COLLATE "C" DESC LIMIT 1)
                    ) sub ORDER BY sub.name COLLATE "C" DESC LIMIT 1;
                ELSE
                    SELECT sub.name INTO v_peek_name FROM (
                        (SELECT o.name FROM storage.objects o
                         WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" = v_next_seek
                           AND NOT v_next_seek_strict
                           AND (v_next_seek_at IS NULL
                                OR COALESCE(date_trunc('milliseconds', o.archived_at), 'infinity'::timestamptz) < v_next_seek_at
                                OR (COALESCE(date_trunc('milliseconds', o.archived_at), 'infinity'::timestamptz) = v_next_seek_at
                                    AND COALESCE(o.version, '') > v_next_seek_version))
                           AND (noncurrent_versions != 'exclude' OR o.archived_at IS NULL)
                           AND (noncurrent_versions != 'only' OR o.archived_at IS NOT NULL)
                           AND (delete_markers != 'exclude' OR NOT o.is_delete_marker)
                           AND (delete_markers != 'only' OR o.is_delete_marker)
                         ORDER BY COALESCE(date_trunc('milliseconds', o.archived_at), 'infinity'::timestamptz) DESC, COALESCE(o.version, '') ASC LIMIT 1)
                        UNION ALL
                        (SELECT o.name FROM storage.objects o
                         WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" < v_next_seek
                           AND (noncurrent_versions != 'exclude' OR o.archived_at IS NULL)
                           AND (noncurrent_versions != 'only' OR o.archived_at IS NOT NULL)
                           AND (delete_markers != 'exclude' OR NOT o.is_delete_marker)
                           AND (delete_markers != 'only' OR o.is_delete_marker)
                         ORDER BY o.name COLLATE "C" DESC LIMIT 1)
                    ) sub ORDER BY sub.name COLLATE "C" DESC LIMIT 1;
                END IF;
            END IF;
        ELSE
            -- Single-row mode is always noncurrent_versions='exclude'. Keep
            -- this predicate literal so generic plans use the current index.
            IF v_is_asc THEN
                IF v_next_seek_strict AND v_upper_bound IS NOT NULL THEN
                    SELECT o.name INTO v_peek_name FROM storage.objects o
                    WHERE o.bucket_id = _bucket_id
                      AND o.name COLLATE "C" > v_next_seek
                      AND o.name COLLATE "C" < v_upper_bound
                      AND o.archived_at IS NULL
                      AND (delete_markers != 'exclude' OR NOT o.is_delete_marker)
                      AND (delete_markers != 'only' OR o.is_delete_marker)
                    ORDER BY o.name COLLATE "C" ASC LIMIT 1;
                ELSIF v_next_seek_strict THEN
                    SELECT o.name INTO v_peek_name FROM storage.objects o
                    WHERE o.bucket_id = _bucket_id
                      AND o.name COLLATE "C" > v_next_seek
                      AND o.archived_at IS NULL
                      AND (delete_markers != 'exclude' OR NOT o.is_delete_marker)
                      AND (delete_markers != 'only' OR o.is_delete_marker)
                    ORDER BY o.name COLLATE "C" ASC LIMIT 1;
                ELSIF v_upper_bound IS NOT NULL THEN
                    SELECT o.name INTO v_peek_name FROM storage.objects o
                    WHERE o.bucket_id = _bucket_id
                      AND o.name COLLATE "C" >= v_next_seek
                      AND o.name COLLATE "C" < v_upper_bound
                      AND o.archived_at IS NULL
                      AND (delete_markers != 'exclude' OR NOT o.is_delete_marker)
                      AND (delete_markers != 'only' OR o.is_delete_marker)
                    ORDER BY o.name COLLATE "C" ASC LIMIT 1;
                ELSE
                    SELECT o.name INTO v_peek_name FROM storage.objects o
                    WHERE o.bucket_id = _bucket_id
                      AND o.name COLLATE "C" >= v_next_seek
                      AND o.archived_at IS NULL
                      AND (delete_markers != 'exclude' OR NOT o.is_delete_marker)
                      AND (delete_markers != 'only' OR o.is_delete_marker)
                    ORDER BY o.name COLLATE "C" ASC LIMIT 1;
                END IF;
            ELSE
                IF v_upper_bound IS NOT NULL THEN
                    SELECT o.name INTO v_peek_name FROM storage.objects o
                    WHERE o.bucket_id = _bucket_id
                      AND o.name COLLATE "C" < v_next_seek
                      AND o.name COLLATE "C" >= v_prefix
                      AND o.archived_at IS NULL
                      AND (delete_markers != 'exclude' OR NOT o.is_delete_marker)
                      AND (delete_markers != 'only' OR o.is_delete_marker)
                    ORDER BY o.name COLLATE "C" DESC LIMIT 1;
                ELSE
                    SELECT o.name INTO v_peek_name FROM storage.objects o
                    WHERE o.bucket_id = _bucket_id
                      AND o.name COLLATE "C" < v_next_seek
                      AND o.archived_at IS NULL
                      AND (delete_markers != 'exclude' OR NOT o.is_delete_marker)
                      AND (delete_markers != 'only' OR o.is_delete_marker)
                    ORDER BY o.name COLLATE "C" DESC LIMIT 1;
                END IF;
            END IF;
        END IF;

        EXIT WHEN v_peek_name IS NULL;

        -- STEP 2: Check if this is a FOLDER or FILE
        v_common_prefix := storage.get_common_prefix(v_peek_name, v_prefix, delimiter_param);

        IF v_common_prefix IS NOT NULL THEN
            -- FOLDER: Emit and skip to next folder (no heap access needed)
            name := v_common_prefix;
            id := NULL;
            updated_at := NULL;
            created_at := NULL;
            last_accessed_at := NULL;
            metadata := NULL;
            version := NULL;
            archived_at := NULL;
            is_delete_marker := NULL;
            is_versioned := NULL;
            RETURN NEXT;
            v_count := v_count + 1;

            -- Advance seek past the folder range
            IF v_is_asc THEN
                v_next_seek := left(v_common_prefix, -1)
                    || chr(ascii(right(v_common_prefix, 1)) + 1);
            ELSE
                v_next_seek := v_common_prefix;
            END IF;
            v_next_seek_at := NULL;
            v_next_seek_version := '';
            v_next_seek_strict := NOT v_is_asc;
        ELSE
            -- FILE: Batch fetch using DYNAMIC SQL (overhead amortized over many rows)
            -- For ASC: upper_bound is the exclusive upper limit (< condition)
            -- For DESC: prefix is the inclusive lower limit (>= condition)
            FOR v_current IN EXECUTE CASE WHEN v_next_seek_strict AND NOT v_multi_row THEN v_batch_query_strict ELSE v_batch_query END
                USING _bucket_id, v_next_seek,
                CASE WHEN v_is_asc THEN COALESCE(v_upper_bound, v_prefix) ELSE v_prefix END, v_file_batch_size, v_next_seek_at, v_next_seek_version,
                v_next_seek_strict
            LOOP
                v_common_prefix := storage.get_common_prefix(v_current.name, v_prefix, delimiter_param);

                IF v_common_prefix IS NOT NULL THEN
                    -- Hit a folder: exit batch, let peek handle it. Reset
                    -- strict mode too it may have been set by an earlier
                    -- row in this same batch (see the single-row ASC advance
                    -- below), and v_next_seek here is the folder-triggering
                    -- row's own name, which the next peek must find inclusively.
                    v_next_seek := CASE
                        WHEN v_is_asc THEN v_current.name
                        ELSE v_current.name || delimiter_param
                    END;
                    v_next_seek_at := NULL;
                    v_next_seek_version := '';
                    v_next_seek_strict := false;
                    EXIT;
                END IF;

                -- Emit file
                name := v_current.name;
                id := v_current.id;
                updated_at := v_current.updated_at;
                created_at := v_current.created_at;
                last_accessed_at := v_current.last_accessed_at;
                metadata := v_current.metadata;
                version := v_current.version;
                archived_at := v_current.archived_at;
                is_delete_marker := v_current.is_delete_marker;
                is_versioned := v_current.is_versioned;
                RETURN NEXT;
                v_count := v_count + 1;

                -- when v_multi_row, stay on this name and record its
                -- archived_at as the new tiebreak so remaining rows for the
                -- same key are picked up before moving to the next name
                IF v_multi_row THEN
                    v_next_seek := v_current.name;
                    v_next_seek_at := COALESCE(date_trunc('milliseconds', v_current.archived_at), 'infinity'::timestamptz);
                    v_next_seek_version := COALESCE(v_current.version, '');
                    v_next_seek_strict := false;
                ELSIF v_is_asc THEN
                    -- Appending the delimiter as a fake lexical successor
                    -- would skip a real key like `name || '!'` (or any
                    -- character sorting below the delimiter), which sorts
                    -- between `name` and `name || delimiter`. Track the real
                    -- name and mark the next comparison strict instead.
                    v_next_seek := v_current.name;
                    v_next_seek_strict := true;
                ELSE
                    v_next_seek := v_current.name;
                END IF;

                EXIT WHEN v_count >= max_keys;
            END LOOP;
        END IF;

        IF v_count = v_previous_count
           AND v_next_seek IS NOT DISTINCT FROM v_previous_seek
           AND v_next_seek_at IS NOT DISTINCT FROM v_previous_seek_at
           AND v_next_seek_version IS NOT DISTINCT FROM v_previous_seek_version THEN
            RAISE EXCEPTION 'storage.list_objects_with_delimiter made no progress at seek (%, %, %)',
                v_next_seek, v_next_seek_at, v_next_seek_version;
        END IF;
    END LOOP;
END;
$_$;


ALTER FUNCTION "storage"."list_objects_with_delimiter"("_bucket_id" "text", "prefix_param" "text", "delimiter_param" "text", "max_keys" integer, "start_after" "text", "next_token" "text", "sort_order" "text", "noncurrent_versions" "text", "delete_markers" "text", "next_token_archived_at" timestamp with time zone, "next_token_version" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."operation"() RETURNS "text"
    LANGUAGE "plpgsql" STABLE
    AS $$
BEGIN
    RETURN current_setting('storage.operation', true);
END;
$$;


ALTER FUNCTION "storage"."operation"() OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."protect_bucket_control_columns"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'pg_catalog'
    AS $$
DECLARE
  configuration_changed boolean;
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.lifecycle_configuration IS NOT NULL
       OR NEW.lifecycle_configuration_generation IS NOT NULL THEN
      IF NOT pg_has_role(current_user, TG_ARGV[0], 'MEMBER') THEN
        RAISE EXCEPTION 'only members of the configured storage service role may insert lifecycle policy state'
          USING ERRCODE = '42501',
                HINT = format(
                  'Insert with both lifecycle columns NULL and configure lifecycle through the Storage API afterward, or insert as a member of %I.',
                  TG_ARGV[0]
                );
      END IF;
    END IF;

    RETURN NEW;
  END IF;

  configuration_changed =
    OLD.lifecycle_configuration IS DISTINCT FROM NEW.lifecycle_configuration
    OR OLD.lifecycle_configuration_generation IS DISTINCT FROM NEW.lifecycle_configuration_generation;

  IF NOT configuration_changed THEN
    RETURN NEW;
  END IF;

  IF NEW.type IS DISTINCT FROM 'STANDARD' THEN
    RAISE EXCEPTION 'bucket versioning and lifecycle controls require a Standard bucket'
      USING ERRCODE = '0A000';
  END IF;

  IF NEW.lifecycle_configuration IS NULL
     AND NEW.lifecycle_configuration_generation IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.lifecycle_configuration IS NULL
     OR NEW.lifecycle_configuration_generation IS NULL
     OR OLD.lifecycle_configuration IS NOT DISTINCT FROM NEW.lifecycle_configuration
     OR OLD.lifecycle_configuration_generation IS NOT DISTINCT FROM NEW.lifecycle_configuration_generation THEN
    RAISE EXCEPTION 'a changed lifecycle policy requires a new non-null generation'
      USING ERRCODE = '22023';
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "storage"."protect_bucket_control_columns"() OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."protect_delete"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Check if storage.allow_delete_query is set to 'true'
    IF COALESCE(current_setting('storage.allow_delete_query', true), 'false') != 'true' THEN
        RAISE EXCEPTION 'Direct deletion from storage tables is not allowed. Use the Storage API instead.'
            USING HINT = 'This prevents accidental data loss from orphaned objects.',
                  ERRCODE = '42501';
    END IF;
    RETURN NULL;
END;
$$;


ALTER FUNCTION "storage"."protect_delete"() OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."search"("prefix" "text", "bucketname" "text", "limits" integer DEFAULT 100, "levels" integer DEFAULT 1, "offsets" integer DEFAULT 0, "search" "text" DEFAULT ''::"text", "sortcolumn" "text" DEFAULT 'name'::"text", "sortorder" "text" DEFAULT 'asc'::"text", "noncurrent_versions" "text" DEFAULT 'exclude'::"text", "delete_markers" "text" DEFAULT 'exclude'::"text") RETURNS TABLE("name" "text", "id" "uuid", "updated_at" timestamp with time zone, "created_at" timestamp with time zone, "last_accessed_at" timestamp with time zone, "metadata" "jsonb", "version" "text", "archived_at" timestamp with time zone, "is_delete_marker" boolean, "is_versioned" boolean)
    LANGUAGE "plpgsql" STABLE
    AS $_$
DECLARE
    v_peek_name TEXT;
    v_current RECORD;
    v_common_prefix TEXT;
    v_delimiter CONSTANT TEXT := '/';

    -- Configuration
    v_limit INT;
    v_prefix TEXT;
    v_prefix_lower TEXT;
    v_prefix_len INT;
    v_prefix_start INT;
    v_combined_levels INT;
    v_is_asc BOOLEAN;
    v_order_by TEXT;
    v_sort_order TEXT;
    v_upper_bound TEXT;
    v_file_batch_size INT;
    v_version_filter TEXT;
    v_multi_row BOOLEAN;

    -- Dynamic SQL for batch query only
    v_batch_query TEXT;
    v_delete_marker_peek_query TEXT;
    v_delete_marker_peek_query_strict TEXT;

    -- Seek state
    v_next_seek TEXT;
    v_next_seek_at TIMESTAMPTZ;
    v_next_seek_version TEXT;
    v_next_seek_strict BOOLEAN := false;
    v_count INT := 0;
    v_skipped INT := 0;
    v_previous_seek TEXT;
    v_previous_seek_at TIMESTAMPTZ;
    v_previous_seek_version TEXT;
    v_previous_count INT;
    v_previous_skipped INT;
BEGIN
    -- ========================================================================
    -- INITIALIZATION
    -- ========================================================================
    v_limit := LEAST(coalesce(limits, 100), 1500);
    v_prefix := coalesce(prefix, '') || coalesce(search, '');
    v_prefix_lower := lower(v_prefix);
    v_prefix_len := length(coalesce(prefix, ''));
    v_prefix_start := coalesce(array_length(string_to_array(coalesce(prefix, ''), v_delimiter), 1), 1);
    v_combined_levels := coalesce(array_length(string_to_array(v_prefix, v_delimiter), 1), 1);
    v_is_asc := lower(coalesce(sortorder, 'asc')) = 'asc';
    v_file_batch_size := LEAST(GREATEST(v_limit * 2, 100), 1000);
    v_next_seek_at := NULL;
    v_next_seek_version := '';

    -- COALESCE first: NULL NOT IN (...) evaluates to NULL (not TRUE), so a
    -- bare NOT IN check silently leaves an explicit NULL argument unreset.
    noncurrent_versions := COALESCE(noncurrent_versions, 'exclude');
    delete_markers := COALESCE(delete_markers, 'exclude');
    IF noncurrent_versions NOT IN ('exclude', 'only', 'include') THEN
        noncurrent_versions := 'exclude';
    END IF;
    IF delete_markers NOT IN ('exclude', 'only', 'include') THEN
        delete_markers := 'exclude';
    END IF;

    v_multi_row := noncurrent_versions IN ('only', 'include');

    v_version_filter := '';
    IF noncurrent_versions = 'exclude' THEN
        v_version_filter := v_version_filter || ' AND o.archived_at IS NULL';
    ELSIF noncurrent_versions = 'only' THEN
        v_version_filter := v_version_filter || ' AND o.archived_at IS NOT NULL';
    END IF;
    IF delete_markers = 'exclude' THEN
        v_version_filter := v_version_filter || ' AND NOT o.is_delete_marker';
    ELSIF delete_markers = 'only' THEN
        v_version_filter := v_version_filter || ' AND o.is_delete_marker';
    END IF;

    -- Validate sort column
    CASE lower(coalesce(sortcolumn, 'name'))
        WHEN 'name' THEN v_order_by := 'name';
        WHEN 'updated_at' THEN v_order_by := 'updated_at';
        WHEN 'created_at' THEN v_order_by := 'created_at';
        WHEN 'last_accessed_at' THEN v_order_by := 'last_accessed_at';
        ELSE v_order_by := 'name';
    END CASE;

    v_sort_order := CASE WHEN v_is_asc THEN 'asc' ELSE 'desc' END;

    -- ========================================================================
    -- NON-NAME SORTING: Use path_tokens approach
    -- ========================================================================
    IF v_order_by != 'name' THEN
        RETURN QUERY EXECUTE format(
            $sql$
            WITH folders AS (
                SELECT array_to_string(path_tokens[$1:$2], '/') AS folder
                FROM storage.objects
                WHERE objects.name ILIKE $3 || '%%'
                  AND bucket_id = $4
                  AND array_length(objects.path_tokens, 1) <> $2
                  AND ($7 != 'exclude' OR objects.archived_at IS NULL)
                  AND ($7 != 'only' OR objects.archived_at IS NOT NULL)
                  AND ($8 != 'exclude' OR NOT objects.is_delete_marker)
                  AND ($8 != 'only' OR objects.is_delete_marker)
                GROUP BY folder
                ORDER BY folder %s
            )
            (SELECT folder AS "name",
                   NULL::uuid AS id,
                   NULL::timestamptz AS updated_at,
                   NULL::timestamptz AS created_at,
                   NULL::timestamptz AS last_accessed_at,
                   NULL::jsonb AS metadata,
                   NULL::text AS version,
                   NULL::timestamptz AS archived_at,
                   NULL::boolean AS is_delete_marker,
                   NULL::boolean AS is_versioned FROM folders)
            UNION ALL
            (SELECT array_to_string(path_tokens[$1:$2], '/') AS "name",
                   id, updated_at, created_at, last_accessed_at, metadata,
                   version, archived_at, is_delete_marker, is_versioned
             FROM storage.objects
             WHERE objects.name ILIKE $3 || '%%'
               AND bucket_id = $4
               AND array_length(objects.path_tokens, 1) = $2
               AND ($7 != 'exclude' OR objects.archived_at IS NULL)
               AND ($7 != 'only' OR objects.archived_at IS NOT NULL)
               AND ($8 != 'exclude' OR NOT objects.is_delete_marker)
               AND ($8 != 'only' OR objects.is_delete_marker)
             -- name, then version, as tiebreaks so two versions of the same
             -- key tying on the sort column still sort deterministically
             ORDER BY %I %s, name COLLATE "C" %s, COALESCE(version, '') %s)
            LIMIT $5 OFFSET $6
            $sql$, v_sort_order, v_order_by, v_sort_order, v_sort_order, v_sort_order
        ) USING v_prefix_start, v_combined_levels, v_prefix, bucketname, v_limit, offsets, noncurrent_versions, delete_markers;
        RETURN;
    END IF;

    -- ========================================================================
    -- NAME SORTING: Hybrid skip-scan with batch optimization
    -- ========================================================================

    -- Calculate upper bound for prefix filtering
    IF v_prefix_lower = '' THEN
        v_upper_bound := NULL;
    ELSIF right(v_prefix_lower, 1) = v_delimiter THEN
        v_upper_bound := left(v_prefix_lower, -1) || chr(ascii(v_delimiter) + 1);
    ELSE
        v_upper_bound := left(v_prefix_lower, -1) || chr(ascii(right(v_prefix_lower, 1)) + 1);
    END IF;

    -- Build a resume-safe batch query. The exact-name branch returns remaining
    -- versions after the current (archived_at, version) boundary; the strict
    -- name branch returns subsequent keys. UNION ALL keeps both predicates
    -- independently indexable.
    IF v_is_asc THEN
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT * FROM (' ||
                '(SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata, o.version, o.archived_at, o.is_delete_marker, o.is_versioned FROM storage.objects o ' ||
                'WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" = $2 AND ($5::timestamptz IS NULL OR COALESCE(o.archived_at, ''infinity''::timestamptz) < $5 OR (COALESCE(o.archived_at, ''infinity''::timestamptz) = $5 AND COALESCE(o.version, '''') > $6))' ||
                v_version_filter || ' ORDER BY COALESCE(o.archived_at, ''infinity''::timestamptz) DESC, COALESCE(o.version, '''') ASC LIMIT $4) UNION ALL ' ||
                '(SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata, o.version, o.archived_at, o.is_delete_marker, o.is_versioned FROM storage.objects o ' ||
                'WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" > $2 AND lower(o.name) COLLATE "C" < $3' || v_version_filter ||
                ' ORDER BY lower(o.name) COLLATE "C" ASC, COALESCE(o.archived_at, ''infinity''::timestamptz) DESC, COALESCE(o.version, '''') ASC LIMIT $4)' ||
                ') sub ORDER BY lower(sub.name) COLLATE "C" ASC, COALESCE(sub.archived_at, ''infinity''::timestamptz) DESC, COALESCE(sub.version, '''') ASC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT * FROM (' ||
                '(SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata, o.version, o.archived_at, o.is_delete_marker, o.is_versioned FROM storage.objects o ' ||
                'WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" = $2 AND ($5::timestamptz IS NULL OR COALESCE(o.archived_at, ''infinity''::timestamptz) < $5 OR (COALESCE(o.archived_at, ''infinity''::timestamptz) = $5 AND COALESCE(o.version, '''') > $6))' ||
                v_version_filter || ' ORDER BY COALESCE(o.archived_at, ''infinity''::timestamptz) DESC, COALESCE(o.version, '''') ASC LIMIT $4) UNION ALL ' ||
                '(SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata, o.version, o.archived_at, o.is_delete_marker, o.is_versioned FROM storage.objects o ' ||
                'WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" > $2' || v_version_filter ||
                ' ORDER BY lower(o.name) COLLATE "C" ASC, COALESCE(o.archived_at, ''infinity''::timestamptz) DESC, COALESCE(o.version, '''') ASC LIMIT $4)' ||
                ') sub ORDER BY lower(sub.name) COLLATE "C" ASC, COALESCE(sub.archived_at, ''infinity''::timestamptz) DESC, COALESCE(sub.version, '''') ASC LIMIT $4';
        END IF;
    ELSE
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT * FROM (' ||
                '(SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata, o.version, o.archived_at, o.is_delete_marker, o.is_versioned FROM storage.objects o ' ||
                'WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" = $2 AND ($5::timestamptz IS NULL OR COALESCE(o.archived_at, ''infinity''::timestamptz) < $5 OR (COALESCE(o.archived_at, ''infinity''::timestamptz) = $5 AND COALESCE(o.version, '''') > $6))' ||
                v_version_filter || ' ORDER BY COALESCE(o.archived_at, ''infinity''::timestamptz) DESC, COALESCE(o.version, '''') ASC LIMIT $4) UNION ALL ' ||
                '(SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata, o.version, o.archived_at, o.is_delete_marker, o.is_versioned FROM storage.objects o ' ||
                'WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" < $2 AND lower(o.name) COLLATE "C" >= $3' || v_version_filter ||
                ' ORDER BY lower(o.name) COLLATE "C" DESC, COALESCE(o.archived_at, ''infinity''::timestamptz) DESC, COALESCE(o.version, '''') ASC LIMIT $4)' ||
                ') sub ORDER BY lower(sub.name) COLLATE "C" DESC, COALESCE(sub.archived_at, ''infinity''::timestamptz) DESC, COALESCE(sub.version, '''') ASC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT * FROM (' ||
                '(SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata, o.version, o.archived_at, o.is_delete_marker, o.is_versioned FROM storage.objects o ' ||
                'WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" = $2 AND ($5::timestamptz IS NULL OR COALESCE(o.archived_at, ''infinity''::timestamptz) < $5 OR (COALESCE(o.archived_at, ''infinity''::timestamptz) = $5 AND COALESCE(o.version, '''') > $6))' ||
                v_version_filter || ' ORDER BY COALESCE(o.archived_at, ''infinity''::timestamptz) DESC, COALESCE(o.version, '''') ASC LIMIT $4) UNION ALL ' ||
                '(SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata, o.version, o.archived_at, o.is_delete_marker, o.is_versioned FROM storage.objects o ' ||
                'WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" < $2' || v_version_filter ||
                ' ORDER BY lower(o.name) COLLATE "C" DESC, COALESCE(o.archived_at, ''infinity''::timestamptz) DESC, COALESCE(o.version, '''') ASC LIMIT $4)' ||
                ') sub ORDER BY lower(sub.name) COLLATE "C" DESC, COALESCE(sub.archived_at, ''infinity''::timestamptz) DESC, COALESCE(sub.version, '''') ASC LIMIT $4';
        END IF;
    END IF;

    -- Keep the delete-marker predicate literal so the cached generic
    -- plan can use idx_objects_delete_markers during the main-loop peek.
    IF delete_markers = 'only' THEN
        IF v_multi_row THEN
            v_delete_marker_peek_query :=
                'SELECT marker_page.name FROM (' || v_batch_query || ') marker_page LIMIT 1';
        ELSIF v_is_asc THEN
            -- Two separate literal query strings, not one gated by a bound
            -- boolean: folding "$n AND op1 OR NOT $n AND op2" into a single
            -- query defeats the generic plan's ability to push either
            -- comparison into the index. Branching in PL/pgSQL control flow
            -- instead keeps each query's index condition intact.
            v_delete_marker_peek_query :=
                'SELECT o.name FROM storage.objects o WHERE o.bucket_id = $1 ' ||
                'AND lower(o.name) COLLATE "C" >= $2' ||
                CASE WHEN v_upper_bound IS NOT NULL
                    THEN ' AND lower(o.name) COLLATE "C" < $3'
                    ELSE ''
                END ||
                v_version_filter ||
                ' ORDER BY lower(o.name) COLLATE "C" ASC LIMIT 1';
            -- Strict variant: used once the single-row ASC batch advance
            -- (below) has left v_next_seek pointing at the last row already
            -- emitted, so a plain >= would re-match it forever.
            v_delete_marker_peek_query_strict :=
                'SELECT o.name FROM storage.objects o WHERE o.bucket_id = $1 ' ||
                'AND lower(o.name) COLLATE "C" > $2' ||
                CASE WHEN v_upper_bound IS NOT NULL
                    THEN ' AND lower(o.name) COLLATE "C" < $3'
                    ELSE ''
                END ||
                v_version_filter ||
                ' ORDER BY lower(o.name) COLLATE "C" ASC LIMIT 1';
        ELSE
            v_delete_marker_peek_query :=
                'SELECT o.name FROM storage.objects o WHERE o.bucket_id = $1 ' ||
                'AND lower(o.name) COLLATE "C" < $2' ||
                CASE WHEN v_upper_bound IS NOT NULL
                    THEN ' AND lower(o.name) COLLATE "C" >= $3'
                    ELSE ''
                END ||
                v_version_filter ||
                ' ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1';
        END IF;
    END IF;

    -- Initialize seek position
    IF v_is_asc THEN
        v_next_seek := v_prefix_lower;
    ELSE
        -- DESC performs one specialized initial seek so partial current-version
        -- and delete-marker indexes remain available.
        EXECUTE format(
            'SELECT o.name FROM storage.objects o WHERE o.bucket_id = $1%s%s ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1',
            CASE WHEN v_upper_bound IS NOT NULL
                THEN ' AND lower(o.name) COLLATE "C" >= $2 AND lower(o.name) COLLATE "C" < $3'
                ELSE ''
            END,
            v_version_filter
        )
        INTO v_peek_name
        USING bucketname, v_prefix_lower, v_upper_bound;

        IF v_peek_name IS NOT NULL THEN
            v_next_seek := lower(v_peek_name) || v_delimiter;
        ELSE
            RETURN;
        END IF;
    END IF;

    -- ========================================================================
    -- MAIN LOOP: Hybrid peek-then-batch algorithm
    -- Uses STATIC SQL for peek (hot path) and DYNAMIC SQL for batch and
    -- the delete-marker-only path
    -- ========================================================================
    LOOP
        EXIT WHEN v_count >= v_limit;

        v_previous_seek := v_next_seek;
        v_previous_seek_at := v_next_seek_at;
        v_previous_seek_version := v_next_seek_version;
        v_previous_count := v_count;
        v_previous_skipped := v_skipped;

        -- STEP 1: PEEK
        v_peek_name := NULL;
        IF delete_markers = 'only' THEN
            EXECUTE CASE WHEN v_next_seek_strict
                THEN v_delete_marker_peek_query_strict
                ELSE v_delete_marker_peek_query
            END
                INTO v_peek_name
                USING bucketname, v_next_seek,
                    CASE WHEN v_is_asc THEN COALESCE(v_upper_bound, v_prefix_lower) ELSE v_prefix_lower END,
                    1, v_next_seek_at, v_next_seek_version;
        ELSIF v_multi_row AND v_next_seek_at IS NOT NULL THEN
            SELECT o.name INTO v_peek_name
            FROM storage.objects o
            WHERE o.bucket_id = bucketname
              AND lower(o.name) COLLATE "C" = v_next_seek
              AND (COALESCE(o.archived_at, 'infinity'::timestamptz) < v_next_seek_at
                   OR (COALESCE(o.archived_at, 'infinity'::timestamptz) = v_next_seek_at
                       AND COALESCE(o.version, '') > v_next_seek_version))
              AND (noncurrent_versions != 'exclude' OR o.archived_at IS NULL)
              AND (noncurrent_versions != 'only' OR o.archived_at IS NOT NULL)
              AND (delete_markers != 'exclude' OR NOT o.is_delete_marker)
              AND (delete_markers != 'only' OR o.is_delete_marker)
            ORDER BY COALESCE(o.archived_at, 'infinity'::timestamptz) DESC,
                     COALESCE(o.version, '') ASC
            LIMIT 1;

            -- The current key is exhausted. Clear its version boundary and
            -- make the following ASC name peek strict. Appending '/' is not a
            -- valid lexical successor because keys ending in characters such
            -- as '!' sort between the exhausted name and name || '/'.
            IF v_peek_name IS NULL THEN
                IF v_is_asc THEN
                    v_next_seek_strict := true;
                END IF;
                v_next_seek_at := NULL;
                v_next_seek_version := '';
            END IF;
        END IF;

        -- Single-row mode is always noncurrent_versions='exclude'. Keep the
        -- current-row predicate literal so generic plans use the current index.
        IF delete_markers != 'only' AND v_peek_name IS NULL AND NOT v_multi_row THEN
            IF v_is_asc THEN
                IF v_next_seek_strict AND v_upper_bound IS NOT NULL THEN
                    SELECT o.name INTO v_peek_name FROM storage.objects o
                    WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" > v_next_seek AND lower(o.name) COLLATE "C" < v_upper_bound
                      AND o.archived_at IS NULL
                      AND (delete_markers != 'exclude' OR NOT o.is_delete_marker)
                    ORDER BY lower(o.name) COLLATE "C" ASC LIMIT 1;
                ELSIF v_next_seek_strict THEN
                    SELECT o.name INTO v_peek_name FROM storage.objects o
                    WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" > v_next_seek
                      AND o.archived_at IS NULL
                      AND (delete_markers != 'exclude' OR NOT o.is_delete_marker)
                    ORDER BY lower(o.name) COLLATE "C" ASC LIMIT 1;
                ELSIF v_upper_bound IS NOT NULL THEN
                    SELECT o.name INTO v_peek_name FROM storage.objects o
                    WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_next_seek AND lower(o.name) COLLATE "C" < v_upper_bound
                      AND o.archived_at IS NULL
                      AND (delete_markers != 'exclude' OR NOT o.is_delete_marker)
                    ORDER BY lower(o.name) COLLATE "C" ASC LIMIT 1;
                ELSE
                    SELECT o.name INTO v_peek_name FROM storage.objects o
                    WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_next_seek
                      AND o.archived_at IS NULL
                      AND (delete_markers != 'exclude' OR NOT o.is_delete_marker)
                    ORDER BY lower(o.name) COLLATE "C" ASC LIMIT 1;
                END IF;
            ELSIF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" < v_next_seek AND lower(o.name) COLLATE "C" >= v_prefix_lower
                  AND o.archived_at IS NULL
                  AND (delete_markers != 'exclude' OR NOT o.is_delete_marker)
                ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" < v_next_seek
                  AND o.archived_at IS NULL
                  AND (delete_markers != 'exclude' OR NOT o.is_delete_marker)
                ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
            END IF;
        ELSIF delete_markers != 'only' AND v_peek_name IS NULL AND v_is_asc THEN
            IF v_next_seek_strict AND v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" > v_next_seek AND lower(o.name) COLLATE "C" < v_upper_bound
                  AND (noncurrent_versions != 'exclude' OR o.archived_at IS NULL)
                  AND (noncurrent_versions != 'only' OR o.archived_at IS NOT NULL)
                  AND (delete_markers != 'exclude' OR NOT o.is_delete_marker)
                  AND (delete_markers != 'only' OR o.is_delete_marker)
                ORDER BY lower(o.name) COLLATE "C" ASC LIMIT 1;
            ELSIF v_next_seek_strict THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" > v_next_seek
                  AND (noncurrent_versions != 'exclude' OR o.archived_at IS NULL)
                  AND (noncurrent_versions != 'only' OR o.archived_at IS NOT NULL)
                  AND (delete_markers != 'exclude' OR NOT o.is_delete_marker)
                  AND (delete_markers != 'only' OR o.is_delete_marker)
                ORDER BY lower(o.name) COLLATE "C" ASC LIMIT 1;
            ELSIF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_next_seek AND lower(o.name) COLLATE "C" < v_upper_bound
                  AND (noncurrent_versions != 'exclude' OR o.archived_at IS NULL)
                  AND (noncurrent_versions != 'only' OR o.archived_at IS NOT NULL)
                  AND (delete_markers != 'exclude' OR NOT o.is_delete_marker)
                  AND (delete_markers != 'only' OR o.is_delete_marker)
                ORDER BY lower(o.name) COLLATE "C" ASC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_next_seek
                  AND (noncurrent_versions != 'exclude' OR o.archived_at IS NULL)
                  AND (noncurrent_versions != 'only' OR o.archived_at IS NOT NULL)
                  AND (delete_markers != 'exclude' OR NOT o.is_delete_marker)
                  AND (delete_markers != 'only' OR o.is_delete_marker)
                ORDER BY lower(o.name) COLLATE "C" ASC LIMIT 1;
            END IF;
        ELSIF delete_markers != 'only' AND v_peek_name IS NULL THEN
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" < v_next_seek AND lower(o.name) COLLATE "C" >= v_prefix_lower
                  AND (noncurrent_versions != 'exclude' OR o.archived_at IS NULL)
                  AND (noncurrent_versions != 'only' OR o.archived_at IS NOT NULL)
                  AND (delete_markers != 'exclude' OR NOT o.is_delete_marker)
                  AND (delete_markers != 'only' OR o.is_delete_marker)
                ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" < v_next_seek
                  AND (noncurrent_versions != 'exclude' OR o.archived_at IS NULL)
                  AND (noncurrent_versions != 'only' OR o.archived_at IS NOT NULL)
                  AND (delete_markers != 'exclude' OR NOT o.is_delete_marker)
                  AND (delete_markers != 'only' OR o.is_delete_marker)
                ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
            END IF;
        END IF;

        EXIT WHEN v_peek_name IS NULL;

        -- If the peek landed on a different key than we were tracking, any
        -- version boundary belongs to the OLD key and must not leak into the
        -- new one - e.g. the deleteMarkers='only' peek doesn't know or care
        -- whether it's continuing the same key or jumping to a new one, so
        -- it never clears these itself.
        IF lower(v_peek_name) IS DISTINCT FROM v_next_seek THEN
            v_next_seek_at := NULL;
            v_next_seek_version := '';
        END IF;

        -- The peek is authoritative for the next key to process. This is
        -- especially important after exhausting a multi-version key: the
        -- version boundary has been cleared, so executing the batch against
        -- a stale v_next_seek would replay every version of that old key.
        v_next_seek := lower(v_peek_name);
        v_next_seek_strict := false;

        -- STEP 2: Check if this is a FOLDER or FILE
        v_common_prefix := storage.get_common_prefix(lower(v_peek_name), v_prefix_lower, v_delimiter);

        IF v_common_prefix IS NOT NULL THEN
            -- FOLDER: Handle offset, emit if needed, skip to next folder
            IF v_skipped < offsets THEN
                v_skipped := v_skipped + 1;
            ELSE
                name := substring(rtrim(storage.get_common_prefix(v_peek_name, v_prefix, v_delimiter), v_delimiter) from v_prefix_len + 1);
                id := NULL;
                updated_at := NULL;
                created_at := NULL;
                last_accessed_at := NULL;
                metadata := NULL;
                version := NULL;
                archived_at := NULL;
                is_delete_marker := NULL;
                is_versioned := NULL;
                RETURN NEXT;
                v_count := v_count + 1;
            END IF;

            -- Advance seek past the folder range
            IF v_is_asc THEN
                v_next_seek := lower(left(v_common_prefix, -1)) || chr(ascii(v_delimiter) + 1);
            ELSE
                v_next_seek := lower(v_common_prefix);
            END IF;
            v_next_seek_at := NULL;
            v_next_seek_version := '';
        ELSE
            -- FILE: Batch fetch using DYNAMIC SQL (overhead amortized over many rows)
            -- For ASC: upper_bound is the exclusive upper limit (< condition)
            -- For DESC: prefix_lower is the inclusive lower limit (>= condition)
            FOR v_current IN EXECUTE v_batch_query
                USING bucketname, v_next_seek,
                    CASE WHEN v_is_asc THEN COALESCE(v_upper_bound, v_prefix_lower) ELSE v_prefix_lower END, v_file_batch_size,
                    v_next_seek_at, v_next_seek_version
            LOOP
                v_common_prefix := storage.get_common_prefix(lower(v_current.name), v_prefix_lower, v_delimiter);

                IF v_common_prefix IS NOT NULL THEN
                    -- Hit a folder: exit batch, let peek handle it. Reset
                    -- strict mode too - it may have been set by an earlier
                    -- row in this same batch (see the single-row ASC advance
                    -- below), and v_next_seek here is the folder-triggering
                    -- row's own name, which the next peek must find inclusively.
                    v_next_seek := CASE
                        WHEN v_is_asc THEN lower(v_current.name)
                        ELSE lower(v_current.name) || v_delimiter
                    END;
                    v_next_seek_at := NULL;
                    v_next_seek_version := '';
                    v_next_seek_strict := false;
                    EXIT;
                END IF;

                -- Handle offset skipping
                IF v_skipped < offsets THEN
                    v_skipped := v_skipped + 1;
                ELSE
                    -- Emit file
                    name := substring(v_current.name from v_prefix_len + 1);
                    id := v_current.id;
                    updated_at := v_current.updated_at;
                    created_at := v_current.created_at;
                    last_accessed_at := v_current.last_accessed_at;
                    metadata := v_current.metadata;
                    version := v_current.version;
                    archived_at := v_current.archived_at;
                    is_delete_marker := v_current.is_delete_marker;
                    is_versioned := v_current.is_versioned;
                    RETURN NEXT;
                    v_count := v_count + 1;
                END IF;

                -- Multi-row mode must remain on this key until all of its
                -- versions have crossed the internal batch boundary.
                IF v_multi_row THEN
                    v_next_seek := lower(v_current.name);
                    v_next_seek_at := COALESCE(v_current.archived_at, 'infinity'::timestamptz);
                    v_next_seek_version := COALESCE(v_current.version, '');
                ELSIF v_is_asc THEN
                    -- Appending the delimiter as a fake lexical successor would
                    -- skip a real key like `name || '!'` (or any character
                    -- sorting below the delimiter), which sorts between `name`
                    -- and `name || delimiter`. Track the real name and mark the
                    -- next comparison strict instead - same fix as the
                    -- exhausted-key case above.
                    v_next_seek := lower(v_current.name);
                    v_next_seek_strict := true;
                ELSE
                    v_next_seek := lower(v_current.name);
                END IF;

                EXIT WHEN v_count >= v_limit;
            END LOOP;
        END IF;

        IF v_count = v_previous_count
           AND v_skipped = v_previous_skipped
           AND v_next_seek IS NOT DISTINCT FROM v_previous_seek
           AND v_next_seek_at IS NOT DISTINCT FROM v_previous_seek_at
           AND v_next_seek_version IS NOT DISTINCT FROM v_previous_seek_version THEN
            RAISE EXCEPTION 'storage.search made no progress at seek (%, %, %)',
                v_next_seek, v_next_seek_at, v_next_seek_version;
        END IF;
    END LOOP;
END;
$_$;


ALTER FUNCTION "storage"."search"("prefix" "text", "bucketname" "text", "limits" integer, "levels" integer, "offsets" integer, "search" "text", "sortcolumn" "text", "sortorder" "text", "noncurrent_versions" "text", "delete_markers" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."search_by_timestamp"("p_prefix" "text", "p_bucket_id" "text", "p_limit" integer, "p_level" integer, "p_start_after" "text", "p_sort_order" "text", "p_sort_column" "text", "p_sort_column_after" "text", "noncurrent_versions" "text" DEFAULT 'exclude'::"text", "delete_markers" "text" DEFAULT 'exclude'::"text", "p_start_after_version" "text" DEFAULT ''::"text") RETURNS TABLE("key" "text", "name" "text", "id" "uuid", "updated_at" timestamp with time zone, "created_at" timestamp with time zone, "last_accessed_at" timestamp with time zone, "metadata" "jsonb", "version" "text", "archived_at" timestamp with time zone, "is_delete_marker" boolean, "is_versioned" boolean)
    LANGUAGE "plpgsql" STABLE
    AS $_$
DECLARE
    v_cursor_op text;
    v_query text;
    v_prefix text;
    v_prefix_pattern text;
    v_sort_order text;
    v_sort_column text;
    v_version_tiebreak text;
BEGIN
    v_prefix := coalesce(p_prefix, '');
    -- Keep the raw prefix for common-prefix calculations and escape only LIKE metacharacters.
    v_prefix_pattern := replace(v_prefix, chr(92), chr(92) || chr(92));
    v_prefix_pattern := replace(v_prefix_pattern, '%', chr(92) || '%');
    v_prefix_pattern := replace(v_prefix_pattern, '_', chr(92) || '_');

    -- COALESCE first: NULL NOT IN (...) evaluates to NULL (not TRUE), so a
    -- bare NOT IN check silently leaves an explicit NULL argument unreset.
    noncurrent_versions := COALESCE(noncurrent_versions, 'exclude');
    delete_markers := COALESCE(delete_markers, 'exclude');
    IF noncurrent_versions NOT IN ('exclude', 'only', 'include') THEN
        noncurrent_versions := 'exclude';
    END IF;
    IF delete_markers NOT IN ('exclude', 'only', 'include') THEN
        delete_markers := 'exclude';
    END IF;

    -- $9 is only populated in multi-row mode; it's always '' otherwise, so
    -- only use each row's real version as a tiebreak in multi-row mode.
    v_version_tiebreak := CASE WHEN noncurrent_versions IN ('only', 'include') THEN 'COALESCE(version, '''')' ELSE '''''' END;

    -- Defense-in-depth: this function is independently reachable and must
    -- not trust p_sort_order/p_sort_column to already be validated by a
    -- caller. Normalize to the same strict allow-list storage.search_v2
    -- uses before interpolating anything into dynamic SQL below.
    v_sort_order := lower(coalesce(p_sort_order, 'asc'));
    IF v_sort_order NOT IN ('asc', 'desc') THEN
        v_sort_order := 'asc';
    END IF;

    v_sort_column := lower(coalesce(p_sort_column, 'updated_at'));
    IF v_sort_column NOT IN ('updated_at', 'created_at') THEN
        v_sort_column := 'updated_at';
    END IF;

    IF v_sort_order = 'asc' THEN
        v_cursor_op := '>';
    ELSE
        v_cursor_op := '<';
    END IF;

    v_query := format($sql$
        WITH raw_objects AS (
            SELECT
                o.name AS obj_name,
                o.id AS obj_id,
                o.updated_at AS obj_updated_at,
                o.created_at AS obj_created_at,
                o.last_accessed_at AS obj_last_accessed_at,
                o.metadata AS obj_metadata,
                o.version AS obj_version,
                o.archived_at AS obj_archived_at,
                o.is_delete_marker AS obj_is_delete_marker,
                o.is_versioned AS obj_is_versioned,
                storage.get_common_prefix(o.name, $1, '/') AS common_prefix
            FROM storage.objects o
            WHERE o.bucket_id = $2
              AND o.name COLLATE "C" LIKE $10 || '%%'
              AND ($7 != 'exclude' OR o.archived_at IS NULL)
              AND ($7 != 'only' OR o.archived_at IS NOT NULL)
              AND ($8 != 'exclude' OR NOT o.is_delete_marker)
              AND ($8 != 'only' OR o.is_delete_marker)
        ),
        -- Aggregate common prefixes (folders)
        -- Both created_at and updated_at use MIN(obj_created_at) to match the old prefixes table behavior
        aggregated_prefixes AS (
            SELECT
                common_prefix AS name,
                NULL::uuid AS id,
                MIN(obj_created_at) AS updated_at,
                MIN(obj_created_at) AS created_at,
                NULL::timestamptz AS last_accessed_at,
                NULL::jsonb AS metadata,
                NULL::text AS version,
                NULL::timestamptz AS archived_at,
                NULL::boolean AS is_delete_marker,
                NULL::boolean AS is_versioned,
                TRUE AS is_prefix
            FROM raw_objects
            WHERE common_prefix IS NOT NULL
            GROUP BY common_prefix
        ),
        leaf_objects AS (
            SELECT
                obj_name AS name,
                obj_id AS id,
                obj_updated_at AS updated_at,
                obj_created_at AS created_at,
                obj_last_accessed_at AS last_accessed_at,
                obj_metadata AS metadata,
                obj_version AS version,
                obj_archived_at AS archived_at,
                obj_is_delete_marker AS is_delete_marker,
                obj_is_versioned AS is_versioned,
                FALSE AS is_prefix
            FROM raw_objects
            WHERE common_prefix IS NULL
        ),
        combined AS (
            SELECT * FROM aggregated_prefixes
            UNION ALL
            SELECT * FROM leaf_objects
        ),
        filtered AS (
            SELECT *
            FROM combined
            WHERE (
                $5 = ''
                OR ROW(
                    COALESCE(date_trunc('milliseconds', %I), 'epoch'::timestamptz),
                    name COLLATE "C",
                    %s
                ) %s ROW(
                    -- truncated the same way as the stored value above
                    date_trunc('milliseconds', COALESCE(NULLIF($6, '')::timestamptz, 'epoch'::timestamptz)),
                    $5,
                    $9
                )
            )
        )
        SELECT
            split_part(name, '/', $3) AS key,
            name,
            id,
            updated_at,
            created_at,
            last_accessed_at,
            metadata,
            version,
            archived_at,
            is_delete_marker,
            is_versioned
        FROM filtered
        ORDER BY
            COALESCE(date_trunc('milliseconds', %I), 'epoch'::timestamptz) %s,
            name COLLATE "C" %s,
            COALESCE(version, '') %s
        LIMIT $4
    $sql$,
        v_sort_column,
        v_version_tiebreak,
        v_cursor_op,
        v_sort_column,
        v_sort_order,
        v_sort_order,
        v_sort_order
    );

    -- version is the third tiebreak component for two versions of the same
    -- key tying on both timestamp and name (see filtered CTE / ORDER BY above)
    RETURN QUERY EXECUTE v_query
    USING v_prefix, p_bucket_id, p_level, p_limit, p_start_after, p_sort_column_after, noncurrent_versions, delete_markers, coalesce(p_start_after_version, ''), v_prefix_pattern;
END;
$_$;


ALTER FUNCTION "storage"."search_by_timestamp"("p_prefix" "text", "p_bucket_id" "text", "p_limit" integer, "p_level" integer, "p_start_after" "text", "p_sort_order" "text", "p_sort_column" "text", "p_sort_column_after" "text", "noncurrent_versions" "text", "delete_markers" "text", "p_start_after_version" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."search_v2"("prefix" "text", "bucket_name" "text", "limits" integer DEFAULT 100, "levels" integer DEFAULT 1, "start_after" "text" DEFAULT ''::"text", "sort_order" "text" DEFAULT 'asc'::"text", "sort_column" "text" DEFAULT 'name'::"text", "sort_column_after" "text" DEFAULT ''::"text", "noncurrent_versions" "text" DEFAULT 'exclude'::"text", "delete_markers" "text" DEFAULT 'exclude'::"text", "start_after_archived_at" timestamp with time zone DEFAULT NULL::timestamp with time zone, "start_after_version" "text" DEFAULT ''::"text", "start_after_is_continuation" boolean DEFAULT false) RETURNS TABLE("key" "text", "name" "text", "id" "uuid", "updated_at" timestamp with time zone, "created_at" timestamp with time zone, "last_accessed_at" timestamp with time zone, "metadata" "jsonb", "version" "text", "archived_at" timestamp with time zone, "is_delete_marker" boolean, "is_versioned" boolean)
    LANGUAGE "plpgsql" STABLE
    AS $$
DECLARE
    v_sort_col text;
    v_sort_ord text;
    v_limit int;
BEGIN
    -- Cap limit to maximum of 1500 records
    v_limit := LEAST(coalesce(limits, 100), 1500);

    -- Validate and normalize sort_order
    v_sort_ord := lower(coalesce(sort_order, 'asc'));
    IF v_sort_ord NOT IN ('asc', 'desc') THEN
        v_sort_ord := 'asc';
    END IF;

    -- Validate and normalize sort_column
    v_sort_col := lower(coalesce(sort_column, 'name'));
    IF v_sort_col NOT IN ('name', 'updated_at', 'created_at') THEN
        v_sort_col := 'name';
    END IF;

    -- Route to appropriate implementation
    IF v_sort_col = 'name' THEN
        -- Use list_objects_with_delimiter for name sorting (most efficient: O(k * log n))
        RETURN QUERY
        SELECT
            split_part(l.name, '/', levels) AS key,
            l.name AS name,
            l.id,
            l.updated_at,
            l.created_at,
            l.last_accessed_at,
            l.metadata,
            l.version,
            l.archived_at,
            l.is_delete_marker,
            l.is_versioned
        FROM storage.list_objects_with_delimiter(
            bucket_name,
            coalesce(prefix, ''),
            '/',
            v_limit,
            CASE WHEN start_after_is_continuation THEN '' ELSE start_after END,
            CASE WHEN start_after_is_continuation THEN start_after ELSE '' END,
            v_sort_ord,
            noncurrent_versions,
            delete_markers,
            start_after_archived_at,
            start_after_version
        ) l;
    ELSE
        -- Use aggregation approach for timestamp sorting
        -- Not efficient for large datasets but supports correct pagination
        RETURN QUERY SELECT * FROM storage.search_by_timestamp(
            prefix, bucket_name, v_limit, levels, start_after,
            v_sort_ord, v_sort_col, sort_column_after,
            noncurrent_versions, delete_markers, start_after_version
        );
    END IF;
END;
$$;


ALTER FUNCTION "storage"."search_v2"("prefix" "text", "bucket_name" "text", "limits" integer, "levels" integer, "start_after" "text", "sort_order" "text", "sort_column" "text", "sort_column_after" "text", "noncurrent_versions" "text", "delete_markers" "text", "start_after_archived_at" timestamp with time zone, "start_after_version" "text", "start_after_is_continuation" boolean) OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW; 
END;
$$;


ALTER FUNCTION "storage"."update_updated_at_column"() OWNER TO "supabase_storage_admin";


CREATE TABLE IF NOT EXISTS "public"."anuncios" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "usuario_id" "uuid" NOT NULL,
    "marca_id" "uuid",
    "modelo_id" "uuid",
    "versao_id" "uuid",
    "titulo" "text" DEFAULT 'Anúncio de Veículo'::"text",
    "descricao" "text",
    "preco" numeric(12,2) NOT NULL,
    "ano_fabricacao" integer NOT NULL,
    "ano_modelo" integer NOT NULL,
    "quilometragem" integer NOT NULL,
    "cor" "text",
    "final_placa" character(1),
    "combustivel" "public"."tipo_combustivel",
    "cambio" "public"."tipo_cambio",
    "cep" "text",
    "cidade" "text" NOT NULL,
    "estado" character(2) NOT NULL,
    "whatsapp" "text",
    "status" "public"."status_anuncio" DEFAULT 'ativo'::"public"."status_anuncio" NOT NULL,
    "visualizacoes" integer DEFAULT 0 NOT NULL,
    "criado_em" timestamp with time zone DEFAULT "now"(),
    "atualizado_em" timestamp with time zone DEFAULT "now"(),
    "curtidas" integer DEFAULT 0,
    "ultimo_anuncio" timestamp with time zone,
    "latitude" double precision,
    "longitude" double precision,
    "cidade_display" "text",
    "data_venda" timestamp with time zone,
    "status_moderacao" "text" DEFAULT 'pendente'::"text",
    "pausado" boolean DEFAULT false,
    "tipo_veiculo" "text" DEFAULT 'carro'::"text",
    "modelo_texto" "text",
    "marca_texto" "text",
    "horas_motor" integer,
    CONSTRAINT "anuncios_preco_check" CHECK (("preco" > (0)::numeric)),
    CONSTRAINT "anuncios_quilometragem_check" CHECK (("quilometragem" >= 0)),
    CONSTRAINT "anuncios_tipo_veiculo_check" CHECK (("tipo_veiculo" = ANY (ARRAY['carro'::"text", 'caminhao'::"text", 'moto'::"text", 'utilitario'::"text", 'embarcacao'::"text", 'maquina_agricola'::"text", 'onibus'::"text"]))),
    CONSTRAINT "chk_estado_valido" CHECK (("estado" ~ '^[A-Z]{2}$'::"text")),
    CONSTRAINT "chk_final_placa" CHECK ((("final_placa" IS NULL) OR ("final_placa" ~ '^[0-9]$'::"text")))
);


ALTER TABLE "public"."anuncios" OWNER TO "postgres";


COMMENT ON COLUMN "public"."anuncios"."quilometragem" IS 'Km rodados. Usado para carro, caminhao, moto, utilitario, maquina_agricola. NULL quando tipo_veiculo = ''embarcacao''.';



COMMENT ON COLUMN "public"."anuncios"."horas_motor" IS 'Horas de uso do motor. Preenchido só quando tipo_veiculo = ''embarcacao''; nesse caso quilometragem fica NULL.';



CREATE TABLE IF NOT EXISTS "public"."anuncios_opcionais" (
    "anuncio_id" "uuid" NOT NULL,
    "opcional_id" "uuid" NOT NULL,
    "criado_em" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."anuncios_opcionais" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."avaliacoes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "avaliador_id" "uuid" NOT NULL,
    "avaliado_id" "uuid" NOT NULL,
    "nota" integer,
    "comentario" "text",
    "criado_em" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "avaliacoes_nota_check" CHECK ((("nota" >= 1) AND ("nota" <= 5)))
);


ALTER TABLE "public"."avaliacoes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."carrinho_itens" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "usuario_id" "uuid" NOT NULL,
    "anuncio_id" "uuid" NOT NULL,
    "criado_em" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."carrinho_itens" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."comunidade_comentarios" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "post_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "texto" "text" NOT NULL,
    "criado_em" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."comunidade_comentarios" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."comunidade_curtidas" (
    "post_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL
);


ALTER TABLE "public"."comunidade_curtidas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."comunidade_posts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "veiculo_id" "uuid",
    "tipo" "text" DEFAULT 'foto'::"text",
    "legenda" "text",
    "curtidas" integer DEFAULT 0,
    "criado_em" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "comunidade_posts_tipo_check" CHECK (("tipo" = ANY (ARRAY['foto'::"text", 'restauracao'::"text", 'modificacao'::"text", 'viagem'::"text", 'outro'::"text"])))
);


ALTER TABLE "public"."comunidade_posts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."comunidade_posts_fotos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "post_id" "uuid" NOT NULL,
    "url" "text" NOT NULL,
    "ordem" integer DEFAULT 0
);


ALTER TABLE "public"."comunidade_posts_fotos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."config_usuario" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "usuario_id" "uuid" NOT NULL,
    "tema" "text" DEFAULT 'claro'::"text",
    "notificacoes_email" boolean DEFAULT true,
    "notificacoes_site" boolean DEFAULT true,
    "privacidade_perfil" "text" DEFAULT 'publico'::"text",
    "atualizado_em" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."config_usuario" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."conversas" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "usuario1_id" "uuid",
    "usuario2_id" "uuid",
    "anuncio_id" "uuid",
    "carro_info" "text",
    "ultima_mensagem" "text",
    "ultima_mensagem_data" timestamp with time zone DEFAULT "now"(),
    "criado_em" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."conversas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."curtidas_anuncio" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "anuncio_id" "uuid" NOT NULL,
    "usuario_id" "uuid" NOT NULL,
    "criado_em" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."curtidas_anuncio" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."curtidas_post" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "post_id" "uuid" NOT NULL,
    "usuario_id" "uuid" NOT NULL,
    "criado_em" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."curtidas_post" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."denuncias" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "denunciante_id" "uuid" NOT NULL,
    "tipo" "text" NOT NULL,
    "alvo_id" "uuid" NOT NULL,
    "motivo" "text" NOT NULL,
    "descricao" "text",
    "status" "text" DEFAULT 'pendente'::"text",
    "criado_em" timestamp with time zone DEFAULT "now"(),
    "resolvido_em" timestamp with time zone,
    "resolvido_por" "uuid",
    CONSTRAINT "denuncias_status_check" CHECK (("status" = ANY (ARRAY['pendente'::"text", 'analisada'::"text", 'rejeitada'::"text", 'acao_tomada'::"text", 'resolvido'::"text"]))),
    CONSTRAINT "denuncias_tipo_check" CHECK (("tipo" = ANY (ARRAY['anuncio'::"text", 'perfil'::"text"])))
);


ALTER TABLE "public"."denuncias" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."encontros" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "criador_id" "uuid",
    "nome" "text" NOT NULL,
    "descricao" "text",
    "regras" "text",
    "requisitos" "text",
    "tipo_veiculo" "text" DEFAULT 'todos'::"text",
    "data" "date" NOT NULL,
    "hora" time without time zone,
    "local_nome" "text",
    "cidade" "text",
    "estado" character(2),
    "lat" numeric(10,7),
    "lng" numeric(10,7),
    "ativo" boolean DEFAULT true,
    "criado_em" timestamp with time zone DEFAULT "now"(),
    "status" "text" DEFAULT 'approved'::"text",
    "veiculo_id" "uuid",
    CONSTRAINT "encontros_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'approved'::"text", 'rejected'::"text"]))),
    CONSTRAINT "encontros_tipo_veiculo_check" CHECK (("tipo_veiculo" = ANY (ARRAY['todos'::"text", 'antigos'::"text", 'jdm'::"text", 'esportivos'::"text", 'muscle'::"text", 'eletricos'::"text", 'motos'::"text"])))
);


ALTER TABLE "public"."encontros" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."encontros_confirmados" (
    "encontro_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "confirmado_em" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."encontros_confirmados" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."favoritos" (
    "usuario_id" "uuid" NOT NULL,
    "anuncio_id" "uuid" NOT NULL,
    "criado_em" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."favoritos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."fotos_anuncio" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "anuncio_id" "uuid" NOT NULL,
    "url_foto" "text" NOT NULL,
    "ordem" integer DEFAULT 0 NOT NULL,
    "caminho" "text",
    "criado_em" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."fotos_anuncio" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."garagem_fotos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "veiculo_id" "uuid" NOT NULL,
    "url" "text" NOT NULL,
    "legenda" "text",
    "criado_em" timestamp with time zone DEFAULT "now"(),
    "path" "text",
    "ordem" integer DEFAULT 0
);


ALTER TABLE "public"."garagem_fotos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."garagem_gastos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "veiculo_id" "uuid" NOT NULL,
    "categoria" "text" NOT NULL,
    "descricao" "text",
    "valor" numeric(10,2) NOT NULL,
    "data" "date" NOT NULL,
    "criado_em" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "garagem_gastos_categoria_check" CHECK (("categoria" = ANY (ARRAY['manutencao'::"text", 'combustivel'::"text", 'seguro'::"text", 'ipva'::"text", 'peca'::"text", 'outro'::"text"])))
);


ALTER TABLE "public"."garagem_gastos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."garagem_lembretes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "veiculo_id" "uuid" NOT NULL,
    "titulo" "text" NOT NULL,
    "data_prevista" "date",
    "km_prevista" integer,
    "concluido" boolean DEFAULT false,
    "criado_em" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."garagem_lembretes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."garagem_manutencoes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "veiculo_id" "uuid" NOT NULL,
    "tipo" "text" NOT NULL,
    "descricao" "text",
    "data" "date" NOT NULL,
    "km_na_manutencao" integer,
    "custo" numeric(10,2),
    "oficina" "text",
    "observacoes" "text",
    "criado_em" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "garagem_manutencoes_tipo_check" CHECK (("tipo" = ANY (ARRAY['oleo'::"text", 'pneu'::"text", 'revisao'::"text", 'peca'::"text", 'outro'::"text"])))
);


ALTER TABLE "public"."garagem_manutencoes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."garagem_veiculos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "marca" "text" NOT NULL,
    "modelo" "text" NOT NULL,
    "ano" integer,
    "versao" "text",
    "cor" "text",
    "km_atual" integer DEFAULT 0,
    "foto_principal" "text",
    "ativo" boolean DEFAULT true,
    "criado_em" timestamp with time zone DEFAULT "now"(),
    "motor" "text",
    "cambio" "text",
    "combustivel" "text",
    "potencia" integer,
    CONSTRAINT "garagem_veiculos_cambio_check" CHECK (("cambio" = ANY (ARRAY['manual'::"text", 'automatico'::"text", 'cvt'::"text", 'automatizado'::"text"]))),
    CONSTRAINT "garagem_veiculos_combustivel_check" CHECK (("combustivel" = ANY (ARRAY['flex'::"text", 'gasolina'::"text", 'etanol'::"text", 'diesel'::"text", 'eletrico'::"text", 'hibrido'::"text", 'gnv'::"text"])))
);


ALTER TABLE "public"."garagem_veiculos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."marcas" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "nome" "text" NOT NULL,
    "criado_em" timestamp with time zone DEFAULT "now"(),
    "categoria" "text" DEFAULT 'carro'::"text"
);


ALTER TABLE "public"."marcas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."mensagens" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "remetente_id" "uuid",
    "destinatario_id" "uuid",
    "anuncio_id" "uuid",
    "conteudo" "text" NOT NULL,
    "carro_info" "text",
    "lida" boolean DEFAULT false,
    "data_envio" timestamp with time zone DEFAULT "now"(),
    "criado_em" timestamp with time zone DEFAULT "now"(),
    "tipo" "text" DEFAULT 'texto'::"text"
);


ALTER TABLE "public"."mensagens" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."modelos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "marca_id" "uuid" NOT NULL,
    "nome" "text" NOT NULL,
    "criado_em" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."modelos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."opcionais" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "nome" "text" NOT NULL,
    "tipo" "text",
    "criado_em" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."opcionais" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."posts_usuario" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "usuario_id" "uuid" NOT NULL,
    "imagem" "text" NOT NULL,
    "legenda" "text",
    "curtidas" integer DEFAULT 0,
    "criado_em" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."posts_usuario" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."projetos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "veiculo_id" "uuid",
    "nome" "text" NOT NULL,
    "descricao" "text",
    "status" "text" DEFAULT 'em_andamento'::"text",
    "curtidas" integer DEFAULT 0,
    "criado_em" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "projetos_status_check" CHECK (("status" = ANY (ARRAY['em_andamento'::"text", 'concluido'::"text", 'pausado'::"text"])))
);


ALTER TABLE "public"."projetos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."projetos_atualizacoes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "projeto_id" "uuid" NOT NULL,
    "titulo" "text" NOT NULL,
    "descricao" "text",
    "etapa" "text",
    "criado_em" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "projetos_atualizacoes_etapa_check" CHECK (("etapa" = ANY (ARRAY['antes'::"text", 'durante'::"text", 'depois'::"text"])))
);


ALTER TABLE "public"."projetos_atualizacoes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."projetos_atualizacoes_fotos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "atualizacao_id" "uuid" NOT NULL,
    "url" "text" NOT NULL,
    "ordem" integer DEFAULT 0
);


ALTER TABLE "public"."projetos_atualizacoes_fotos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."projetos_comentarios" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "projeto_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "texto" "text" NOT NULL,
    "criado_em" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."projetos_comentarios" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."projetos_curtidas" (
    "projeto_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL
);


ALTER TABLE "public"."projetos_curtidas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."propostas" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "anuncio_id" "uuid" NOT NULL,
    "comprador_id" "uuid" NOT NULL,
    "vendedor_id" "uuid" NOT NULL,
    "mensagem" "text" NOT NULL,
    "valor_proposta" numeric(12,2),
    "criado_em" timestamp with time zone DEFAULT "now"(),
    "status" "public"."status_proposta" DEFAULT 'pendente'::"public"."status_proposta"
);


ALTER TABLE "public"."propostas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."seguidores" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "seguidor_id" "uuid" NOT NULL,
    "seguido_id" "uuid" NOT NULL,
    "criado_em" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."seguidores" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."usuarios_banidos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "usuario_id" "uuid" NOT NULL,
    "motivo" "text" NOT NULL,
    "banido_por" "uuid",
    "banido_em" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."usuarios_banidos" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."usuarios_publicos" AS
 SELECT "id",
    "nome",
    "foto",
    "capa_foto",
    "cidade",
    "estado",
    "bio",
    "site",
    "instagram",
    "seguidores",
    "seguindo",
    "nota_media",
    "total_avaliacoes",
    "criado_em"
   FROM "public"."usuarios";


ALTER VIEW "public"."usuarios_publicos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."versoes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "modelo_id" "uuid" NOT NULL,
    "nome" "text" NOT NULL,
    "criado_em" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."versoes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "storage"."buckets" (
    "id" "text" NOT NULL,
    "name" "text" NOT NULL,
    "owner" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "public" boolean DEFAULT false,
    "avif_autodetection" boolean DEFAULT false,
    "file_size_limit" bigint,
    "allowed_mime_types" "text"[],
    "owner_id" "text",
    "type" "storage"."buckettype" DEFAULT 'STANDARD'::"storage"."buckettype" NOT NULL,
    "versioning_status" "text" DEFAULT 'DISABLED'::"text" NOT NULL,
    "lifecycle_configuration" "jsonb",
    "lifecycle_configuration_generation" "uuid",
    CONSTRAINT "buckets_lifecycle_configuration_pair_check" CHECK ((("lifecycle_configuration" IS NULL) = ("lifecycle_configuration_generation" IS NULL))),
    CONSTRAINT "buckets_lifecycle_configuration_shape_check" CHECK ((("lifecycle_configuration" IS NULL) OR (("jsonb_typeof"("lifecycle_configuration") = 'object'::"text") AND ("lifecycle_configuration" ? 'rules'::"text") AND
CASE
    WHEN ("jsonb_typeof"(("lifecycle_configuration" -> 'rules'::"text")) = 'array'::"text") THEN (("jsonb_array_length"(("lifecycle_configuration" -> 'rules'::"text")) >= 1) AND ("jsonb_array_length"(("lifecycle_configuration" -> 'rules'::"text")) <= 1000))
    ELSE false
END))),
    CONSTRAINT "buckets_lifecycle_configuration_standard_only_check" CHECK ((("type" = 'STANDARD'::"storage"."buckettype") OR (("lifecycle_configuration" IS NULL) AND ("lifecycle_configuration_generation" IS NULL)))),
    CONSTRAINT "buckets_versioning_dark_check" CHECK (("versioning_status" = 'DISABLED'::"text")),
    CONSTRAINT "buckets_versioning_standard_only_check" CHECK ((("type" = 'STANDARD'::"storage"."buckettype") OR ("versioning_status" = 'DISABLED'::"text"))),
    CONSTRAINT "buckets_versioning_status_check" CHECK (("versioning_status" = ANY (ARRAY['DISABLED'::"text", 'ENABLED'::"text", 'SUSPENDED'::"text"])))
);


ALTER TABLE "storage"."buckets" OWNER TO "supabase_storage_admin";


COMMENT ON COLUMN "storage"."buckets"."owner" IS 'Field is deprecated, use owner_id instead';



CREATE TABLE IF NOT EXISTS "storage"."buckets_analytics" (
    "name" "text" NOT NULL,
    "type" "storage"."buckettype" DEFAULT 'ANALYTICS'::"storage"."buckettype" NOT NULL,
    "format" "text" DEFAULT 'ICEBERG'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "deleted_at" timestamp with time zone
);


ALTER TABLE "storage"."buckets_analytics" OWNER TO "supabase_storage_admin";


CREATE TABLE IF NOT EXISTS "storage"."buckets_vectors" (
    "id" "text" NOT NULL,
    "type" "storage"."buckettype" DEFAULT 'VECTOR'::"storage"."buckettype" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "storage"."buckets_vectors" OWNER TO "supabase_storage_admin";


CREATE TABLE IF NOT EXISTS "storage"."migrations" (
    "id" integer NOT NULL,
    "name" character varying(100) NOT NULL,
    "hash" character varying(40) NOT NULL,
    "executed_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "storage"."migrations" OWNER TO "supabase_storage_admin";


CREATE TABLE IF NOT EXISTS "storage"."objects" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "bucket_id" "text",
    "name" "text",
    "owner" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "last_accessed_at" timestamp with time zone DEFAULT "now"(),
    "metadata" "jsonb",
    "path_tokens" "text"[] GENERATED ALWAYS AS ("string_to_array"("name", '/'::"text")) STORED,
    "version" "text",
    "owner_id" "text",
    "user_metadata" "jsonb",
    "archived_at" timestamp with time zone,
    "is_delete_marker" boolean DEFAULT false NOT NULL,
    "is_versioned" boolean DEFAULT false NOT NULL
);


ALTER TABLE "storage"."objects" OWNER TO "supabase_storage_admin";


COMMENT ON COLUMN "storage"."objects"."owner" IS 'Field is deprecated, use owner_id instead';



CREATE TABLE IF NOT EXISTS "storage"."s3_multipart_uploads" (
    "id" "text" NOT NULL,
    "in_progress_size" bigint DEFAULT 0 NOT NULL,
    "upload_signature" "text" NOT NULL,
    "bucket_id" "text" NOT NULL,
    "key" "text" NOT NULL COLLATE "pg_catalog"."C",
    "version" "text" NOT NULL,
    "owner_id" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "user_metadata" "jsonb",
    "metadata" "jsonb"
);


ALTER TABLE "storage"."s3_multipart_uploads" OWNER TO "supabase_storage_admin";


CREATE TABLE IF NOT EXISTS "storage"."s3_multipart_uploads_parts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "upload_id" "text" NOT NULL,
    "size" bigint DEFAULT 0 NOT NULL,
    "part_number" integer NOT NULL,
    "bucket_id" "text" NOT NULL,
    "key" "text" NOT NULL COLLATE "pg_catalog"."C",
    "etag" "text" NOT NULL,
    "owner_id" "text",
    "version" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "storage"."s3_multipart_uploads_parts" OWNER TO "supabase_storage_admin";


CREATE TABLE IF NOT EXISTS "storage"."vector_indexes" (
    "id" "text" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL COLLATE "pg_catalog"."C",
    "bucket_id" "text" NOT NULL,
    "data_type" "text" NOT NULL,
    "dimension" integer NOT NULL,
    "distance_metric" "text" NOT NULL,
    "metadata_configuration" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "storage"."vector_indexes" OWNER TO "supabase_storage_admin";


ALTER TABLE ONLY "public"."anuncios_opcionais"
    ADD CONSTRAINT "anuncios_opcionais_pkey" PRIMARY KEY ("anuncio_id", "opcional_id");



ALTER TABLE ONLY "public"."anuncios"
    ADD CONSTRAINT "anuncios_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."avaliacoes"
    ADD CONSTRAINT "avaliacoes_avaliador_avaliado_unica" UNIQUE ("avaliador_id", "avaliado_id");



ALTER TABLE ONLY "public"."avaliacoes"
    ADD CONSTRAINT "avaliacoes_avaliador_id_avaliado_id_key" UNIQUE ("avaliador_id", "avaliado_id");



ALTER TABLE ONLY "public"."avaliacoes"
    ADD CONSTRAINT "avaliacoes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."carrinho_itens"
    ADD CONSTRAINT "carrinho_itens_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."carrinho_itens"
    ADD CONSTRAINT "carrinho_itens_usuario_id_anuncio_id_key" UNIQUE ("usuario_id", "anuncio_id");



ALTER TABLE ONLY "public"."comunidade_comentarios"
    ADD CONSTRAINT "comunidade_comentarios_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."comunidade_curtidas"
    ADD CONSTRAINT "comunidade_curtidas_pkey" PRIMARY KEY ("post_id", "user_id");



ALTER TABLE ONLY "public"."comunidade_posts_fotos"
    ADD CONSTRAINT "comunidade_posts_fotos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."comunidade_posts"
    ADD CONSTRAINT "comunidade_posts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."config_usuario"
    ADD CONSTRAINT "config_usuario_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."config_usuario"
    ADD CONSTRAINT "config_usuario_usuario_id_key" UNIQUE ("usuario_id");



ALTER TABLE ONLY "public"."conversas"
    ADD CONSTRAINT "conversas_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."conversas"
    ADD CONSTRAINT "conversas_usuario1_id_usuario2_id_anuncio_id_key" UNIQUE ("usuario1_id", "usuario2_id", "anuncio_id");



ALTER TABLE ONLY "public"."curtidas_anuncio"
    ADD CONSTRAINT "curtidas_anuncio_anuncio_id_usuario_id_key" UNIQUE ("anuncio_id", "usuario_id");



ALTER TABLE ONLY "public"."curtidas_anuncio"
    ADD CONSTRAINT "curtidas_anuncio_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."curtidas_anuncio"
    ADD CONSTRAINT "curtidas_anuncio_unica" UNIQUE ("anuncio_id", "usuario_id");



ALTER TABLE ONLY "public"."curtidas_post"
    ADD CONSTRAINT "curtidas_post_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."curtidas_post"
    ADD CONSTRAINT "curtidas_post_post_id_usuario_id_key" UNIQUE ("post_id", "usuario_id");



ALTER TABLE ONLY "public"."denuncias"
    ADD CONSTRAINT "denuncias_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."encontros_confirmados"
    ADD CONSTRAINT "encontros_confirmados_pkey" PRIMARY KEY ("encontro_id", "user_id");



ALTER TABLE ONLY "public"."encontros"
    ADD CONSTRAINT "encontros_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."favoritos"
    ADD CONSTRAINT "favoritos_pkey" PRIMARY KEY ("usuario_id", "anuncio_id");



ALTER TABLE ONLY "public"."fotos_anuncio"
    ADD CONSTRAINT "fotos_anuncio_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."garagem_fotos"
    ADD CONSTRAINT "garagem_fotos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."garagem_gastos"
    ADD CONSTRAINT "garagem_gastos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."garagem_lembretes"
    ADD CONSTRAINT "garagem_lembretes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."garagem_manutencoes"
    ADD CONSTRAINT "garagem_manutencoes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."garagem_veiculos"
    ADD CONSTRAINT "garagem_veiculos_pkey" PRIMARY KEY ("id");



ALTER TABLE "public"."marcas"
    ADD CONSTRAINT "marcas_categoria_check" CHECK (("categoria" = ANY (ARRAY['carro'::"text", 'moto'::"text", 'caminhao'::"text", 'trator'::"text", 'embarcacao'::"text"]))) NOT VALID;



ALTER TABLE ONLY "public"."marcas"
    ADD CONSTRAINT "marcas_nome_key" UNIQUE ("nome");



ALTER TABLE ONLY "public"."marcas"
    ADD CONSTRAINT "marcas_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."mensagens"
    ADD CONSTRAINT "mensagens_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."modelos"
    ADD CONSTRAINT "modelos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."opcionais"
    ADD CONSTRAINT "opcionais_nome_key" UNIQUE ("nome");



ALTER TABLE ONLY "public"."opcionais"
    ADD CONSTRAINT "opcionais_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."posts_usuario"
    ADD CONSTRAINT "posts_usuario_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."projetos_atualizacoes_fotos"
    ADD CONSTRAINT "projetos_atualizacoes_fotos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."projetos_atualizacoes"
    ADD CONSTRAINT "projetos_atualizacoes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."projetos_comentarios"
    ADD CONSTRAINT "projetos_comentarios_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."projetos_curtidas"
    ADD CONSTRAINT "projetos_curtidas_pkey" PRIMARY KEY ("projeto_id", "user_id");



ALTER TABLE ONLY "public"."projetos"
    ADD CONSTRAINT "projetos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."propostas"
    ADD CONSTRAINT "propostas_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."seguidores"
    ADD CONSTRAINT "seguidores_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."seguidores"
    ADD CONSTRAINT "seguidores_seguidor_id_seguido_id_key" UNIQUE ("seguidor_id", "seguido_id");



ALTER TABLE ONLY "public"."fotos_anuncio"
    ADD CONSTRAINT "unique_foto_por_anuncio_ordem" UNIQUE ("anuncio_id", "ordem");



ALTER TABLE ONLY "public"."modelos"
    ADD CONSTRAINT "unique_modelo_por_marca" UNIQUE ("marca_id", "nome");



ALTER TABLE ONLY "public"."versoes"
    ADD CONSTRAINT "unique_versao_por_modelo" UNIQUE ("modelo_id", "nome");



ALTER TABLE ONLY "public"."usuarios_banidos"
    ADD CONSTRAINT "usuarios_banidos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."usuarios_banidos"
    ADD CONSTRAINT "usuarios_banidos_usuario_id_key" UNIQUE ("usuario_id");



ALTER TABLE ONLY "public"."usuarios"
    ADD CONSTRAINT "usuarios_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."versoes"
    ADD CONSTRAINT "versoes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "storage"."buckets_analytics"
    ADD CONSTRAINT "buckets_analytics_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "storage"."buckets"
    ADD CONSTRAINT "buckets_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "storage"."buckets_vectors"
    ADD CONSTRAINT "buckets_vectors_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "storage"."migrations"
    ADD CONSTRAINT "migrations_name_key" UNIQUE ("name");



ALTER TABLE ONLY "storage"."migrations"
    ADD CONSTRAINT "migrations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "storage"."objects"
    ADD CONSTRAINT "objects_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "storage"."s3_multipart_uploads_parts"
    ADD CONSTRAINT "s3_multipart_uploads_parts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "storage"."s3_multipart_uploads"
    ADD CONSTRAINT "s3_multipart_uploads_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "storage"."vector_indexes"
    ADD CONSTRAINT "vector_indexes_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_anuncios_ano_modelo" ON "public"."anuncios" USING "btree" ("ano_modelo");



CREATE INDEX "idx_anuncios_cidade" ON "public"."anuncios" USING "btree" ("cidade");



CREATE INDEX "idx_anuncios_cidade_estado" ON "public"."anuncios" USING "btree" ("cidade", "estado");



CREATE INDEX "idx_anuncios_curtidas" ON "public"."anuncios" USING "btree" ("curtidas" DESC);



CREATE INDEX "idx_anuncios_estado" ON "public"."anuncios" USING "btree" ("estado");



CREATE INDEX "idx_anuncios_marca" ON "public"."anuncios" USING "btree" ("marca_id");



CREATE INDEX "idx_anuncios_modelo" ON "public"."anuncios" USING "btree" ("modelo_id");



CREATE INDEX "idx_anuncios_pausado" ON "public"."anuncios" USING "btree" ("pausado");



CREATE INDEX "idx_anuncios_preco" ON "public"."anuncios" USING "btree" ("preco");



CREATE INDEX "idx_anuncios_quilometragem" ON "public"."anuncios" USING "btree" ("quilometragem");



CREATE INDEX "idx_anuncios_status" ON "public"."anuncios" USING "btree" ("status");



CREATE INDEX "idx_anuncios_status_criado" ON "public"."anuncios" USING "btree" ("status", "criado_em" DESC);



CREATE INDEX "idx_anuncios_status_curtidas" ON "public"."anuncios" USING "btree" ("status", "curtidas" DESC);



CREATE INDEX "idx_anuncios_tipo_veiculo" ON "public"."anuncios" USING "btree" ("tipo_veiculo");



CREATE INDEX "idx_anuncios_ultimo" ON "public"."anuncios" USING "btree" ("ultimo_anuncio" DESC);



CREATE INDEX "idx_anuncios_usuario" ON "public"."anuncios" USING "btree" ("usuario_id");



CREATE INDEX "idx_config_usuario" ON "public"."config_usuario" USING "btree" ("usuario_id");



CREATE INDEX "idx_conversas_ultima_data" ON "public"."conversas" USING "btree" ("ultima_mensagem_data");



CREATE INDEX "idx_conversas_usuario1" ON "public"."conversas" USING "btree" ("usuario1_id");



CREATE INDEX "idx_conversas_usuario2" ON "public"."conversas" USING "btree" ("usuario2_id");



CREATE INDEX "idx_curtidas_anuncio" ON "public"."curtidas_anuncio" USING "btree" ("anuncio_id");



CREATE INDEX "idx_curtidas_unique" ON "public"."curtidas_anuncio" USING "btree" ("anuncio_id", "usuario_id");



CREATE INDEX "idx_curtidas_usuario" ON "public"."curtidas_anuncio" USING "btree" ("usuario_id");



CREATE INDEX "idx_denuncias_status" ON "public"."denuncias" USING "btree" ("status");



CREATE INDEX "idx_denuncias_tipo" ON "public"."denuncias" USING "btree" ("tipo");



CREATE INDEX "idx_fotos_anuncio" ON "public"."fotos_anuncio" USING "btree" ("anuncio_id");



CREATE INDEX "idx_mensagens_data_envio" ON "public"."mensagens" USING "btree" ("data_envio");



CREATE INDEX "idx_mensagens_destinatario" ON "public"."mensagens" USING "btree" ("destinatario_id");



CREATE INDEX "idx_mensagens_remetente" ON "public"."mensagens" USING "btree" ("remetente_id");



CREATE INDEX "idx_posts_usuario_criado" ON "public"."posts_usuario" USING "btree" ("usuario_id", "criado_em" DESC);



CREATE INDEX "idx_posts_usuario_curtidas" ON "public"."posts_usuario" USING "btree" ("curtidas" DESC);



CREATE INDEX "idx_posts_usuario_data" ON "public"."posts_usuario" USING "btree" ("criado_em" DESC);



CREATE INDEX "idx_propostas_comprador" ON "public"."propostas" USING "btree" ("comprador_id");



CREATE INDEX "idx_propostas_vendedor" ON "public"."propostas" USING "btree" ("vendedor_id");



CREATE INDEX "idx_usuarios_banido" ON "public"."usuarios" USING "btree" ("banido") WHERE ("banido" = true);



CREATE INDEX "idx_usuarios_email" ON "public"."usuarios" USING "btree" ("email");



CREATE UNIQUE INDEX "bname" ON "storage"."buckets" USING "btree" ("name");



CREATE UNIQUE INDEX "buckets_analytics_unique_name_idx" ON "storage"."buckets_analytics" USING "btree" ("name") WHERE ("deleted_at" IS NULL);



CREATE INDEX "idx_multipart_uploads_list" ON "storage"."s3_multipart_uploads" USING "btree" ("bucket_id", "key", "created_at");



CREATE INDEX "idx_objects_bucket_id_name" ON "storage"."objects" USING "btree" ("bucket_id", "name" COLLATE "C");



CREATE INDEX "idx_objects_bucket_id_name_lower" ON "storage"."objects" USING "btree" ("bucket_id", "lower"("name") COLLATE "C");



CREATE UNIQUE INDEX "idx_objects_current_version" ON "storage"."objects" USING "btree" ("bucket_id", "name" COLLATE "C") WHERE ("archived_at" IS NULL);



CREATE INDEX "idx_objects_delete_markers" ON "storage"."objects" USING "btree" ("bucket_id", "name" COLLATE "C") WHERE "is_delete_marker";



CREATE UNIQUE INDEX "idx_objects_null_version" ON "storage"."objects" USING "btree" ("bucket_id", "name" COLLATE "C") WHERE (NOT "is_versioned");



CREATE INDEX "name_prefix_search" ON "storage"."objects" USING "btree" ("name" "text_pattern_ops");



CREATE UNIQUE INDEX "objects_bucket_id_name_version_key" ON "storage"."objects" USING "btree" ("bucket_id", "name" COLLATE "C", "version") NULLS NOT DISTINCT;



CREATE UNIQUE INDEX "vector_indexes_name_bucket_id_idx" ON "storage"."vector_indexes" USING "btree" ("name", "bucket_id");



CREATE OR REPLACE TRIGGER "atualizar_conversa_trigger" AFTER INSERT ON "public"."mensagens" FOR EACH ROW EXECUTE FUNCTION "public"."atualizar_conversa"();



CREATE OR REPLACE TRIGGER "trg_cooldown_anuncio" BEFORE INSERT ON "public"."anuncios" FOR EACH ROW EXECUTE FUNCTION "public"."checar_cooldown_anuncio"();



CREATE OR REPLACE TRIGGER "trg_limpar_dependencias_anuncio" BEFORE DELETE ON "public"."anuncios" FOR EACH ROW EXECUTE FUNCTION "public"."limpar_dependencias_antes_excluir_anuncio"();



CREATE OR REPLACE TRIGGER "trg_proteger_campos_usuarios" BEFORE UPDATE ON "public"."usuarios" FOR EACH ROW EXECUTE FUNCTION "public"."proteger_campos_sensiveis_usuarios"();



CREATE OR REPLACE TRIGGER "trg_proteger_consentimento_legal" BEFORE UPDATE ON "public"."usuarios" FOR EACH ROW EXECUTE FUNCTION "public"."proteger_consentimento_legal"();



CREATE OR REPLACE TRIGGER "trg_proteger_conteudo_mensagens" BEFORE UPDATE ON "public"."mensagens" FOR EACH ROW EXECUTE FUNCTION "public"."proteger_conteudo_mensagens"();



CREATE OR REPLACE TRIGGER "trg_proteger_status_anuncios" BEFORE INSERT OR UPDATE ON "public"."anuncios" FOR EACH ROW EXECUTE FUNCTION "public"."proteger_status_anuncios"();



CREATE OR REPLACE TRIGGER "trigger_cooldown_anuncio" BEFORE INSERT ON "public"."anuncios" FOR EACH ROW EXECUTE FUNCTION "public"."verificar_cooldown_anuncio"();



CREATE OR REPLACE TRIGGER "trigger_criar_config" AFTER INSERT ON "public"."usuarios" FOR EACH ROW EXECUTE FUNCTION "public"."criar_config_usuario"();



CREATE OR REPLACE TRIGGER "trigger_curtidas_delete" AFTER DELETE ON "public"."curtidas_anuncio" FOR EACH ROW EXECUTE FUNCTION "public"."decrementar_curtidas"();



CREATE OR REPLACE TRIGGER "trigger_curtidas_insert" AFTER INSERT ON "public"."curtidas_anuncio" FOR EACH ROW EXECUTE FUNCTION "public"."incrementar_curtidas"();



CREATE OR REPLACE TRIGGER "trigger_curtidas_post_delete" AFTER DELETE ON "public"."curtidas_post" FOR EACH ROW EXECUTE FUNCTION "public"."decrementar_curtidas_post"();



CREATE OR REPLACE TRIGGER "trigger_curtidas_post_insert" AFTER INSERT ON "public"."curtidas_post" FOR EACH ROW EXECUTE FUNCTION "public"."incrementar_curtidas_post"();



CREATE OR REPLACE TRIGGER "trigger_seguidores" AFTER INSERT OR DELETE ON "public"."seguidores" FOR EACH ROW EXECUTE FUNCTION "public"."atualizar_contador_seguidores"();



CREATE OR REPLACE TRIGGER "update_anuncios_timestamp" BEFORE UPDATE ON "public"."anuncios" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_usuarios_timestamp" BEFORE UPDATE ON "public"."usuarios" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "enforce_bucket_name_length_trigger" BEFORE INSERT OR UPDATE OF "name" ON "storage"."buckets" FOR EACH ROW EXECUTE FUNCTION "storage"."enforce_bucket_name_length"();



CREATE OR REPLACE TRIGGER "protect_bucket_control_insert" BEFORE INSERT ON "storage"."buckets" FOR EACH ROW EXECUTE FUNCTION "storage"."protect_bucket_control_columns"('service_role');



CREATE OR REPLACE TRIGGER "protect_bucket_control_update" BEFORE UPDATE OF "lifecycle_configuration", "lifecycle_configuration_generation" ON "storage"."buckets" FOR EACH ROW EXECUTE FUNCTION "storage"."protect_bucket_control_columns"();



CREATE OR REPLACE TRIGGER "protect_bucket_control_update_role" AFTER UPDATE OF "lifecycle_configuration", "lifecycle_configuration_generation" ON "storage"."buckets" FOR EACH ROW EXECUTE FUNCTION "storage"."enforce_bucket_lifecycle_service_role"('service_role');



CREATE OR REPLACE TRIGGER "protect_buckets_delete" BEFORE DELETE ON "storage"."buckets" FOR EACH STATEMENT EXECUTE FUNCTION "storage"."protect_delete"();



CREATE OR REPLACE TRIGGER "protect_objects_delete" BEFORE DELETE ON "storage"."objects" FOR EACH STATEMENT EXECUTE FUNCTION "storage"."protect_delete"();



CREATE OR REPLACE TRIGGER "update_objects_updated_at" BEFORE UPDATE ON "storage"."objects" FOR EACH ROW EXECUTE FUNCTION "storage"."update_updated_at_column"();



ALTER TABLE ONLY "public"."anuncios"
    ADD CONSTRAINT "anuncios_marca_id_fkey" FOREIGN KEY ("marca_id") REFERENCES "public"."marcas"("id");



ALTER TABLE ONLY "public"."anuncios"
    ADD CONSTRAINT "anuncios_modelo_id_fkey" FOREIGN KEY ("modelo_id") REFERENCES "public"."modelos"("id");



ALTER TABLE ONLY "public"."anuncios_opcionais"
    ADD CONSTRAINT "anuncios_opcionais_anuncio_id_fkey" FOREIGN KEY ("anuncio_id") REFERENCES "public"."anuncios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."anuncios_opcionais"
    ADD CONSTRAINT "anuncios_opcionais_opcional_id_fkey" FOREIGN KEY ("opcional_id") REFERENCES "public"."opcionais"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."anuncios"
    ADD CONSTRAINT "anuncios_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."anuncios"
    ADD CONSTRAINT "anuncios_versao_id_fkey" FOREIGN KEY ("versao_id") REFERENCES "public"."versoes"("id");



ALTER TABLE ONLY "public"."avaliacoes"
    ADD CONSTRAINT "avaliacoes_avaliado_id_fkey" FOREIGN KEY ("avaliado_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."avaliacoes"
    ADD CONSTRAINT "avaliacoes_avaliador_id_fkey" FOREIGN KEY ("avaliador_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."carrinho_itens"
    ADD CONSTRAINT "carrinho_itens_anuncio_id_fkey" FOREIGN KEY ("anuncio_id") REFERENCES "public"."anuncios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."carrinho_itens"
    ADD CONSTRAINT "carrinho_itens_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."comunidade_comentarios"
    ADD CONSTRAINT "comunidade_comentarios_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "public"."comunidade_posts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."comunidade_comentarios"
    ADD CONSTRAINT "comunidade_comentarios_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."comunidade_curtidas"
    ADD CONSTRAINT "comunidade_curtidas_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "public"."comunidade_posts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."comunidade_curtidas"
    ADD CONSTRAINT "comunidade_curtidas_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."comunidade_posts_fotos"
    ADD CONSTRAINT "comunidade_posts_fotos_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "public"."comunidade_posts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."comunidade_posts"
    ADD CONSTRAINT "comunidade_posts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."comunidade_posts"
    ADD CONSTRAINT "comunidade_posts_veiculo_id_fkey" FOREIGN KEY ("veiculo_id") REFERENCES "public"."garagem_veiculos"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."config_usuario"
    ADD CONSTRAINT "config_usuario_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."conversas"
    ADD CONSTRAINT "conversas_anuncio_id_fkey" FOREIGN KEY ("anuncio_id") REFERENCES "public"."anuncios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."conversas"
    ADD CONSTRAINT "conversas_usuario1_id_fkey" FOREIGN KEY ("usuario1_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."conversas"
    ADD CONSTRAINT "conversas_usuario2_id_fkey" FOREIGN KEY ("usuario2_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."curtidas_anuncio"
    ADD CONSTRAINT "curtidas_anuncio_anuncio_id_fkey" FOREIGN KEY ("anuncio_id") REFERENCES "public"."anuncios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."curtidas_anuncio"
    ADD CONSTRAINT "curtidas_anuncio_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."curtidas_post"
    ADD CONSTRAINT "curtidas_post_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "public"."posts_usuario"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."curtidas_post"
    ADD CONSTRAINT "curtidas_post_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."denuncias"
    ADD CONSTRAINT "denuncias_denunciante_id_fkey" FOREIGN KEY ("denunciante_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."denuncias"
    ADD CONSTRAINT "denuncias_resolvido_por_fkey" FOREIGN KEY ("resolvido_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."encontros_confirmados"
    ADD CONSTRAINT "encontros_confirmados_encontro_id_fkey" FOREIGN KEY ("encontro_id") REFERENCES "public"."encontros"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."encontros_confirmados"
    ADD CONSTRAINT "encontros_confirmados_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."encontros"
    ADD CONSTRAINT "encontros_criador_id_fkey" FOREIGN KEY ("criador_id") REFERENCES "public"."usuarios"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."encontros"
    ADD CONSTRAINT "encontros_veiculo_id_fkey" FOREIGN KEY ("veiculo_id") REFERENCES "public"."garagem_veiculos"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."favoritos"
    ADD CONSTRAINT "favoritos_anuncio_id_fkey" FOREIGN KEY ("anuncio_id") REFERENCES "public"."anuncios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."favoritos"
    ADD CONSTRAINT "favoritos_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."fotos_anuncio"
    ADD CONSTRAINT "fotos_anuncio_anuncio_id_fkey" FOREIGN KEY ("anuncio_id") REFERENCES "public"."anuncios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."garagem_fotos"
    ADD CONSTRAINT "garagem_fotos_veiculo_id_fkey" FOREIGN KEY ("veiculo_id") REFERENCES "public"."garagem_veiculos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."garagem_gastos"
    ADD CONSTRAINT "garagem_gastos_veiculo_id_fkey" FOREIGN KEY ("veiculo_id") REFERENCES "public"."garagem_veiculos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."garagem_lembretes"
    ADD CONSTRAINT "garagem_lembretes_veiculo_id_fkey" FOREIGN KEY ("veiculo_id") REFERENCES "public"."garagem_veiculos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."garagem_manutencoes"
    ADD CONSTRAINT "garagem_manutencoes_veiculo_id_fkey" FOREIGN KEY ("veiculo_id") REFERENCES "public"."garagem_veiculos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."garagem_veiculos"
    ADD CONSTRAINT "garagem_veiculos_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."mensagens"
    ADD CONSTRAINT "mensagens_anuncio_id_fkey" FOREIGN KEY ("anuncio_id") REFERENCES "public"."anuncios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."mensagens"
    ADD CONSTRAINT "mensagens_destinatario_id_fkey" FOREIGN KEY ("destinatario_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."mensagens"
    ADD CONSTRAINT "mensagens_remetente_id_fkey" FOREIGN KEY ("remetente_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."modelos"
    ADD CONSTRAINT "modelos_marca_id_fkey" FOREIGN KEY ("marca_id") REFERENCES "public"."marcas"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."posts_usuario"
    ADD CONSTRAINT "posts_usuario_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."projetos_atualizacoes_fotos"
    ADD CONSTRAINT "projetos_atualizacoes_fotos_atualizacao_id_fkey" FOREIGN KEY ("atualizacao_id") REFERENCES "public"."projetos_atualizacoes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."projetos_atualizacoes"
    ADD CONSTRAINT "projetos_atualizacoes_projeto_id_fkey" FOREIGN KEY ("projeto_id") REFERENCES "public"."projetos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."projetos_comentarios"
    ADD CONSTRAINT "projetos_comentarios_projeto_id_fkey" FOREIGN KEY ("projeto_id") REFERENCES "public"."projetos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."projetos_comentarios"
    ADD CONSTRAINT "projetos_comentarios_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."projetos_curtidas"
    ADD CONSTRAINT "projetos_curtidas_projeto_id_fkey" FOREIGN KEY ("projeto_id") REFERENCES "public"."projetos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."projetos_curtidas"
    ADD CONSTRAINT "projetos_curtidas_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."projetos"
    ADD CONSTRAINT "projetos_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."projetos"
    ADD CONSTRAINT "projetos_veiculo_id_fkey" FOREIGN KEY ("veiculo_id") REFERENCES "public"."garagem_veiculos"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."propostas"
    ADD CONSTRAINT "propostas_anuncio_id_fkey" FOREIGN KEY ("anuncio_id") REFERENCES "public"."anuncios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."propostas"
    ADD CONSTRAINT "propostas_comprador_id_fkey" FOREIGN KEY ("comprador_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."propostas"
    ADD CONSTRAINT "propostas_vendedor_id_fkey" FOREIGN KEY ("vendedor_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."seguidores"
    ADD CONSTRAINT "seguidores_seguido_id_fkey" FOREIGN KEY ("seguido_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."seguidores"
    ADD CONSTRAINT "seguidores_seguidor_id_fkey" FOREIGN KEY ("seguidor_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."usuarios_banidos"
    ADD CONSTRAINT "usuarios_banidos_banido_por_fkey" FOREIGN KEY ("banido_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."usuarios_banidos"
    ADD CONSTRAINT "usuarios_banidos_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."versoes"
    ADD CONSTRAINT "versoes_modelo_id_fkey" FOREIGN KEY ("modelo_id") REFERENCES "public"."modelos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "storage"."objects"
    ADD CONSTRAINT "objects_bucketId_fkey" FOREIGN KEY ("bucket_id") REFERENCES "storage"."buckets"("id");



ALTER TABLE ONLY "storage"."s3_multipart_uploads"
    ADD CONSTRAINT "s3_multipart_uploads_bucket_id_fkey" FOREIGN KEY ("bucket_id") REFERENCES "storage"."buckets"("id");



ALTER TABLE ONLY "storage"."s3_multipart_uploads_parts"
    ADD CONSTRAINT "s3_multipart_uploads_parts_bucket_id_fkey" FOREIGN KEY ("bucket_id") REFERENCES "storage"."buckets"("id");



ALTER TABLE ONLY "storage"."s3_multipart_uploads_parts"
    ADD CONSTRAINT "s3_multipart_uploads_parts_upload_id_fkey" FOREIGN KEY ("upload_id") REFERENCES "storage"."s3_multipart_uploads"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "storage"."vector_indexes"
    ADD CONSTRAINT "vector_indexes_bucket_id_fkey" FOREIGN KEY ("bucket_id") REFERENCES "storage"."buckets_vectors"("id");



CREATE POLICY "Avaliacoes visíveis" ON "public"."avaliacoes" FOR SELECT USING (true);



CREATE POLICY "Curtidas visíveis" ON "public"."curtidas_anuncio" FOR SELECT USING (true);



CREATE POLICY "Denuncias criar" ON "public"."denuncias" FOR INSERT WITH CHECK (("auth"."uid"() = "denunciante_id"));



CREATE POLICY "Dono do anuncio apaga curtidas do anuncio" ON "public"."curtidas_anuncio" FOR DELETE USING (("anuncio_id" IN ( SELECT "anuncios"."id"
   FROM "public"."anuncios"
  WHERE ("anuncios"."usuario_id" = "auth"."uid"()))));



CREATE POLICY "Dono do anuncio apaga mensagens do anuncio" ON "public"."mensagens" FOR DELETE USING (("anuncio_id" IN ( SELECT "anuncios"."id"
   FROM "public"."anuncios"
  WHERE ("anuncios"."usuario_id" = "auth"."uid"()))));



CREATE POLICY "Envolvidos veem propostas" ON "public"."propostas" USING ((("auth"."uid"() = "comprador_id") OR ("auth"."uid"() = "vendedor_id")));



CREATE POLICY "Seguidores visíveis" ON "public"."seguidores" FOR SELECT USING (true);



CREATE POLICY "Todos podem ler versoes" ON "public"."versoes" FOR SELECT USING (true);



CREATE POLICY "Todos veem anuncios ativos" ON "public"."anuncios" FOR SELECT USING (((("status" = 'ativo'::"public"."status_anuncio") AND (("pausado" IS NULL) OR ("pausado" = false))) OR ("auth"."uid"() = "usuario_id")));



CREATE POLICY "Todos veem fotos anuncio" ON "public"."fotos_anuncio" FOR SELECT USING (("anuncio_id" IN ( SELECT "anuncios"."id"
   FROM "public"."anuncios"
  WHERE (("anuncios"."status" = 'ativo'::"public"."status_anuncio") OR ("anuncios"."usuario_id" = "auth"."uid"())))));



CREATE POLICY "Todos veem opcionais" ON "public"."opcionais" FOR SELECT USING (true);



CREATE POLICY "Todos veem opcionais de anuncios ativos" ON "public"."anuncios_opcionais" FOR SELECT USING (("anuncio_id" IN ( SELECT "anuncios"."id"
   FROM "public"."anuncios"
  WHERE ("anuncios"."status" = 'ativo'::"public"."status_anuncio"))));



CREATE POLICY "Todos veem posts" ON "public"."posts_usuario" FOR SELECT USING (true);



CREATE POLICY "Todos veem versoes" ON "public"."versoes" FOR SELECT USING (true);



CREATE POLICY "Usuarios atualizam anuncios" ON "public"."anuncios" FOR UPDATE USING (("auth"."uid"() = "usuario_id")) WITH CHECK (("auth"."uid"() = "usuario_id"));



CREATE POLICY "Usuarios atualizam fotos anuncio" ON "public"."fotos_anuncio" FOR UPDATE USING (("anuncio_id" IN ( SELECT "anuncios"."id"
   FROM "public"."anuncios"
  WHERE ("anuncios"."usuario_id" = "auth"."uid"())))) WITH CHECK (("anuncio_id" IN ( SELECT "anuncios"."id"
   FROM "public"."anuncios"
  WHERE ("anuncios"."usuario_id" = "auth"."uid"()))));



CREATE POLICY "Usuarios atualizam mensagens" ON "public"."mensagens" FOR UPDATE USING (("auth"."uid"() = "destinatario_id"));



CREATE POLICY "Usuarios avaliar" ON "public"."avaliacoes" USING (("auth"."uid"() = "avaliador_id"));



CREATE POLICY "Usuarios criam anuncios" ON "public"."anuncios" FOR INSERT WITH CHECK (("auth"."uid"() = "usuario_id"));



CREATE POLICY "Usuarios criam posts" ON "public"."posts_usuario" FOR INSERT WITH CHECK (("auth"."uid"() = "usuario_id"));



CREATE POLICY "Usuarios curtir" ON "public"."curtidas_anuncio" FOR INSERT WITH CHECK (("auth"."uid"() = "usuario_id"));



CREATE POLICY "Usuarios deletam anuncios" ON "public"."anuncios" FOR DELETE USING (("auth"."uid"() = "usuario_id"));



CREATE POLICY "Usuarios deletam fotos anuncio" ON "public"."fotos_anuncio" FOR DELETE USING (("anuncio_id" IN ( SELECT "anuncios"."id"
   FROM "public"."anuncios"
  WHERE ("anuncios"."usuario_id" = "auth"."uid"()))));



CREATE POLICY "Usuarios deletam posts" ON "public"."posts_usuario" FOR DELETE USING (("auth"."uid"() = "usuario_id"));



CREATE POLICY "Usuarios deletam sua conta" ON "public"."usuarios" FOR DELETE USING (("auth"."uid"() = "id"));



CREATE POLICY "Usuarios descurtir" ON "public"."curtidas_anuncio" FOR DELETE USING (("auth"."uid"() = "usuario_id"));



CREATE POLICY "Usuarios desseguir" ON "public"."seguidores" FOR DELETE USING (("auth"."uid"() = "seguidor_id"));



CREATE POLICY "Usuarios editam seu perfil" ON "public"."usuarios" FOR UPDATE USING (("auth"."uid"() = "id")) WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "Usuarios enviam mensagens" ON "public"."mensagens" FOR INSERT WITH CHECK (("auth"."uid"() = "remetente_id"));



CREATE POLICY "Usuarios gerenciam curtidas de posts" ON "public"."curtidas_post" USING (("auth"."uid"() = "usuario_id"));



CREATE POLICY "Usuarios gerenciam curtidas posts" ON "public"."curtidas_post" USING (("auth"."uid"() = "usuario_id"));



CREATE POLICY "Usuarios gerenciam favoritos" ON "public"."favoritos" USING (("auth"."uid"() = "usuario_id"));



CREATE POLICY "Usuarios gerenciam opcionais dos seus anuncios" ON "public"."anuncios_opcionais" USING (("anuncio_id" IN ( SELECT "anuncios"."id"
   FROM "public"."anuncios"
  WHERE ("anuncios"."usuario_id" = "auth"."uid"())))) WITH CHECK (("anuncio_id" IN ( SELECT "anuncios"."id"
   FROM "public"."anuncios"
  WHERE ("anuncios"."usuario_id" = "auth"."uid"()))));



CREATE POLICY "Usuarios gerenciam seus carrinhos" ON "public"."carrinho_itens" USING (("auth"."uid"() = "usuario_id"));



CREATE POLICY "Usuarios inserem fotos anuncio" ON "public"."fotos_anuncio" FOR INSERT WITH CHECK (("anuncio_id" IN ( SELECT "anuncios"."id"
   FROM "public"."anuncios"
  WHERE ("anuncios"."usuario_id" = "auth"."uid"()))));



CREATE POLICY "Usuarios seguir" ON "public"."seguidores" FOR INSERT WITH CHECK (("auth"."uid"() = "seguidor_id"));



CREATE POLICY "Usuarios veem suas mensagens" ON "public"."mensagens" FOR SELECT USING ((("auth"."uid"() = "remetente_id") OR ("auth"."uid"() = "destinatario_id")));



ALTER TABLE "public"."anuncios" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "anuncios delete proprio ou admin" ON "public"."anuncios" FOR DELETE TO "authenticated" USING ((("usuario_id" = "auth"."uid"()) OR "public"."is_admin"()));



CREATE POLICY "anuncios insert proprio" ON "public"."anuncios" FOR INSERT TO "authenticated" WITH CHECK (("usuario_id" = "auth"."uid"()));



CREATE POLICY "anuncios select" ON "public"."anuncios" FOR SELECT TO "authenticated", "anon" USING ((("status" = 'ativo'::"public"."status_anuncio") OR ("usuario_id" = "auth"."uid"()) OR "public"."is_admin"()));



CREATE POLICY "anuncios update proprio ou admin" ON "public"."anuncios" FOR UPDATE TO "authenticated" USING ((("usuario_id" = "auth"."uid"()) OR "public"."is_admin"())) WITH CHECK ((("usuario_id" = "auth"."uid"()) OR "public"."is_admin"()));



ALTER TABLE "public"."anuncios_opcionais" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."avaliacoes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "avaliacoes insert proprio" ON "public"."avaliacoes" FOR INSERT TO "authenticated" WITH CHECK ((("avaliador_id" = "auth"."uid"()) AND ("avaliador_id" <> "avaliado_id")));



CREATE POLICY "avaliacoes select publico" ON "public"."avaliacoes" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "avaliacoes update proprio" ON "public"."avaliacoes" FOR UPDATE TO "authenticated" USING (("avaliador_id" = "auth"."uid"())) WITH CHECK ((("avaliador_id" = "auth"."uid"()) AND ("avaliador_id" <> "avaliado_id")));



CREATE POLICY "carrinho delete proprio" ON "public"."carrinho_itens" FOR DELETE TO "authenticated" USING (("usuario_id" = "auth"."uid"()));



CREATE POLICY "carrinho insert proprio" ON "public"."carrinho_itens" FOR INSERT TO "authenticated" WITH CHECK (("usuario_id" = "auth"."uid"()));



CREATE POLICY "carrinho select proprio" ON "public"."carrinho_itens" FOR SELECT TO "authenticated" USING (("usuario_id" = "auth"."uid"()));



ALTER TABLE "public"."carrinho_itens" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "cc_insert" ON "public"."comunidade_comentarios" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "cc_select" ON "public"."comunidade_comentarios" FOR SELECT USING (true);



CREATE POLICY "ccurt_all" ON "public"."comunidade_curtidas" USING (true) WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."comunidade_comentarios" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."comunidade_curtidas" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."comunidade_posts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."comunidade_posts_fotos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "conf_delete" ON "public"."encontros_confirmados" FOR DELETE USING (("user_id" = "auth"."uid"()));



CREATE POLICY "conf_insert" ON "public"."encontros_confirmados" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "conf_select" ON "public"."encontros_confirmados" FOR SELECT USING (true);



CREATE POLICY "config_own" ON "public"."config_usuario" USING (("auth"."uid"() = "usuario_id"));



ALTER TABLE "public"."config_usuario" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."conversas" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "cp_delete" ON "public"."comunidade_posts" FOR DELETE USING (("user_id" = "auth"."uid"()));



CREATE POLICY "cp_insert" ON "public"."comunidade_posts" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "cp_select" ON "public"."comunidade_posts" FOR SELECT USING (true);



CREATE POLICY "cpf_insert" ON "public"."comunidade_posts_fotos" FOR INSERT WITH CHECK (true);



CREATE POLICY "cpf_select" ON "public"."comunidade_posts_fotos" FOR SELECT USING (true);



CREATE POLICY "curtidas delete dono do anuncio" ON "public"."curtidas_anuncio" FOR DELETE TO "authenticated" USING ((("usuario_id" = "auth"."uid"()) OR ("anuncio_id" IN ( SELECT "anuncios"."id"
   FROM "public"."anuncios"
  WHERE ("anuncios"."usuario_id" = "auth"."uid"())))));



CREATE POLICY "curtidas delete proprio" ON "public"."curtidas_anuncio" FOR DELETE TO "authenticated" USING (("usuario_id" = "auth"."uid"()));



CREATE POLICY "curtidas insert proprio" ON "public"."curtidas_anuncio" FOR INSERT TO "authenticated" WITH CHECK (("usuario_id" = "auth"."uid"()));



CREATE POLICY "curtidas select publico" ON "public"."curtidas_anuncio" FOR SELECT TO "authenticated", "anon" USING (true);



ALTER TABLE "public"."curtidas_anuncio" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."curtidas_post" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."denuncias" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "denuncias insert proprio" ON "public"."denuncias" FOR INSERT TO "authenticated" WITH CHECK (("denunciante_id" = "auth"."uid"()));



CREATE POLICY "denuncias select admin" ON "public"."denuncias" FOR SELECT TO "authenticated" USING ((("denunciante_id" = "auth"."uid"()) OR "public"."is_admin"()));



CREATE POLICY "denuncias update admin" ON "public"."denuncias" FOR UPDATE TO "authenticated" USING ("public"."is_admin"()) WITH CHECK ("public"."is_admin"());



CREATE POLICY "enc_insert" ON "public"."encontros" FOR INSERT WITH CHECK ((("auth"."uid"() IS NOT NULL) AND ("criador_id" = "auth"."uid"())));



CREATE POLICY "enc_select" ON "public"."encontros" FOR SELECT USING (((("ativo" = true) AND ("status" = 'approved'::"text")) OR ("criador_id" = "auth"."uid"()) OR "public"."is_admin"()));



CREATE POLICY "enc_update" ON "public"."encontros" FOR UPDATE USING (("criador_id" = "auth"."uid"()));



ALTER TABLE "public"."encontros" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."encontros_confirmados" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."favoritos" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."fotos_anuncio" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "fotos_anuncio delete dono do anuncio" ON "public"."fotos_anuncio" FOR DELETE TO "authenticated" USING (((EXISTS ( SELECT 1
   FROM "public"."anuncios" "a"
  WHERE (("a"."id" = "fotos_anuncio"."anuncio_id") AND ("a"."usuario_id" = "auth"."uid"())))) OR "public"."is_admin"()));



CREATE POLICY "fotos_anuncio insert dono do anuncio" ON "public"."fotos_anuncio" FOR INSERT TO "authenticated" WITH CHECK (((EXISTS ( SELECT 1
   FROM "public"."anuncios" "a"
  WHERE (("a"."id" = "fotos_anuncio"."anuncio_id") AND ("a"."usuario_id" = "auth"."uid"())))) OR "public"."is_admin"()));



CREATE POLICY "fotos_anuncio select publico" ON "public"."fotos_anuncio" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "garagem_delete" ON "public"."garagem_veiculos" FOR DELETE USING (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."garagem_fotos" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."garagem_gastos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "garagem_insert" ON "public"."garagem_veiculos" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."garagem_lembretes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."garagem_manutencoes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "garagem_select" ON "public"."garagem_veiculos" FOR SELECT USING (("user_id" = "auth"."uid"()));



CREATE POLICY "garagem_update" ON "public"."garagem_veiculos" FOR UPDATE USING (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."garagem_veiculos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "gastos_all" ON "public"."garagem_gastos" USING ((EXISTS ( SELECT 1
   FROM "public"."garagem_veiculos" "v"
  WHERE (("v"."id" = "garagem_gastos"."veiculo_id") AND ("v"."user_id" = "auth"."uid"())))));



CREATE POLICY "gf_delete" ON "public"."garagem_fotos" FOR DELETE USING (("veiculo_id" IN ( SELECT "garagem_veiculos"."id"
   FROM "public"."garagem_veiculos"
  WHERE ("garagem_veiculos"."user_id" = "auth"."uid"()))));



CREATE POLICY "gf_insert" ON "public"."garagem_fotos" FOR INSERT WITH CHECK (("veiculo_id" IN ( SELECT "garagem_veiculos"."id"
   FROM "public"."garagem_veiculos"
  WHERE ("garagem_veiculos"."user_id" = "auth"."uid"()))));



CREATE POLICY "gf_select" ON "public"."garagem_fotos" FOR SELECT USING (true);



CREATE POLICY "gfotos_all" ON "public"."garagem_fotos" USING ((EXISTS ( SELECT 1
   FROM "public"."garagem_veiculos" "v"
  WHERE (("v"."id" = "garagem_fotos"."veiculo_id") AND ("v"."user_id" = "auth"."uid"())))));



CREATE POLICY "lembretes_all" ON "public"."garagem_lembretes" USING ((EXISTS ( SELECT 1
   FROM "public"."garagem_veiculos" "v"
  WHERE (("v"."id" = "garagem_lembretes"."veiculo_id") AND ("v"."user_id" = "auth"."uid"())))));



CREATE POLICY "manut_all" ON "public"."garagem_manutencoes" USING ((EXISTS ( SELECT 1
   FROM "public"."garagem_veiculos" "v"
  WHERE (("v"."id" = "garagem_manutencoes"."veiculo_id") AND ("v"."user_id" = "auth"."uid"())))));



ALTER TABLE "public"."marcas" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "marcas select publico" ON "public"."marcas" FOR SELECT TO "authenticated", "anon" USING (true);



ALTER TABLE "public"."mensagens" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "mensagens delete dono do anuncio" ON "public"."mensagens" FOR DELETE TO "authenticated" USING ((("remetente_id" = "auth"."uid"()) OR ("destinatario_id" = "auth"."uid"()) OR ("anuncio_id" IN ( SELECT "anuncios"."id"
   FROM "public"."anuncios"
  WHERE ("anuncios"."usuario_id" = "auth"."uid"())))));



CREATE POLICY "mensagens insert como remetente" ON "public"."mensagens" FOR INSERT TO "authenticated" WITH CHECK (("remetente_id" = "auth"."uid"()));



CREATE POLICY "mensagens select participante" ON "public"."mensagens" FOR SELECT TO "authenticated" USING ((("remetente_id" = "auth"."uid"()) OR ("destinatario_id" = "auth"."uid"())));



CREATE POLICY "mensagens update destinatario marca lida" ON "public"."mensagens" FOR UPDATE TO "authenticated" USING (("destinatario_id" = "auth"."uid"())) WITH CHECK (("destinatario_id" = "auth"."uid"()));



ALTER TABLE "public"."modelos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "modelos select publico" ON "public"."modelos" FOR SELECT TO "authenticated", "anon" USING (true);



ALTER TABLE "public"."opcionais" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "pafoto_insert" ON "public"."projetos_atualizacoes_fotos" FOR INSERT WITH CHECK (true);



CREATE POLICY "pafoto_select" ON "public"."projetos_atualizacoes_fotos" FOR SELECT USING (true);



CREATE POLICY "patu_insert" ON "public"."projetos_atualizacoes" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."projetos" "p"
  WHERE (("p"."id" = "projetos_atualizacoes"."projeto_id") AND ("p"."user_id" = "auth"."uid"())))));



CREATE POLICY "patu_select" ON "public"."projetos_atualizacoes" FOR SELECT USING (true);



CREATE POLICY "pcomt_insert" ON "public"."projetos_comentarios" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "pcomt_select" ON "public"."projetos_comentarios" FOR SELECT USING (true);



CREATE POLICY "pcurt_all" ON "public"."projetos_curtidas" USING (true) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "posts delete proprio ou admin" ON "public"."posts_usuario" FOR DELETE TO "authenticated" USING ((("usuario_id" = "auth"."uid"()) OR "public"."is_admin"()));



CREATE POLICY "posts insert proprio" ON "public"."posts_usuario" FOR INSERT TO "authenticated" WITH CHECK (("usuario_id" = "auth"."uid"()));



CREATE POLICY "posts select publico" ON "public"."posts_usuario" FOR SELECT TO "authenticated", "anon" USING (true);



ALTER TABLE "public"."posts_usuario" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "proj_delete" ON "public"."projetos" FOR DELETE USING (("user_id" = "auth"."uid"()));



CREATE POLICY "proj_insert" ON "public"."projetos" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "proj_select" ON "public"."projetos" FOR SELECT USING (true);



CREATE POLICY "proj_update" ON "public"."projetos" FOR UPDATE USING (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."projetos" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."projetos_atualizacoes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."projetos_atualizacoes_fotos" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."projetos_comentarios" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."projetos_curtidas" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."propostas" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."seguidores" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "seguidores delete proprio" ON "public"."seguidores" FOR DELETE TO "authenticated" USING (("seguidor_id" = "auth"."uid"()));



CREATE POLICY "seguidores insert proprio" ON "public"."seguidores" FOR INSERT TO "authenticated" WITH CHECK (("seguidor_id" = "auth"."uid"()));



CREATE POLICY "seguidores select publico" ON "public"."seguidores" FOR SELECT TO "authenticated", "anon" USING (true);



ALTER TABLE "public"."usuarios" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "usuarios delete proprio ou admin" ON "public"."usuarios" FOR DELETE TO "authenticated" USING ((("id" = "auth"."uid"()) OR "public"."is_admin"()));



CREATE POLICY "usuarios insert proprio" ON "public"."usuarios" FOR INSERT TO "authenticated" WITH CHECK (("id" = "auth"."uid"()));



CREATE POLICY "usuarios select proprio ou admin" ON "public"."usuarios" FOR SELECT TO "authenticated" USING ((("id" = "auth"."uid"()) OR "public"."is_admin"()));



CREATE POLICY "usuarios update proprio ou admin" ON "public"."usuarios" FOR UPDATE TO "authenticated" USING ((("id" = "auth"."uid"()) OR "public"."is_admin"())) WITH CHECK ((("id" = "auth"."uid"()) OR "public"."is_admin"()));



CREATE POLICY "usuarios_atualizam_conversas" ON "public"."conversas" FOR UPDATE USING ((("auth"."uid"() = "usuario1_id") OR ("auth"."uid"() = "usuario2_id")));



ALTER TABLE "public"."usuarios_banidos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "usuarios_banidos admin all" ON "public"."usuarios_banidos" TO "authenticated" USING ("public"."is_admin"()) WITH CHECK ("public"."is_admin"());



CREATE POLICY "usuarios_criam_conversas" ON "public"."conversas" FOR INSERT WITH CHECK ((("auth"."uid"() = "usuario1_id") OR ("auth"."uid"() = "usuario2_id")));



CREATE POLICY "usuarios_veem_conversas" ON "public"."conversas" FOR SELECT USING ((("auth"."uid"() = "usuario1_id") OR ("auth"."uid"() = "usuario2_id")));



CREATE POLICY "usuarios_veem_suas_conversas" ON "public"."conversas" FOR SELECT USING ((("auth"."uid"() = "usuario1_id") OR ("auth"."uid"() = "usuario2_id")));



ALTER TABLE "public"."versoes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "Acesso público para FOTOS-ANUNCIOS" ON "storage"."objects" FOR SELECT USING (("bucket_id" = 'FOTOS-ANUNCIOS'::"text"));



CREATE POLICY "Acesso público para fotos-perfil" ON "storage"."objects" FOR SELECT USING (("bucket_id" = 'fotos-perfil'::"text"));



CREATE POLICY "Leitura publica fotos anuncio" ON "storage"."objects" FOR SELECT USING (("bucket_id" = 'FOTOS-ANUNCIOS'::"text"));



CREATE POLICY "Upload para usuários autenticados" ON "storage"."objects" FOR INSERT WITH CHECK ((("bucket_id" = 'fotos-perfil'::"text") AND ("auth"."role"() = 'authenticated'::"text")));



CREATE POLICY "Usuarios autenticados atualizam fotos anuncio" ON "storage"."objects" FOR UPDATE TO "authenticated" USING (("bucket_id" = 'FOTOS-ANUNCIOS'::"text")) WITH CHECK (("bucket_id" = 'FOTOS-ANUNCIOS'::"text"));



CREATE POLICY "Usuarios autenticados enviam fotos anuncio" ON "storage"."objects" FOR INSERT TO "authenticated" WITH CHECK (("bucket_id" = 'FOTOS-ANUNCIOS'::"text"));



CREATE POLICY "Usuarios autenticados removem fotos anuncio" ON "storage"."objects" FOR DELETE TO "authenticated" USING (("bucket_id" = 'FOTOS-ANUNCIOS'::"text"));



CREATE POLICY "Usuários autenticados podem atualizar" ON "storage"."objects" FOR UPDATE USING ((("bucket_id" = 'fotos-perfil'::"text") AND ("auth"."role"() = 'authenticated'::"text"))) WITH CHECK ((("bucket_id" = 'fotos-perfil'::"text") AND ("auth"."role"() = 'authenticated'::"text")));



CREATE POLICY "Usuários autenticados podem atualizar FOTOS-ANUNCIOS" ON "storage"."objects" FOR UPDATE USING ((("bucket_id" = 'FOTOS-ANUNCIOS'::"text") AND ("auth"."role"() = 'authenticated'::"text")));



CREATE POLICY "Usuários autenticados podem atualizar perfil" ON "storage"."objects" FOR UPDATE USING ((("bucket_id" = 'fotos-perfil'::"text") AND ("auth"."role"() = 'authenticated'::"text")));



CREATE POLICY "Usuários autenticados podem deletar" ON "storage"."objects" FOR DELETE USING ((("bucket_id" = 'fotos-perfil'::"text") AND ("auth"."role"() = 'authenticated'::"text")));



CREATE POLICY "Usuários autenticados podem deletar FOTOS-ANUNCIOS" ON "storage"."objects" FOR DELETE USING ((("bucket_id" = 'FOTOS-ANUNCIOS'::"text") AND ("auth"."role"() = 'authenticated'::"text")));



CREATE POLICY "Usuários autenticados podem deletar perfil" ON "storage"."objects" FOR DELETE USING ((("bucket_id" = 'fotos-perfil'::"text") AND ("auth"."role"() = 'authenticated'::"text")));



CREATE POLICY "Usuários autenticados podem upload" ON "storage"."objects" FOR INSERT WITH CHECK ((("bucket_id" = 'fotos-perfil'::"text") AND ("auth"."role"() = 'authenticated'::"text")));



CREATE POLICY "Usuários autenticados podem upload FOTOS-ANUNCIOS" ON "storage"."objects" FOR INSERT WITH CHECK ((("bucket_id" = 'FOTOS-ANUNCIOS'::"text") AND ("auth"."role"() = 'authenticated'::"text")));



CREATE POLICY "Usuários autenticados podem upload perfil" ON "storage"."objects" FOR INSERT WITH CHECK ((("bucket_id" = 'fotos-perfil'::"text") AND ("auth"."role"() = 'authenticated'::"text")));



CREATE POLICY "Usuários podem atualizar suas fotos" ON "storage"."objects" FOR UPDATE USING ((("bucket_id" = 'fotos-perfil'::"text") AND ("auth"."role"() = 'authenticated'::"text")));



CREATE POLICY "Usuários podem deletar suas fotos" ON "storage"."objects" FOR DELETE USING ((("bucket_id" = 'fotos-perfil'::"text") AND ("auth"."role"() = 'authenticated'::"text")));



CREATE POLICY "allow authenticaded uploads cn6lji_0" ON "storage"."objects" FOR INSERT TO "authenticated" WITH CHECK ((("bucket_id" = 'FOTOS-ANUNCIOS'::"text") AND ("auth"."role"() = 'authenticated'::"text")));



ALTER TABLE "storage"."buckets" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "storage"."buckets_analytics" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "storage"."buckets_vectors" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "fc_delete" ON "storage"."objects" FOR DELETE TO "authenticated" USING (("bucket_id" = 'FOTOS-COMUNIDADE'::"text"));



CREATE POLICY "fc_select" ON "storage"."objects" FOR SELECT USING (("bucket_id" = 'FOTOS-COMUNIDADE'::"text"));



CREATE POLICY "fc_update" ON "storage"."objects" FOR UPDATE TO "authenticated" USING (("bucket_id" = 'FOTOS-COMUNIDADE'::"text"));



CREATE POLICY "fc_upload" ON "storage"."objects" FOR INSERT TO "authenticated" WITH CHECK (("bucket_id" = 'FOTOS-COMUNIDADE'::"text"));



CREATE POLICY "fg_delete" ON "storage"."objects" FOR DELETE TO "authenticated" USING (("bucket_id" = 'FOTOS-GARAGEM'::"text"));



CREATE POLICY "fg_select" ON "storage"."objects" FOR SELECT USING (("bucket_id" = 'FOTOS-GARAGEM'::"text"));



CREATE POLICY "fg_update" ON "storage"."objects" FOR UPDATE TO "authenticated" USING (("bucket_id" = 'FOTOS-GARAGEM'::"text"));



CREATE POLICY "fg_upload" ON "storage"."objects" FOR INSERT TO "authenticated" WITH CHECK (("bucket_id" = 'FOTOS-GARAGEM'::"text"));



ALTER TABLE "storage"."migrations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "storage"."objects" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "public select cn6lji_0" ON "storage"."objects" FOR SELECT TO "anon" USING ((("bucket_id" = 'FOTOS-ANUNCIOS'::"text") AND true));



ALTER TABLE "storage"."s3_multipart_uploads" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "storage"."s3_multipart_uploads_parts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "storage"."vector_indexes" ENABLE ROW LEVEL SECURITY;


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT USAGE ON SCHEMA "storage" TO "postgres" WITH GRANT OPTION;
GRANT USAGE ON SCHEMA "storage" TO "anon";
GRANT USAGE ON SCHEMA "storage" TO "authenticated";
GRANT USAGE ON SCHEMA "storage" TO "service_role";
GRANT ALL ON SCHEMA "storage" TO "supabase_storage_admin";
GRANT ALL ON SCHEMA "storage" TO "dashboard_user";



GRANT SELECT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."usuarios" TO "anon";
GRANT ALL ON TABLE "public"."usuarios" TO "authenticated";
GRANT ALL ON TABLE "public"."usuarios" TO "service_role";



REVOKE ALL ON FUNCTION "public"."admin_atualizar_usuario"("p_email" "text", "p_moderador" boolean, "p_banido" boolean, "p_nota_media" numeric, "p_total_avaliacoes" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_atualizar_usuario"("p_email" "text", "p_moderador" boolean, "p_banido" boolean, "p_nota_media" numeric, "p_total_avaliacoes" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."atualizar_contador_seguidores"() TO "anon";
GRANT ALL ON FUNCTION "public"."atualizar_contador_seguidores"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."atualizar_contador_seguidores"() TO "service_role";



GRANT ALL ON FUNCTION "public"."atualizar_conversa"() TO "anon";
GRANT ALL ON FUNCTION "public"."atualizar_conversa"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."atualizar_conversa"() TO "service_role";



GRANT ALL ON FUNCTION "public"."checar_cooldown_anuncio"() TO "anon";
GRANT ALL ON FUNCTION "public"."checar_cooldown_anuncio"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."checar_cooldown_anuncio"() TO "service_role";



GRANT ALL ON FUNCTION "public"."criar_config_usuario"() TO "anon";
GRANT ALL ON FUNCTION "public"."criar_config_usuario"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."criar_config_usuario"() TO "service_role";



GRANT ALL ON FUNCTION "public"."criar_tabela_carrinho"() TO "anon";
GRANT ALL ON FUNCTION "public"."criar_tabela_carrinho"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."criar_tabela_carrinho"() TO "service_role";



GRANT ALL ON FUNCTION "public"."decrementar_curtidas"() TO "anon";
GRANT ALL ON FUNCTION "public"."decrementar_curtidas"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."decrementar_curtidas"() TO "service_role";



GRANT ALL ON FUNCTION "public"."decrementar_curtidas_anuncio"() TO "anon";
GRANT ALL ON FUNCTION "public"."decrementar_curtidas_anuncio"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."decrementar_curtidas_anuncio"() TO "service_role";



GRANT ALL ON FUNCTION "public"."decrementar_curtidas_post"() TO "anon";
GRANT ALL ON FUNCTION "public"."decrementar_curtidas_post"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."decrementar_curtidas_post"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_anuncios_marketplace"("usuario_id_param" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_anuncios_marketplace"("usuario_id_param" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_anuncios_marketplace"("usuario_id_param" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."incrementar_curtidas"() TO "anon";
GRANT ALL ON FUNCTION "public"."incrementar_curtidas"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."incrementar_curtidas"() TO "service_role";



GRANT ALL ON FUNCTION "public"."incrementar_curtidas_anuncio"() TO "anon";
GRANT ALL ON FUNCTION "public"."incrementar_curtidas_anuncio"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."incrementar_curtidas_anuncio"() TO "service_role";



GRANT ALL ON FUNCTION "public"."incrementar_curtidas_post"() TO "anon";
GRANT ALL ON FUNCTION "public"."incrementar_curtidas_post"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."incrementar_curtidas_post"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."is_admin"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."is_admin"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_admin"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_admin"() TO "service_role";



GRANT ALL ON FUNCTION "public"."limpar_dependencias_antes_excluir_anuncio"() TO "anon";
GRANT ALL ON FUNCTION "public"."limpar_dependencias_antes_excluir_anuncio"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."limpar_dependencias_antes_excluir_anuncio"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."promover_moderador"("p_email" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."promover_moderador"("p_email" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."promover_moderador"("p_email" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."promover_moderador"("p_email" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."proteger_campos_sensiveis_usuarios"() TO "anon";
GRANT ALL ON FUNCTION "public"."proteger_campos_sensiveis_usuarios"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."proteger_campos_sensiveis_usuarios"() TO "service_role";



GRANT ALL ON FUNCTION "public"."proteger_consentimento_legal"() TO "anon";
GRANT ALL ON FUNCTION "public"."proteger_consentimento_legal"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."proteger_consentimento_legal"() TO "service_role";



GRANT ALL ON FUNCTION "public"."proteger_conteudo_mensagens"() TO "anon";
GRANT ALL ON FUNCTION "public"."proteger_conteudo_mensagens"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."proteger_conteudo_mensagens"() TO "service_role";



GRANT ALL ON FUNCTION "public"."proteger_status_anuncios"() TO "anon";
GRANT ALL ON FUNCTION "public"."proteger_status_anuncios"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."proteger_status_anuncios"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."registrar_aceite_legal"("p_terms_version" "text", "p_privacy_version" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."registrar_aceite_legal"("p_terms_version" "text", "p_privacy_version" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."registrar_aceite_legal"("p_terms_version" "text", "p_privacy_version" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."registrar_aceite_legal"("p_terms_version" "text", "p_privacy_version" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";



GRANT ALL ON FUNCTION "public"."verificar_cooldown_anuncio"() TO "anon";
GRANT ALL ON FUNCTION "public"."verificar_cooldown_anuncio"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."verificar_cooldown_anuncio"() TO "service_role";



GRANT ALL ON TABLE "public"."anuncios" TO "anon";
GRANT ALL ON TABLE "public"."anuncios" TO "authenticated";
GRANT ALL ON TABLE "public"."anuncios" TO "service_role";



GRANT ALL ON TABLE "public"."anuncios_opcionais" TO "anon";
GRANT ALL ON TABLE "public"."anuncios_opcionais" TO "authenticated";
GRANT ALL ON TABLE "public"."anuncios_opcionais" TO "service_role";



GRANT ALL ON TABLE "public"."avaliacoes" TO "anon";
GRANT ALL ON TABLE "public"."avaliacoes" TO "authenticated";
GRANT ALL ON TABLE "public"."avaliacoes" TO "service_role";



GRANT ALL ON TABLE "public"."carrinho_itens" TO "anon";
GRANT ALL ON TABLE "public"."carrinho_itens" TO "authenticated";
GRANT ALL ON TABLE "public"."carrinho_itens" TO "service_role";



GRANT ALL ON TABLE "public"."comunidade_comentarios" TO "anon";
GRANT ALL ON TABLE "public"."comunidade_comentarios" TO "authenticated";
GRANT ALL ON TABLE "public"."comunidade_comentarios" TO "service_role";



GRANT ALL ON TABLE "public"."comunidade_curtidas" TO "anon";
GRANT ALL ON TABLE "public"."comunidade_curtidas" TO "authenticated";
GRANT ALL ON TABLE "public"."comunidade_curtidas" TO "service_role";



GRANT ALL ON TABLE "public"."comunidade_posts" TO "anon";
GRANT ALL ON TABLE "public"."comunidade_posts" TO "authenticated";
GRANT ALL ON TABLE "public"."comunidade_posts" TO "service_role";



GRANT ALL ON TABLE "public"."comunidade_posts_fotos" TO "anon";
GRANT ALL ON TABLE "public"."comunidade_posts_fotos" TO "authenticated";
GRANT ALL ON TABLE "public"."comunidade_posts_fotos" TO "service_role";



GRANT ALL ON TABLE "public"."config_usuario" TO "anon";
GRANT ALL ON TABLE "public"."config_usuario" TO "authenticated";
GRANT ALL ON TABLE "public"."config_usuario" TO "service_role";



GRANT ALL ON TABLE "public"."conversas" TO "anon";
GRANT ALL ON TABLE "public"."conversas" TO "authenticated";
GRANT ALL ON TABLE "public"."conversas" TO "service_role";



GRANT ALL ON TABLE "public"."curtidas_anuncio" TO "anon";
GRANT ALL ON TABLE "public"."curtidas_anuncio" TO "authenticated";
GRANT ALL ON TABLE "public"."curtidas_anuncio" TO "service_role";



GRANT ALL ON TABLE "public"."curtidas_post" TO "anon";
GRANT ALL ON TABLE "public"."curtidas_post" TO "authenticated";
GRANT ALL ON TABLE "public"."curtidas_post" TO "service_role";



GRANT ALL ON TABLE "public"."denuncias" TO "anon";
GRANT ALL ON TABLE "public"."denuncias" TO "authenticated";
GRANT ALL ON TABLE "public"."denuncias" TO "service_role";



GRANT ALL ON TABLE "public"."encontros" TO "anon";
GRANT ALL ON TABLE "public"."encontros" TO "authenticated";
GRANT ALL ON TABLE "public"."encontros" TO "service_role";



GRANT ALL ON TABLE "public"."encontros_confirmados" TO "anon";
GRANT ALL ON TABLE "public"."encontros_confirmados" TO "authenticated";
GRANT ALL ON TABLE "public"."encontros_confirmados" TO "service_role";



GRANT ALL ON TABLE "public"."favoritos" TO "anon";
GRANT ALL ON TABLE "public"."favoritos" TO "authenticated";
GRANT ALL ON TABLE "public"."favoritos" TO "service_role";



GRANT ALL ON TABLE "public"."fotos_anuncio" TO "anon";
GRANT ALL ON TABLE "public"."fotos_anuncio" TO "authenticated";
GRANT ALL ON TABLE "public"."fotos_anuncio" TO "service_role";



GRANT ALL ON TABLE "public"."garagem_fotos" TO "anon";
GRANT ALL ON TABLE "public"."garagem_fotos" TO "authenticated";
GRANT ALL ON TABLE "public"."garagem_fotos" TO "service_role";



GRANT ALL ON TABLE "public"."garagem_gastos" TO "anon";
GRANT ALL ON TABLE "public"."garagem_gastos" TO "authenticated";
GRANT ALL ON TABLE "public"."garagem_gastos" TO "service_role";



GRANT ALL ON TABLE "public"."garagem_lembretes" TO "anon";
GRANT ALL ON TABLE "public"."garagem_lembretes" TO "authenticated";
GRANT ALL ON TABLE "public"."garagem_lembretes" TO "service_role";



GRANT ALL ON TABLE "public"."garagem_manutencoes" TO "anon";
GRANT ALL ON TABLE "public"."garagem_manutencoes" TO "authenticated";
GRANT ALL ON TABLE "public"."garagem_manutencoes" TO "service_role";



GRANT ALL ON TABLE "public"."garagem_veiculos" TO "anon";
GRANT ALL ON TABLE "public"."garagem_veiculos" TO "authenticated";
GRANT ALL ON TABLE "public"."garagem_veiculos" TO "service_role";



GRANT ALL ON TABLE "public"."marcas" TO "anon";
GRANT ALL ON TABLE "public"."marcas" TO "authenticated";
GRANT ALL ON TABLE "public"."marcas" TO "service_role";



GRANT ALL ON TABLE "public"."mensagens" TO "anon";
GRANT ALL ON TABLE "public"."mensagens" TO "authenticated";
GRANT ALL ON TABLE "public"."mensagens" TO "service_role";



GRANT ALL ON TABLE "public"."modelos" TO "anon";
GRANT ALL ON TABLE "public"."modelos" TO "authenticated";
GRANT ALL ON TABLE "public"."modelos" TO "service_role";



GRANT ALL ON TABLE "public"."opcionais" TO "anon";
GRANT ALL ON TABLE "public"."opcionais" TO "authenticated";
GRANT ALL ON TABLE "public"."opcionais" TO "service_role";



GRANT ALL ON TABLE "public"."posts_usuario" TO "anon";
GRANT ALL ON TABLE "public"."posts_usuario" TO "authenticated";
GRANT ALL ON TABLE "public"."posts_usuario" TO "service_role";



GRANT ALL ON TABLE "public"."projetos" TO "anon";
GRANT ALL ON TABLE "public"."projetos" TO "authenticated";
GRANT ALL ON TABLE "public"."projetos" TO "service_role";



GRANT ALL ON TABLE "public"."projetos_atualizacoes" TO "anon";
GRANT ALL ON TABLE "public"."projetos_atualizacoes" TO "authenticated";
GRANT ALL ON TABLE "public"."projetos_atualizacoes" TO "service_role";



GRANT ALL ON TABLE "public"."projetos_atualizacoes_fotos" TO "anon";
GRANT ALL ON TABLE "public"."projetos_atualizacoes_fotos" TO "authenticated";
GRANT ALL ON TABLE "public"."projetos_atualizacoes_fotos" TO "service_role";



GRANT ALL ON TABLE "public"."projetos_comentarios" TO "anon";
GRANT ALL ON TABLE "public"."projetos_comentarios" TO "authenticated";
GRANT ALL ON TABLE "public"."projetos_comentarios" TO "service_role";



GRANT ALL ON TABLE "public"."projetos_curtidas" TO "anon";
GRANT ALL ON TABLE "public"."projetos_curtidas" TO "authenticated";
GRANT ALL ON TABLE "public"."projetos_curtidas" TO "service_role";



GRANT ALL ON TABLE "public"."propostas" TO "anon";
GRANT ALL ON TABLE "public"."propostas" TO "authenticated";
GRANT ALL ON TABLE "public"."propostas" TO "service_role";



GRANT ALL ON TABLE "public"."seguidores" TO "anon";
GRANT ALL ON TABLE "public"."seguidores" TO "authenticated";
GRANT ALL ON TABLE "public"."seguidores" TO "service_role";



GRANT ALL ON TABLE "public"."usuarios_banidos" TO "anon";
GRANT ALL ON TABLE "public"."usuarios_banidos" TO "authenticated";
GRANT ALL ON TABLE "public"."usuarios_banidos" TO "service_role";



GRANT ALL ON TABLE "public"."usuarios_publicos" TO "anon";
GRANT ALL ON TABLE "public"."usuarios_publicos" TO "authenticated";
GRANT ALL ON TABLE "public"."usuarios_publicos" TO "service_role";



GRANT ALL ON TABLE "public"."versoes" TO "anon";
GRANT ALL ON TABLE "public"."versoes" TO "authenticated";
GRANT ALL ON TABLE "public"."versoes" TO "service_role";



REVOKE ALL ON TABLE "storage"."buckets" FROM "supabase_storage_admin";
GRANT ALL ON TABLE "storage"."buckets" TO "supabase_storage_admin" WITH GRANT OPTION;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "storage"."buckets" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "storage"."buckets" TO "authenticated";
GRANT ALL ON TABLE "storage"."buckets" TO "service_role";
GRANT ALL ON TABLE "storage"."buckets" TO "postgres" WITH GRANT OPTION;



GRANT ALL ON TABLE "storage"."buckets_analytics" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "storage"."buckets_analytics" TO "authenticated";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "storage"."buckets_analytics" TO "anon";



GRANT SELECT ON TABLE "storage"."buckets_vectors" TO "service_role";
GRANT SELECT ON TABLE "storage"."buckets_vectors" TO "anon";
GRANT SELECT ON TABLE "storage"."buckets_vectors" TO "authenticated";



REVOKE ALL ON TABLE "storage"."objects" FROM "supabase_storage_admin";
GRANT ALL ON TABLE "storage"."objects" TO "supabase_storage_admin" WITH GRANT OPTION;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "storage"."objects" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "storage"."objects" TO "authenticated";
GRANT ALL ON TABLE "storage"."objects" TO "service_role";
GRANT ALL ON TABLE "storage"."objects" TO "postgres" WITH GRANT OPTION;



GRANT ALL ON TABLE "storage"."s3_multipart_uploads" TO "service_role";
GRANT SELECT ON TABLE "storage"."s3_multipart_uploads" TO "authenticated";
GRANT SELECT ON TABLE "storage"."s3_multipart_uploads" TO "anon";



GRANT ALL ON TABLE "storage"."s3_multipart_uploads_parts" TO "service_role";
GRANT SELECT ON TABLE "storage"."s3_multipart_uploads_parts" TO "authenticated";
GRANT SELECT ON TABLE "storage"."s3_multipart_uploads_parts" TO "anon";



GRANT SELECT ON TABLE "storage"."vector_indexes" TO "service_role";
GRANT SELECT ON TABLE "storage"."vector_indexes" TO "anon";
GRANT SELECT ON TABLE "storage"."vector_indexes" TO "authenticated";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON SEQUENCES TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON FUNCTIONS TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON TABLES TO "service_role";




