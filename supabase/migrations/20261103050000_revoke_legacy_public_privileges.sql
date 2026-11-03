-- These modules are not referenced by the current application. Preserve their
-- data for now, but remove the inherited public write surface until a final
-- retention/drop decision is approved.
DO $$
DECLARE
  tabela text;
BEGIN
  FOREACH tabela IN ARRAY ARRAY[
    'comunidade_comentarios', 'comunidade_curtidas', 'comunidade_posts',
    'comunidade_posts_fotos', 'encontros', 'encontros_confirmados',
    'garagem_fotos', 'garagem_gastos', 'garagem_lembretes',
    'garagem_manutencoes', 'garagem_veiculos', 'projetos',
    'projetos_atualizacoes', 'projetos_atualizacoes_fotos',
    'projetos_comentarios', 'projetos_curtidas'
  ]
  LOOP
    IF to_regclass('public.' || tabela) IS NOT NULL THEN
      EXECUTE format('REVOKE ALL ON TABLE public.%I FROM anon, authenticated', tabela);
    END IF;
  END LOOP;
END $$;

-- New objects must receive explicit least-privilege grants in their migrations.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL ON TABLES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL ON SEQUENCES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL ON FUNCTIONS FROM anon, authenticated;
