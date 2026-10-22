-- =============================================================================
-- MGMOTORS — Hardening de segurança (RLS / Storage / RPC)
-- -----------------------------------------------------------------------------
-- Data: 2026-10-20
-- Origem: auditoria empírica contra produção (ANALISE-BANCA.md, seção 3)
-- Teste:  supabase/tests/rls-security-check.sh  (meta: 21 PASS / 0 FAIL)
--
-- Esta migration NÃO altera dados de negócio. Ela:
--   1. fecha a escalação de privilégio via INSERT em public.usuarios;
--   2. garante que e-mail seja único e que o perfil tenha lastro em auth.users;
--   3. remove leituras públicas indevidas (avaliações e fotos de anúncios pausados);
--   4. separa policies "FOR ALL USING (true)" em SELECT/INSERT/UPDATE/DELETE;
--   5. passa a exigir o dono do caminho nas policies de storage;
--   6. remove RPCs perigosas (promover_moderador e criar_tabela_carrinho);
--   7. fixa search_path das funções SECURITY DEFINER que estavam sem ele.
--
-- Rollback: como toda migration Supabase roda em transação, uma falha no bloco
-- de verificação final (seção 9) desfaz tudo. Para reverter manualmente depois
-- de aplicada, recrie as policies antigas a partir de
-- supabase/snapshots/schema_producao_20261020.sql.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 0. PRÉ-CONDIÇÕES
-- -----------------------------------------------------------------------------
DO $$
BEGIN
  IF to_regclass('public.usuarios') IS NULL
     OR to_regclass('public.anuncios') IS NULL
     OR to_regclass('public.mensagens') IS NULL THEN
    RAISE EXCEPTION 'Hardening abortado: schema base MGMOTORS incompleto.';
  END IF;
END
$$;

-- O índice único de e-mail só pode ser criado se não houver duplicatas.
DO $$
DECLARE
  v_email text;
BEGIN
  SELECT lower(trim(email))
    INTO v_email
  FROM public.usuarios
  WHERE email IS NOT NULL
  GROUP BY 1
  HAVING count(*) > 1
  LIMIT 1;

  IF v_email IS NOT NULL THEN
    RAISE EXCEPTION
      'Hardening abortado: o e-mail % está duplicado em public.usuarios. Corrija antes de aplicar.',
      v_email;
  END IF;
END
$$;


-- -----------------------------------------------------------------------------
-- 1. USUÁRIOS — fecha a cadeia de escalação de privilégio
-- -----------------------------------------------------------------------------
-- Vetor explorado na auditoria:
--   DELETE do próprio perfil  ->  INSERT com moderador=true  ->  is_admin()=true
-- A combinação abaixo torna o INSERT inofensivo mesmo que a policy volte a ser
-- permissiva no futuro: a policy barra as flags e o trigger as força para false.

DROP POLICY IF EXISTS "usuarios insert proprio" ON public.usuarios;

CREATE POLICY "usuarios insert proprio" ON public.usuarios
  FOR INSERT
  TO authenticated
  WITH CHECK (
    id = (SELECT auth.uid())
    AND coalesce(moderador, false) = false
    AND coalesce(is_admin, false) = false
    AND coalesce(banido, false) = false
    AND coalesce(bloqueado, false) = false
  );

-- Trigger de INSERT: garante que nenhuma flag administrativa nasça ligada,
-- mesmo que a policy seja afrouxada ou que a inserção venha de outro caminho.
CREATE OR REPLACE FUNCTION public.proteger_campos_sensiveis_usuarios_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- service_role e administradores legítimos podem criar registros completos.
  IF coalesce(current_setting('request.jwt.claim.role', true), '') <> 'service_role'
     AND NOT public.is_admin() THEN
    NEW.banido           := false;
    NEW.bloqueado        := false;
    NEW.moderador        := false;
    NEW.is_admin         := false;
    NEW.nota_media       := 0;
    NEW.total_avaliacoes := 0;
    NEW.seguidores       := 0;
    NEW.seguindo         := 0;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_proteger_campos_usuarios_insert ON public.usuarios;
