-- =============================================================================
-- MGMOTORS — Exportador do schema efetivo do banco (1 única query)
-- -----------------------------------------------------------------------------
-- COMO USAR:
--   1. Supabase Dashboard -> SQL Editor -> New query
--   2. Cole ESTE arquivo inteiro
--   3. Clique em "Run" (ou Ctrl+Enter)
--   4. Copie o resultado (1 linha, 1 coluna "schema_dump") e cole aqui
--
-- Saída: um único campo de texto com tabelas, colunas, policies RLS,
-- funções (com corpo + search_path), triggers, flags de RLS, GRANTs e índices.
-- =============================================================================

SELECT string_agg(line, E'\n' ORDER BY ord, sub, line) AS schema_dump
FROM (
  -- 1. TABELAS -------------------------------------------------------------
  SELECT 1 AS ord, 1 AS sub,
         '### TABELA ' || quote_ident(table_name) AS line
  FROM information_schema.tables
  WHERE table_schema = 'public' AND table_type = 'BASE TABLE'

  UNION ALL
  SELECT 2, 1,
         '### COLUNAS ' || table_name || ' :: ' ||
         string_agg(
           column_name || ' ' || data_type ||
           CASE WHEN character_maximum_length IS NOT NULL THEN '('||character_maximum_length||')' ELSE '' END ||
           CASE WHEN is_nullable = 'NO' THEN ' NOT NULL' ELSE '' END ||
           CASE WHEN column_default IS NOT NULL THEN ' DEFAULT '||column_default ELSE '' END,
           ' | ' ORDER BY ordinal_position)
  FROM information_schema.columns
  WHERE table_schema = 'public'
  GROUP BY table_name

  UNION ALL
  SELECT 3, 1,
         '### RLS ' || relname || ' :: enabled=' || relrowsecurity ||
         ' force=' || relforcerowsecurity
  FROM pg_class r
  JOIN pg_namespace n ON n.oid = r.relnamespace
  WHERE n.nspname = 'public' AND r.relkind = 'r'

  -- 2. POLICIES RLS --------------------------------------------------------
  UNION ALL
  SELECT 4, 1,
         '### POLICY [' || tablename || '] ' || policyname ||
         ' :: cmd=' || cmd ||
         ' | roles=' || roles::text ||
         ' | USING=' || coalesce(qual, '(none)') ||
         ' | WITH CHECK=' || coalesce(with_check, '(none)')
  FROM pg_policies
  WHERE schemaname = 'public'

  -- 3. FUNCOES -------------------------------------------------------------
  UNION ALL
  SELECT 5, 1,
         '### FUNCTION ' || p.proname || '(' || pg_get_function_arguments(p.oid) || ')' ||
         ' -> ' || pg_get_function_result(p.oid) ||
         ' :: ' || CASE p.prosecdef WHEN true THEN 'SECURITY DEFINER' ELSE 'INVOKER' END ||
         ' | config=' || coalesce(array_to_string(p.proconfig, ','), '(none)') ||
         E'\n' || p.prosrc
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'

  -- 4. TRIGGERS ------------------------------------------------------------
  UNION ALL
  SELECT 6, 1,
         '### TRIGGER ' || relname || ' :: ' || tgname || ' :: ' || pg_get_triggerdef(t.oid)
  FROM pg_trigger t
  JOIN pg_class r ON r.oid = t.tgrelid
  JOIN pg_namespace n ON n.oid = r.relnamespace
  WHERE n.nspname = 'public' AND NOT t.tgisinternal

  -- 5. GRANTS --------------------------------------------------------------
  UNION ALL
  SELECT 7, 1,
         '### GRANT TABLE ' || table_name || ' -> ' || grantee || ' :: ' || privilege_type
  FROM information_schema.role_table_grants
  WHERE table_schema = 'public' AND grantee IN ('anon', 'authenticated', 'PUBLIC')

  UNION ALL
  SELECT 8, 1,
         '### GRANT FUNCTION ' || routine_name || ' -> ' || grantee || ' :: ' || privilege_type
  FROM information_schema.role_routine_grants
  WHERE routine_schema = 'public' AND grantee IN ('anon', 'authenticated', 'PUBLIC')

  UNION ALL
  SELECT 9, 1,
         '### GRANT SCHEMA ' || table_schema || ' -> ' || grantee || ' :: ' || privilege_type
  FROM information_schema.role_usage_grants
  WHERE table_schema = 'public' AND grantee IN ('anon', 'authenticated', 'PUBLIC')

  -- 6. INDICES -------------------------------------------------------------
  UNION ALL
  SELECT 10, 1,
         '### INDEX ' || tablename || ' :: ' || indexname || ' :: ' || indexdef
  FROM pg_indexes
  WHERE schemaname = 'public'

  -- 7. ENUMS / TIPOS -------------------------------------------------------
  UNION ALL
  SELECT 11, 1,
         '### TYPE ' || t.typname || ' :: ' || string_agg(e.enumlabel, ', ' ORDER BY e.enumsortorder)
  FROM pg_type t
  JOIN pg_enum e ON e.enumtypid = t.oid
  JOIN pg_namespace n ON n.oid = t.typnamespace
  WHERE n.nspname = 'public'
  GROUP BY t.typname

  -- 8. STORAGE -------------------------------------------------------------
  UNION ALL
  SELECT 12, 1,
         '### STORAGE BUCKET ' || b.id || ' :: public=' || b.public ||
         ' :: file_size_limit=' || coalesce(b.file_size_limit::text, '-') ||
         ' :: allowed_mime=' || coalesce(array_to_string(b.allowed_mime_types, ','), '(all)')
  FROM storage.buckets b
  WHERE b.id IN ('FOTOS-ANUNCIOS', 'fotos-perfil', 'FOTOS-COMUNIDADE', 'FOTOS-GARAGEM')

  UNION ALL
  SELECT 13, 1,
         '### STORAGE POLICY [' || policyname || '] on ' || tablename ||
         ' :: cmd=' || cmd || ' | roles=' || roles::text ||
         ' | USING=' || coalesce(qual, '(none)') ||
         ' | WITH CHECK=' || coalesce(with_check, '(none)')
  FROM pg_policies
  WHERE schemaname = 'storage'
) s;
