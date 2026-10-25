-- Remove uma concessão direta legada que não era apagada por REVOKE FROM PUBLIC.
-- O aceite legal só pode ser registrado pela própria sessão autenticada.
REVOKE ALL ON FUNCTION public.registrar_aceite_legal(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.registrar_aceite_legal(text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.registrar_aceite_legal(text, text) TO authenticated;

DO $$
BEGIN
  IF has_function_privilege(
    'anon',
    'public.registrar_aceite_legal(text, text)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'hardening falhou: anon ainda pode executar registrar_aceite_legal';
  END IF;
END
$$;