CREATE TRIGGER trg_proteger_campos_usuarios_insert
  BEFORE INSERT ON public.usuarios
  FOR EACH ROW
  EXECUTE FUNCTION public.proteger_campos_sensiveis_usuarios_insert();

-- Trigger de UPDATE: a versão em produção protegia apenas banido/moderador/
-- nota_media/total_avaliacoes. Faltavam is_admin, bloqueado e email.
CREATE OR REPLACE FUNCTION public.proteger_campos_sensiveis_usuarios()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN
    NEW.banido           := OLD.banido;
    NEW.bloqueado        := OLD.bloqueado;
    NEW.moderador        := OLD.moderador;
    NEW.is_admin         := OLD.is_admin;
    NEW.email            := OLD.email;
    NEW.nota_media       := OLD.nota_media;
    NEW.total_avaliacoes := OLD.total_avaliacoes;
  END IF;
  RETURN NEW;
END;
$function$;

-- Policies legadas duplicadas (criadas antes da migration de consentimento).
-- Mantemos apenas as versões com "TO authenticated" que já estão em uso.
DROP POLICY IF EXISTS "Usuarios deletam sua conta" ON public.usuarios;
DROP POLICY IF EXISTS "Usuarios editam seu perfil" ON public.usuarios;

-- E-mail único (case-insensitive). A produção tem 15 perfis e 0 duplicatas;
-- o bloco 0 aborta a migration se isso deixar de ser verdade.
CREATE UNIQUE INDEX IF NOT EXISTS usuarios_email_lower_key
  ON public.usuarios (lower(trim(email)))
  WHERE email IS NOT NULL;

-- Lastro em auth.users: sem FK, apagar o perfil deixava uma conta Auth órfã e
-- permitia recriar a linha com o mesmo id. Em produção há 0 perfis órfãos.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'usuarios_id_auth_fkey'
  ) THEN
    IF EXISTS (
      SELECT 1
      FROM public.usuarios u
      LEFT JOIN auth.users a ON a.id = u.id
      WHERE a.id IS NULL
    ) THEN
      RAISE EXCEPTION
        'Hardening abortado: há perfis em public.usuarios sem conta em auth.users.';
    END IF;

    ALTER TABLE public.usuarios
      ADD CONSTRAINT usuarios_id_auth_fkey
      FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
  END IF;
END
$$;


-- -----------------------------------------------------------------------------
-- 2. RPCs PERIGOSAS
-- -----------------------------------------------------------------------------
-- promover_moderador: SECURITY DEFINER e GRANT para anon. O guard interno
-- (`auth.uid() IS NOT NULL`) não protege anônimo, porque auth.uid() é NULL.
-- Nenhum trecho do frontend chama esta função.
DO $$
BEGIN
  IF to_regprocedure('public.promover_moderador(text)') IS NOT NULL THEN
    REVOKE ALL ON FUNCTION public.promover_moderador(text) FROM PUBLIC;
    REVOKE ALL ON FUNCTION public.promover_moderador(text) FROM anon;
    REVOKE ALL ON FUNCTION public.promover_moderador(text) FROM authenticated;
    GRANT EXECUTE ON FUNCTION public.promover_moderador(text) TO service_role;
  END IF;
END
$$;

-- criar_tabela_carrinho: DDL executável por anon (criação de tabela em runtime).
-- A tabela já existe; o helper não tem mais razão de existir.
DROP FUNCTION IF EXISTS public.criar_tabela_carrinho();

