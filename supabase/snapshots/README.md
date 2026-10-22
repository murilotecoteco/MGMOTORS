# Snapshots do banco de produção

## `schema_producao_20261020.sql`

Dump gerado com `supabase db dump --linked --schema public --schema storage` a partir
do projeto Supabase `ilswwmjojfuvcgyymymb` em **20/10/2026**.

**Não é uma migration.** É uma referência de leitura, usada para verificar se as
migrations versionadas em `../migrations/` refletem fielmente o banco de produção.

### Como foi verificado

Comparação automática entre o dump e as duas migrations do repositório
(`20260915145500_remote_schema.sql` + `20261008000000_legal_consent.sql`):

| Verificação | Resultado |
|---|---|
| Policies em produção | 143 |
| Policies no repositório | 144 |
| Só em produção | 1 — `carrinho_itens.usuarios gerenciam seus carrinhos` (criada em runtime pela função `criar_tabela_carrinho()`) |
| Só no repositório | 3 — `Sistema cria usuarios`, `Todos veem usuarios`, `usuarios select publico` (as três são removidas corretamente pela migration de consentimento legal) |
| Divergências de conteúdo | 8 — **apenas a ordem dos papéis** em `TO anon, authenticated` vs `TO authenticated, anon`. Semanticamente idênticas |
| Triggers | 18 em produção / 17 no repositório (a 18ª é `protect_bucket_control_insert`, do schema `storage`) |

**Conclusão:** as migrations do repositório reproduzem fielmente o banco de produção.
Não há policy, trigger ou função órfã em produção que esteja ausente no repositório.

### O que o dump expõe (e precisa ser corrigido)

Verificação feita sobre o dump de produção:

| Objeto | Problema confirmado no dump |
|---|---|
| `public.usuarios` | **Sem FK para `auth.users.id`** — só tem `usuarios_pkey`. É a causa estrutural da escalação de privilégio: apagar o perfil não derruba a conta Auth, e reinserir com o mesmo `id` funciona |
| `usuarios` | **Nenhum trigger `BEFORE INSERT`** — só `BEFORE UPDATE`. `moderador` e `is_admin` passam intactos na criação da linha |
| `storage.objects` | **28 policies**, e nenhuma verifica o dono do caminho. Todas as mutantes checam apenas `bucket_id` + `auth.role() = 'authenticated'` |
| `criar_tabela_carrinho()` | `SECURITY DEFINER` **sem `search_path`**, com `GRANT` para `anon` — DDL executável por anônimo |
| `promover_moderador()` | `GRANT` para `anon`; o guard `auth.uid() IS NOT NULL` não bloqueia anônimo (`auth.uid()` é `NULL`) |
| `get_anuncios_marketplace()`, `incrementar_curtidas()`, `decrementar_curtidas()`, `atualizar_contador_seguidores()` | `SECURITY DEFINER` **sem `search_path`** |

### Reproduzir

```bash
supabase login
supabase db dump --linked --schema public --schema storage -f /tmp/schema_prod.sql
```

### Teste de segurança

O roteiro automatizado fica em `../tests/rls-security-check.sh`:

```bash
export SUPABASE_URL="https://SEU-PROJETO.supabase.co"
export SUPABASE_ANON_KEY="sb_publishable_..."
bash supabase/tests/rls-security-check.sh
```

Estado em 20/10/2026: **17 PASS / 4 FAIL**. A meta é **21 PASS / 0 FAIL** após a
migration de hardening.
