-- Keep the public profile view read-only for browser roles.
-- The project historically granted ALL on public objects by default, and this
-- simple view is auto-updatable unless write privileges are explicitly revoked.
REVOKE ALL ON TABLE public.usuarios_publicos FROM anon, authenticated;
GRANT SELECT ON TABLE public.usuarios_publicos TO anon, authenticated, service_role;

DO $$
BEGIN
  IF has_table_privilege('anon', 'public.usuarios_publicos', 'INSERT')
     OR has_table_privilege('anon', 'public.usuarios_publicos', 'UPDATE')
     OR has_table_privilege('anon', 'public.usuarios_publicos', 'DELETE') THEN
    RAISE EXCEPTION 'hardening failed: anon can still write to usuarios_publicos';
  END IF;

  IF has_table_privilege('authenticated', 'public.usuarios_publicos', 'INSERT')
     OR has_table_privilege('authenticated', 'public.usuarios_publicos', 'UPDATE')
     OR has_table_privilege('authenticated', 'public.usuarios_publicos', 'DELETE') THEN
    RAISE EXCEPTION 'hardening failed: authenticated can still write to usuarios_publicos';
  END IF;
END $$;