-- A tabela nasceu em runtime, então não está nas migrations do repositório.
-- O bloco abaixo a torna reproduzível em um banco vazio (é no-op em produção).
CREATE TABLE IF NOT EXISTS public.carrinho_itens (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id uuid NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  anuncio_id uuid NOT NULL REFERENCES public.anuncios(id) ON DELETE CASCADE,
  criado_em  timestamptz DEFAULT now(),
  CONSTRAINT carrinho_itens_usuario_id_anuncio_id_key UNIQUE (usuario_id, anuncio_id)
);

ALTER TABLE public.carrinho_itens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Usuarios gerenciam seus carrinhos" ON public.carrinho_itens;
CREATE POLICY "Usuarios gerenciam seus carrinhos" ON public.carrinho_itens
  FOR ALL
  TO authenticated
  USING (usuario_id = (SELECT auth.uid()))
  WITH CHECK (usuario_id = (SELECT auth.uid()));

REVOKE ALL ON TABLE public.carrinho_itens FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.carrinho_itens TO authenticated;

-- search_path fixo nas funções SECURITY DEFINER que estavam sem ele.
-- (criar_tabela_carrinho foi removida acima.)
ALTER FUNCTION public.incrementar_curtidas()          SET search_path TO 'public', 'pg_temp';
ALTER FUNCTION public.decrementar_curtidas()          SET search_path TO 'public', 'pg_temp';
ALTER FUNCTION public.atualizar_contador_seguidores() SET search_path TO 'public', 'pg_temp';
ALTER FUNCTION public.get_anuncios_marketplace(uuid)  SET search_path TO 'public', 'pg_temp';


-- -----------------------------------------------------------------------------
-- 3. AVALIAÇÕES — remove leitura anônima
-- -----------------------------------------------------------------------------
-- Existiam duas policies de SELECT com USING (true): "Avaliacoes visíveis"
-- (PUBLIC) e "avaliacoes select publico" (anon + authenticated). Juntas, expunham
-- avaliador_id/avaliado_id para qualquer visitante.
-- O agregado (nota_media/total_avaliacoes) continua público via usuarios_publicos,
-- que é o único dado que a página de perfil anônima consome.
DROP POLICY IF EXISTS "Avaliacoes visíveis"       ON public.avaliacoes;
DROP POLICY IF EXISTS "avaliacoes select publico" ON public.avaliacoes;

CREATE POLICY "avaliacoes select autenticado" ON public.avaliacoes
  FOR SELECT
  TO authenticated
  USING (true);


-- -----------------------------------------------------------------------------
-- 4. FOTOS DE ANÚNCIO — só de anúncios ativos (ou do próprio dono)
-- -----------------------------------------------------------------------------
-- "fotos_anuncio select publico" (USING true) anulava a policy "Todos veem
-- fotos anuncio", que já fazia a checagem correta. Resultado medido: 49 fotos
-- visíveis contra 4 anúncios ativos.
DROP POLICY IF EXISTS "fotos_anuncio select publico" ON public.fotos_anuncio;


-- -----------------------------------------------------------------------------
-- 5. CURTIDAS — separa "FOR ALL USING (true)"
-- -----------------------------------------------------------------------------
-- pcurt_all/ccurt_all permitiam que qualquer pessoa (inclusive anon) apagasse
-- qualquer curtida. SELECT público é intencional (contador de curtidas).
DROP POLICY IF EXISTS "pcurt_all" ON public.projetos_curtidas;
CREATE POLICY "projetos_curtidas select publico" ON public.projetos_curtidas
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "projetos_curtidas insert proprio" ON public.projetos_curtidas
  FOR INSERT TO authenticated WITH CHECK (user_id = (SELECT auth.uid()));
CREATE POLICY "projetos_curtidas update proprio" ON public.projetos_curtidas
  FOR UPDATE TO authenticated
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));
CREATE POLICY "projetos_curtidas delete proprio" ON public.projetos_curtidas
  FOR DELETE TO authenticated USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "ccurt_all" ON public.comunidade_curtidas;
