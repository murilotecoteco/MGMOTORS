# Implantação segura das migrations

## Regra principal

`20260915145500_remote_schema.sql` é o schema-base exportado do projeto. Ele não deve ser reaplicado em um banco remoto que já possui as tabelas da MGMOTORS. Antes de usar `supabase db push`, confira o histórico:

```bash
supabase link --project-ref SEU_PROJECT_REF
supabase migration list
```

Se o schema-base já existir no remoto, mas aparecer como pendente, pare e confirme a equivalência do schema antes de registrar a migration como aplicada. Não use `db reset` em produção.

## Migrations incrementais

Depois de confirmar o schema-base, a ordem é:

1. `20261008000000_legal_consent.sql`
2. `20261020120000_security_hardening.sql`
3. `20261022160000_notifications_rf14.sql`

As três possuem pré-condições e rodam dentro da transação de migration. Se o schema for incompatível, devem abortar antes de concluir alterações.

## Antes de produção

- fazer backup/export do banco;
- aplicar em um projeto de staging;
- rodar `supabase/tests/verificar-hardening.sql` no SQL Editor (somente leitura; pode rodar em produção) e guardar a saída em `evidencias/`;
- executar `supabase/tests/rls-security-check.sh` com usuário de teste descartável;
- validar login, publicação, fotos, mensagens, moderação e notificações;
- somente então executar `supabase db push` em produção.

O arquivo antigo `MIGRAR_CATEGORIAS.sql` em Downloads não faz parte do fluxo: ele contém valores incompatíveis (`barco`/`jetski`) e uma alteração administrativa por e-mail fixo.
