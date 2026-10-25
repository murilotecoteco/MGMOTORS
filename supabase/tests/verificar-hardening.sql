-- =============================================================================
-- MGMOTORS — Verificação SOMENTE LEITURA do estado de segurança do banco
-- -----------------------------------------------------------------------------
-- Confere se as migrations versionadas em supabase/migrations/ estão de fato
-- aplicadas (legal_consent, security_hardening, notifications_rf14,
-- performance_indexes, track_ban_pauses, paginated_marketplace_rpc).
--
-- SEGURO PARA PRODUÇÃO: só consulta catálogos (pg_policies, pg_proc, pg_trigger,
-- information_schema...). Não cria, altera nem apaga nada.
--
-- COMO USAR:
--   1. Supabase Dashboard -> SQL Editor -> New query
--   2. Cole este arquivo inteiro e clique em "Run"
--   3. Esperado: todas as linhas com status = PASS
--   4. Salve o resultado em evidencias/hardening-<ambiente>-<data>.txt
-- =============================================================================

WITH checks AS (

  -- 1. RLS habilitado em todas as tabelas do schema public -------------------
  SELECT 1 AS ord, 'RLS habilitado em todas as tabelas public' AS item,
         NOT EXISTS (
           SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
           WHERE n.nspname = 'public' AND c.relkind = 'r' AND NOT c.relrowsecurity
         ) AS ok,
         coalesce((
           SELECT string_agg(c.relname, ', ')
           FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
           WHERE n.nspname = 'public' AND c.relkind = 'r' AND NOT c.relrowsecurity
         ), 'todas com RLS') AS detalhe

  -- 2. usuarios: leitura só do próprio registro ou admin ----------------------
  UNION ALL
  SELECT 2, 'usuarios: policy "usuarios select proprio ou admin" presente',
         EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public'
                 AND tablename = 'usuarios' AND policyname = 'usuarios select proprio ou admin'),
         ''

  UNION ALL
  SELECT 3, 'usuarios: policies públicas antigas removidas',
         NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public'
                     AND tablename = 'usuarios'
                     AND policyname IN ('Todos veem usuarios', 'usuarios select publico', 'Sistema cria usuarios')),
         coalesce((SELECT string_agg(policyname, ', ') FROM pg_policies WHERE schemaname = 'public'
                   AND tablename = 'usuarios'
                   AND policyname IN ('Todos veem usuarios', 'usuarios select publico', 'Sistema cria usuarios')), '')

  UNION ALL
  SELECT 4, 'usuarios: anon sem INSERT',
         NOT EXISTS (SELECT 1 FROM information_schema.role_table_grants
                     WHERE table_schema = 'public' AND table_name = 'usuarios'
                     AND grantee = 'anon' AND privilege_type = 'INSERT'),
         ''

  UNION ALL
  SELECT 5, 'usuarios: FK usuarios_id_auth_fkey para auth.users',
         EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'usuarios_id_auth_fkey'),
         ''

  UNION ALL
  SELECT 6, 'usuarios: trigger BEFORE INSERT protege moderador/is_admin',
         EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_proteger_campos_usuarios_insert'
                 AND tgrelid = to_regclass('public.usuarios') AND NOT tgisinternal),
         ''

  UNION ALL
  SELECT 7, 'usuarios: trigger BEFORE UPDATE protege consentimento legal',
         EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_proteger_consentimento_legal'
                 AND tgrelid = to_regclass('public.usuarios') AND NOT tgisinternal),
         ''

  UNION ALL
  SELECT 8, 'usuarios: índice único de e-mail (usuarios_email_lower_key)',
         EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'public'
                 AND tablename = 'usuarios' AND indexname = 'usuarios_email_lower_key'),
         ''

  -- 3. View pública ----------------------------------------------------------
  UNION ALL
  SELECT 9, 'view usuarios_publicos existe',
         EXISTS (SELECT 1 FROM information_schema.views
                 WHERE table_schema = 'public' AND table_name = 'usuarios_publicos'),
         ''

  UNION ALL
  SELECT 10, 'view usuarios_publicos não expõe email/telefone/flags/preferencias',
         NOT EXISTS (SELECT 1 FROM information_schema.columns
                     WHERE table_schema = 'public' AND table_name = 'usuarios_publicos'
                     AND column_name IN ('email', 'telefone', 'is_admin', 'moderador',
                                         'bloqueado', 'preferencias', 'data_nascimento')),
         coalesce((SELECT string_agg(column_name, ', ') FROM information_schema.columns
                   WHERE table_schema = 'public' AND table_name = 'usuarios_publicos'
                   AND column_name IN ('email', 'telefone', 'is_admin', 'moderador',
                                       'bloqueado', 'preferencias', 'data_nascimento')), '')

  -- 4. Funções -----------------------------------------------------------------
  UNION ALL
  SELECT 11, 'função is_admin() existe',
         to_regprocedure('public.is_admin()') IS NOT NULL, ''

  UNION ALL
  SELECT 12, 'função registrar_aceite_legal existe e anon não executa',
         CASE WHEN to_regprocedure('public.registrar_aceite_legal(text, text)') IS NULL THEN false
              ELSE NOT has_function_privilege('anon', 'public.registrar_aceite_legal(text, text)', 'EXECUTE') END,
         ''

  UNION ALL
  SELECT 13, 'promover_moderador: anon e authenticated sem EXECUTE',
         CASE WHEN to_regprocedure('public.promover_moderador(text)') IS NULL THEN true
              ELSE NOT has_function_privilege('anon', 'public.promover_moderador(text)', 'EXECUTE')
               AND NOT has_function_privilege('authenticated', 'public.promover_moderador(text)', 'EXECUTE') END,
         CASE WHEN to_regprocedure('public.promover_moderador(text)') IS NULL THEN 'função não existe' ELSE '' END

  UNION ALL
  SELECT 14, 'criar_tabela_carrinho() removida',
         to_regprocedure('public.criar_tabela_carrinho()') IS NULL, ''

  UNION ALL
  SELECT 15, 'funções SECURITY DEFINER com search_path fixo',
         NOT EXISTS (
           SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
           WHERE n.nspname = 'public' AND p.prosecdef
             AND NOT EXISTS (SELECT 1 FROM unnest(coalesce(p.proconfig, '{}')) cfg
                             WHERE cfg LIKE 'search_path=%')
         ),
         coalesce((
           SELECT string_agg(p.proname, ', ')
           FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
           WHERE n.nspname = 'public' AND p.prosecdef
             AND NOT EXISTS (SELECT 1 FROM unnest(coalesce(p.proconfig, '{}')) cfg
                             WHERE cfg LIKE 'search_path=%')
         ), 'todas com search_path')

  UNION ALL
  SELECT 16, 'RPC get_anuncios_marketplace_paginado existe',
         EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                 WHERE n.nspname = 'public' AND p.proname = 'get_anuncios_marketplace_paginado'),
         ''

  -- 5. Policies de tabelas de dados ---------------------------------------------
  UNION ALL
  SELECT 17, 'fotos_anuncio: leitura pública total removida',
         NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public'
                     AND tablename = 'fotos_anuncio' AND policyname = 'fotos_anuncio select publico'),
         ''

  UNION ALL
  SELECT 18, 'avaliacoes: sem SELECT para PUBLIC',
         NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public'
                     AND tablename = 'avaliacoes' AND cmd = 'SELECT' AND roles::text = '{public}'),
         ''

  UNION ALL
  SELECT 19, 'projetos_curtidas/comunidade_curtidas: sem policy FOR ALL',
         NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public'
                     AND tablename IN ('projetos_curtidas', 'comunidade_curtidas') AND cmd = 'ALL'),
         ''

  UNION ALL
  SELECT 20, 'carrinho_itens: RLS ligado e anon sem privilégios',
         EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                 WHERE n.nspname = 'public' AND c.relname = 'carrinho_itens' AND c.relrowsecurity)
         AND NOT EXISTS (SELECT 1 FROM information_schema.role_table_grants
                         WHERE table_schema = 'public' AND table_name = 'carrinho_itens' AND grantee = 'anon'),
         ''

  -- 6. Notificações (RF14) -------------------------------------------------------
  UNION ALL
  SELECT 21, 'notificacoes: tabela com RLS e policies próprias',
         EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                 WHERE n.nspname = 'public' AND c.relname = 'notificacoes' AND c.relrowsecurity)
         AND EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public'
                     AND tablename = 'notificacoes' AND policyname = 'notificacoes_select_proprias')
         AND EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public'
                     AND tablename = 'notificacoes' AND policyname = 'notificacoes_update_proprias'),
         ''

  UNION ALL
  SELECT 22, 'mensagens: trigger trg_notificar_nova_mensagem',
         EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_notificar_nova_mensagem'
                 AND tgrelid = to_regclass('public.mensagens') AND NOT tgisinternal),
         ''

  -- 7. Storage ---------------------------------------------------------------------
  UNION ALL
  SELECT 23, 'storage: policies antigas (sem dono do caminho) removidas',
         NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects'
                     AND policyname IN ('Usuarios autenticados enviam fotos anuncio',
                                        'Usuarios autenticados removem fotos anuncio',
                                        'Upload para usuários autenticados',
                                        'public select cn6lji_0', 'allow authenticaded uploads cn6lji_0',
                                        'fc_upload', 'fg_upload', 'fc_update', 'fg_update',
                                        'fc_delete', 'fg_delete')),
         coalesce((SELECT string_agg(policyname, ', ') FROM pg_policies
                   WHERE schemaname = 'storage' AND tablename = 'objects'
                   AND policyname IN ('Usuarios autenticados enviam fotos anuncio',
                                      'Usuarios autenticados removem fotos anuncio',
                                      'Upload para usuários autenticados',
                                      'public select cn6lji_0', 'allow authenticaded uploads cn6lji_0',
                                      'fc_upload', 'fg_upload', 'fc_update', 'fg_update',
                                      'fc_delete', 'fg_delete')), '')

  UNION ALL
  SELECT 24, 'storage: 8 policies novas por dono do caminho presentes',
         (SELECT count(*) FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects'
          AND policyname IN ('fotos_perfil_select_dono', 'fotos_perfil_insert_dono',
                             'fotos_perfil_update_dono', 'fotos_perfil_delete_dono',
                             'fotos_anuncios_select_dono', 'fotos_anuncios_insert_dono',
                             'fotos_anuncios_update_dono', 'fotos_anuncios_delete_dono')) = 8,
         (SELECT count(*)::text || ' de 8' FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects'
          AND policyname LIKE 'fotos_%_dono')

  UNION ALL
  SELECT 25, 'storage: toda policy de escrita em objects exige auth.uid()',
         NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects'
                     AND cmd IN ('INSERT', 'UPDATE', 'DELETE', 'ALL')
                     AND coalesce(qual, '') || coalesce(with_check, '') NOT LIKE '%auth.uid%'),
         coalesce((SELECT string_agg(policyname, ', ') FROM pg_policies
                   WHERE schemaname = 'storage' AND tablename = 'objects'
                   AND cmd IN ('INSERT', 'UPDATE', 'DELETE', 'ALL')
                   AND coalesce(qual, '') || coalesce(with_check, '') NOT LIKE '%auth.uid%'), '')

  -- 8. Performance / moderação ----------------------------------------------------
  UNION ALL
  SELECT 26, 'anuncios: coluna pausado_por_ban',
         EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public'
                 AND table_name = 'anuncios' AND column_name = 'pausado_por_ban'),
         ''

  UNION ALL
  SELECT 27, 'índices de performance do marketplace',
         (SELECT count(*) FROM pg_indexes WHERE schemaname = 'public'
          AND indexname IN ('idx_anuncios_marketplace_ativos_recentes', 'idx_anuncios_marketplace_tipo_estado',
                            'idx_anuncios_marketplace_preco', 'idx_fotos_anuncio_principal',
                            'idx_curtidas_anuncio_usuario_anuncio', 'idx_notificacoes_usuario_data')) = 6,
         (SELECT count(*)::text || ' de 6' FROM pg_indexes WHERE schemaname = 'public'
          AND indexname IN ('idx_anuncios_marketplace_ativos_recentes', 'idx_anuncios_marketplace_tipo_estado',
                            'idx_anuncios_marketplace_preco', 'idx_fotos_anuncio_principal',
                            'idx_curtidas_anuncio_usuario_anuncio', 'idx_notificacoes_usuario_data'))
)
SELECT ord,
       CASE WHEN ok THEN 'PASS' ELSE 'FAIL' END AS status,
       item,
       detalhe
FROM checks
UNION ALL
SELECT 99,
       CASE WHEN bool_and(ok) THEN 'PASS' ELSE 'FAIL' END,
       'RESUMO: ' || count(*) FILTER (WHERE ok) || ' PASS / ' || count(*) FILTER (WHERE NOT ok) || ' FAIL',
       ''
FROM checks
ORDER BY ord;