CREATE POLICY "comunidade_curtidas select publico" ON public.comunidade_curtidas
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "comunidade_curtidas insert proprio" ON public.comunidade_curtidas
  FOR INSERT TO authenticated WITH CHECK (user_id = (SELECT auth.uid()));
CREATE POLICY "comunidade_curtidas update proprio" ON public.comunidade_curtidas
  FOR UPDATE TO authenticated
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));
CREATE POLICY "comunidade_curtidas delete proprio" ON public.comunidade_curtidas
  FOR DELETE TO authenticated USING (user_id = (SELECT auth.uid()));


-- -----------------------------------------------------------------------------
-- 6. WITH CHECK EXPLÍCITO EM POLICIES "FOR ALL"
-- -----------------------------------------------------------------------------
-- Em policies FOR ALL, o WITH CHECK omitido herda o USING. O comportamento já
-- era seguro, mas explicitar evita regressão silenciosa em futuras edições.

DROP POLICY IF EXISTS "Envolvidos veem propostas" ON public.propostas;
CREATE POLICY "Envolvidos veem propostas" ON public.propostas
  FOR ALL
  TO authenticated
  USING (
    (SELECT auth.uid()) = comprador_id OR (SELECT auth.uid()) = vendedor_id
  )
  WITH CHECK (
    (SELECT auth.uid()) = comprador_id OR (SELECT auth.uid()) = vendedor_id
  );

DROP POLICY IF EXISTS "usuarios_atualizam_conversas" ON public.conversas;
CREATE POLICY "usuarios_atualizam_conversas" ON public.conversas
  FOR UPDATE
  TO authenticated
  USING (
    (SELECT auth.uid()) = usuario1_id OR (SELECT auth.uid()) = usuario2_id
  )
  WITH CHECK (
    (SELECT auth.uid()) = usuario1_id OR (SELECT auth.uid()) = usuario2_id
  );

DROP POLICY IF EXISTS "enc_update" ON public.encontros;
CREATE POLICY "enc_update" ON public.encontros
  FOR UPDATE
  TO authenticated
  USING (criador_id = (SELECT auth.uid()))
  WITH CHECK (criador_id = (SELECT auth.uid()));

-- Policies duplicadas/legadas
DROP POLICY IF EXISTS "usuarios_veem_suas_conversas" ON public.conversas;
DROP POLICY IF EXISTS "Denuncias criar" ON public.denuncias;


-- -----------------------------------------------------------------------------
-- 7. STORAGE — dono do caminho
-- -----------------------------------------------------------------------------
-- Todas as 28 policies de storage.objects checavam apenas bucket_id e
-- auth.role() = 'authenticated'. Qualquer usuário autenticado podia
-- sobrescrever e apagar arquivos de terceiros. Além disso, "public select
-- cn6lji_0" permitia a um anônimo LISTAR FOTOS-ANUNCIOS/mensagens/<uid>/ —
-- enumerando fotos de conversas privadas.
--
-- Convenções de caminho usadas pelo frontend:
--   FOTOS-ANUNCIOS/anuncios/<anuncio_id>/...   (dono do anúncio)
--   FOTOS-ANUNCIOS/mensagens/<user_id>/...     (dono da conversa)
--   fotos-perfil/perfil/<user_id>/...          (dono do perfil)
--   fotos-perfil/posts/<user_id>/...           (dono do post)
--   FOTOS-COMUNIDADE/posts/<user_id>/...
--   FOTOS-GARAGEM/<user_id>/...
--
-- Os buckets FOTOS-ANUNCIOS e fotos-perfil são públicos (confirmado: a URL
-- /object/public/... responde 200 sem apikey). Por isso as imagens continuam
-- abrindo normalmente sem policy de SELECT pública — o que se fecha aqui é a
-- listagem e a escrita por terceiros.

DROP POLICY IF EXISTS "Acesso público para FOTOS-ANUNCIOS"            ON storage.objects;
DROP POLICY IF EXISTS "Acesso público para fotos-perfil"              ON storage.objects;
DROP POLICY IF EXISTS "Leitura publica fotos anuncio"                 ON storage.objects;
DROP POLICY IF EXISTS "Upload para usuários autenticados"             ON storage.objects;
DROP POLICY IF EXISTS "Usuarios autenticados atualizam fotos anuncio" ON storage.objects;
DROP POLICY IF EXISTS "Usuarios autenticados enviam fotos anuncio"    ON storage.objects;
DROP POLICY IF EXISTS "Usuarios autenticados removem fotos anuncio"   ON storage.objects;
DROP POLICY IF EXISTS "Usuários autenticados podem atualizar"         ON storage.objects;
DROP POLICY IF EXISTS "Usuários autenticados podem atualizar FOTOS-ANUNCIOS" ON storage.objects;
DROP POLICY IF EXISTS "Usuários autenticados podem atualizar perfil"  ON storage.objects;
DROP POLICY IF EXISTS "Usuários autenticados podem deletar"           ON storage.objects;
DROP POLICY IF EXISTS "Usuários autenticados podem deletar FOTOS-ANUNCIOS" ON storage.objects;
DROP POLICY IF EXISTS "Usuários autenticados podem deletar perfil"    ON storage.objects;
DROP POLICY IF EXISTS "Usuários autenticados podem upload"            ON storage.objects;
DROP POLICY IF EXISTS "Usuários autenticados podem upload FOTOS-ANUNCIOS" ON storage.objects;
DROP POLICY IF EXISTS "Usuários autenticados podem upload perfil"     ON storage.objects;
DROP POLICY IF EXISTS "Usuários podem atualizar suas fotos"           ON storage.objects;
DROP POLICY IF EXISTS "Usuários podem deletar suas fotos"             ON storage.objects;
DROP POLICY IF EXISTS "allow authenticaded uploads cn6lji_0"          ON storage.objects;
DROP POLICY IF EXISTS "public select cn6lji_0"                        ON storage.objects;
DROP POLICY IF EXISTS "fc_select"                                     ON storage.objects;
-- As policies reais do schema usam o sufixo _upload. Os nomes esperados pela
-- versão anterior da migration nunca existiram e deixavam os uploads
-- permissivos ativos.
DROP POLICY IF EXISTS "fc_upload"                                     ON storage.objects;
DROP POLICY IF EXISTS "fc_update"                                     ON storage.objects;
DROP POLICY IF EXISTS "fc_delete"                                     ON storage.objects;
DROP POLICY IF EXISTS "fg_select"                                     ON storage.objects;
DROP POLICY IF EXISTS "fg_upload"                                     ON storage.objects;
DROP POLICY IF EXISTS "fg_update"                                     ON storage.objects;
DROP POLICY IF EXISTS "fg_delete"                                     ON storage.objects;

-- fotos-perfil, FOTOS-COMUNIDADE e FOTOS-GARAGEM:
-- o uid precisa ser o 1º ou o 2º segmento do caminho.
CREATE POLICY "fotos_perfil_select_dono" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id IN ('fotos-perfil', 'FOTOS-COMUNIDADE', 'FOTOS-GARAGEM')
    AND (
      (storage.foldername(name))[1] = (SELECT auth.uid())::text
      OR (storage.foldername(name))[2] = (SELECT auth.uid())::text
    )
  );

CREATE POLICY "fotos_perfil_insert_dono" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id IN ('fotos-perfil', 'FOTOS-COMUNIDADE', 'FOTOS-GARAGEM')
    AND (
      (storage.foldername(name))[1] = (SELECT auth.uid())::text
      OR (storage.foldername(name))[2] = (SELECT auth.uid())::text
    )
  );

CREATE POLICY "fotos_perfil_update_dono" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id IN ('fotos-perfil', 'FOTOS-COMUNIDADE', 'FOTOS-GARAGEM')
    AND (
      (storage.foldername(name))[1] = (SELECT auth.uid())::text
      OR (storage.foldername(name))[2] = (SELECT auth.uid())::text
    )
  )
  WITH CHECK (
    bucket_id IN ('fotos-perfil', 'FOTOS-COMUNIDADE', 'FOTOS-GARAGEM')
    AND (
      (storage.foldername(name))[1] = (SELECT auth.uid())::text
      OR (storage.foldername(name))[2] = (SELECT auth.uid())::text
    )
  );

CREATE POLICY "fotos_perfil_delete_dono" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id IN ('fotos-perfil', 'FOTOS-COMUNIDADE', 'FOTOS-GARAGEM')
    AND (
      (storage.foldername(name))[1] = (SELECT auth.uid())::text
      OR (storage.foldername(name))[2] = (SELECT auth.uid())::text
    )
  );

-- FOTOS-ANUNCIOS: chat (mensagens/<uid>) ou anúncio do próprio usuário.
CREATE POLICY "fotos_anuncios_select_dono" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'FOTOS-ANUNCIOS'
    AND (
      (
        (storage.foldername(name))[1] = 'mensagens'
        AND (storage.foldername(name))[2] = (SELECT auth.uid())::text
      )
      OR (
        (storage.foldername(name))[1] = 'anuncios'
        AND EXISTS (
          SELECT 1
          FROM public.anuncios a
          WHERE a.id::text = (storage.foldername(name))[2]
            AND a.usuario_id = (SELECT auth.uid())
        )
      )
      OR public.is_admin()
    )
  );

CREATE POLICY "fotos_anuncios_insert_dono" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'FOTOS-ANUNCIOS'
    AND (
      (
        (storage.foldername(name))[1] = 'mensagens'
        AND (storage.foldername(name))[2] = (SELECT auth.uid())::text
      )
      OR (
        (storage.foldername(name))[1] = 'anuncios'
        AND EXISTS (
          SELECT 1
          FROM public.anuncios a
          WHERE a.id::text = (storage.foldername(name))[2]
            AND a.usuario_id = (SELECT auth.uid())
        )
      )
      OR public.is_admin()
    )
  );

CREATE POLICY "fotos_anuncios_update_dono" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'FOTOS-ANUNCIOS'
    AND (
      (
        (storage.foldername(name))[1] = 'mensagens'
        AND (storage.foldername(name))[2] = (SELECT auth.uid())::text
      )
      OR (
        (storage.foldername(name))[1] = 'anuncios'
        AND EXISTS (
          SELECT 1
          FROM public.anuncios a
          WHERE a.id::text = (storage.foldername(name))[2]
            AND a.usuario_id = (SELECT auth.uid())
        )
      )
      OR public.is_admin()
    )
  )
  WITH CHECK (
    bucket_id = 'FOTOS-ANUNCIOS'
    AND (
      (
        (storage.foldername(name))[1] = 'mensagens'
        AND (storage.foldername(name))[2] = (SELECT auth.uid())::text
      )
      OR (
        (storage.foldername(name))[1] = 'anuncios'
        AND EXISTS (
          SELECT 1
          FROM public.anuncios a
          WHERE a.id::text = (storage.foldername(name))[2]
            AND a.usuario_id = (SELECT auth.uid())
        )
      )
      OR public.is_admin()
    )
  );

CREATE POLICY "fotos_anuncios_delete_dono" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'FOTOS-ANUNCIOS'
    AND (
      (
        (storage.foldername(name))[1] = 'mensagens'
        AND (storage.foldername(name))[2] = (SELECT auth.uid())::text
      )
      OR (
        (storage.foldername(name))[1] = 'anuncios'
        AND EXISTS (
          SELECT 1
          FROM public.anuncios a
          WHERE a.id::text = (storage.foldername(name))[2]
            AND a.usuario_id = (SELECT auth.uid())
        )
      )
      OR public.is_admin()
    )
  );


-- -----------------------------------------------------------------------------
-- 8. VIEW usuarios_publicos
-- -----------------------------------------------------------------------------
-- A view é SECURITY DEFINER (comportamento padrão) e expõe apenas colunas não
-- sensíveis. security_invoker = true quebraria o perfil público: o RLS de
-- public.usuarios só permite SELECT do próprio registro (ou admin), então um
-- visitante anônimo passaria a ver zero linhas. Mantida como está de propósito.
COMMENT ON VIEW public.usuarios_publicos IS
  'Projeção pública intencional (security definer). Expõe somente colunas de apresentação; nunca adicionar email, telefone ou flags administrativas.';


-- -----------------------------------------------------------------------------
-- 9. VERIFICAÇÃO FINAL
-- -----------------------------------------------------------------------------
-- Se qualquer invariante falhar, a transação inteira é revertida e o
-- `supabase db push` termina com erro — evitando um deploy "meio aplicado".
DO $$
DECLARE
  v_falhas text[] := ARRAY[]::text[];
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'fotos_anuncio'
      AND policyname = 'fotos_anuncio select publico'
  ) THEN
    v_falhas := v_falhas || 'fotos_anuncio ainda tem leitura pública total';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'avaliacoes'
      AND cmd = 'SELECT' AND roles::text = '{public}'
  ) THEN
    v_falhas := v_falhas || 'avaliacoes ainda tem SELECT para PUBLIC';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename IN ('projetos_curtidas', 'comunidade_curtidas')
      AND cmd = 'ALL'
  ) THEN
    v_falhas := v_falhas || 'curtidas ainda usam policy FOR ALL';
  END IF;

  IF to_regprocedure('public.promover_moderador(text)') IS NOT NULL
     AND has_function_privilege('anon', 'public.promover_moderador(text)', 'EXECUTE') THEN
    v_falhas := v_falhas || 'anon ainda executa promover_moderador';
  END IF;

  IF to_regprocedure('public.criar_tabela_carrinho()') IS NOT NULL THEN
    v_falhas := v_falhas || 'criar_tabela_carrinho ainda existe';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'trg_proteger_campos_usuarios_insert'
      AND tgrelid = 'public.usuarios'::regclass
      AND NOT tgisinternal
  ) THEN
    v_falhas := v_falhas || 'trigger BEFORE INSERT de usuarios ausente';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public' AND tablename = 'usuarios'
      AND indexname = 'usuarios_email_lower_key'
  ) THEN
    v_falhas := v_falhas || 'índice único de e-mail ausente';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname IN (
        'Usuarios autenticados enviam fotos anuncio',
        'Usuarios autenticados removem fotos anuncio',
        'public select cn6lji_0',
        'fc_upload',
        'fg_upload'
      )
  ) THEN
    v_falhas := v_falhas || 'policies antigas de storage ainda existem';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'fotos_perfil_insert_dono'
      AND cmd = 'INSERT'
      AND coalesce(with_check, '') LIKE '%auth.uid%'
      AND coalesce(with_check, '') LIKE '%FOTOS-COMUNIDADE%'
  ) THEN
    v_falhas := v_falhas || 'policy de upload da comunidade não exige o dono do caminho';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'fotos_perfil_insert_dono'
      AND cmd = 'INSERT'
      AND coalesce(with_check, '') LIKE '%auth.uid%'
      AND coalesce(with_check, '') LIKE '%FOTOS-GARAGEM%'
  ) THEN
    v_falhas := v_falhas || 'policy de upload da garagem não exige o dono do caminho';
  END IF;

  IF array_length(v_falhas, 1) IS NOT NULL THEN
    RAISE EXCEPTION 'Hardening incompleto: %', array_to_string(v_falhas, '; ');
  END IF;

  RAISE NOTICE 'Hardening de segurança aplicado e verificado com sucesso.';
END
$$;
