# Relatório de Estado e Próximos Passos — MG Motors

**Data:** Agosto de 2026  
**Escopo:** Projeto `mgmotors_output` — site estático multi-página com Supabase como backend, sem bundler, imports via CDN esm.sh.  
**Tamanho atual do projeto:** ~8.3 MB (após remoção de PNGs órfãos; era ~19 MB antes das otimizações desta sessão)

---

## ✅ O Que Já Foi Feito (Esta Sessão)

| Área | Ação |
|------|------|
| SEO | Meta description + Open Graph em 10 páginas |
| Títulos | Subtítulos descritivos em todas as páginas |
| Supabase | Versão `@2.45.4` fixada em todos os 19 HTMLs + 8 blogs |
| Performance | `loading="lazy"` nos cards de anúncios e fotos de perfil |
| Deploy | `vercel.json` com cache de 1 ano para imagens + 3 headers de segurança |
| Limpeza | 8 PNGs órfãos removidos (economia de ~2 MB) |
| Limpeza | `MG-CONTA_conta.html.check.mjs` e `MG-DEV_devpanel.html.check.mjs` deletados |

---

## 🔴 Prioridade Alta (Impacto direto em funcionamento / segurança)

### 1. Link quebrado: "Central de Ajuda" aponta para página inexistente
**Afeta:** `marketplace.html`, `configuracoes.html`, `como-utilizar.html`  
**Problema:** Os três arquivos têm `<a href="../MG-AJUDA/ajuda.html">Central de Ajuda</a>`, mas a pasta `MG-AJUDA/` não existe no projeto.  
**Ação recomendada:** Criar a página `MG-AJUDA/ajuda.html` com conteúdo de FAQ e central de suporte, **ou** redirecionar esses links para `MG-CASOS-USO/como-utilizar.html` que já cumpre esse papel.

---

### 2. Imagens de blog ainda não otimizadas (PNGs e JPEGs pesados)
**Problema:** A pasta `MG-DICAS/blogs/` ainda contém imagens sem versão `.webp`. O maior arquivo é `mclaren_720s.png` (1.35 MB). Total estimado de imagens não-webp nos blogs: ~6–8 MB.  
**Ação recomendada:** Converter todas as imagens de blog para `.webp` usando uma ferramenta local (como [Squoosh CLI](https://github.com/GoogleChromeLabs/squoosh/tree/dev/cli) ou [cwebp](https://developers.google.com/speed/webp/docs/cwebp)):
```bash
# Exemplo com cwebp
cwebp mclaren_720s.png -o mclaren_720s.webp -q 80
```
Depois atualizar as referências nos HTMLs de cada blog.

---

### 3. Auditoria de `escapeHtml()` nos pontos novos de `innerHTML`
**Problema:** O marketplace, conta e mensagens injetam dados do banco via `innerHTML` em templates literais. O código do marketplace já usa `textContent` corretamente para campos de texto livre (`h3`, `alt`), mas vale confirmar se todos os campos de usuário (legenda de post, descrição de veículo no modal de visualização, nomes de usuários em avaliações) passam por `escapeHtml()` antes de entrar no DOM.  
**Ação recomendada:** Revisar especificamente:
- `viz-descricao` em `marketplace.html` (descrição do veículo)
- Campos de avaliação em `conta.html`
- Conteúdo das mensagens de chat em `mensagens.html`

---

### 4. Favicon ausente em todas as páginas
**Problema:** Nenhuma página tem `<link rel="icon">`, então o browser usa o ícone padrão. Em mobile (PWA-like), não há `apple-touch-icon` ou `manifest.webmanifest`.  
**Ação recomendada:** Gerar um favicon a partir do `logo.webp` e adicionar:
```html
<link rel="icon" href="/imagens/logo.webp" type="image/webp">
<link rel="apple-touch-icon" href="/imagens/logo.webp">
```

---

## 🟡 Prioridade Média (UX e qualidade)

### 5. URL canônica ausente
**Problema:** Nenhuma página tem `<link rel="canonical">`. Para um site estático, isso não é crítico, mas pode causar problemas de duplicate content se o site for acessível via `www` e sem `www`, ou via HTTP e HTTPS ao mesmo tempo.  
**Ação recomendada:** Adicionar em cada página:
```html
<link rel="canonical" href="https://seudominio.com/MG-INICIO/inicio.html">
```

---

### 6. Sem paginação no marketplace — carrega todos os anúncios de uma vez
**Problema:** O marketplace faz um único `SELECT *` e renderiza todos os cards em memória. Com poucos anúncios funciona bem, mas à medida que a base crescer, a experiência vai degradar (DOM pesado, chamada lenta).  
**Ação recomendada:** Implementar paginação por offset ou cursor:
```js
// Exemplo: carregar 20 por vez com .range()
const { data } = await supabase
  .from('anuncios')
  .select('...')
  .range(pagina * 20, pagina * 20 + 19);
```
Adicionar botão "Carregar mais" ou scroll infinito.

---

### 7. Sem feedback visual de carregamento nas páginas de blog
**Problema:** As páginas de blog individuais (`astonmartin.html`, `bmw.html`, etc.) carregam imagens sem skeleton loader ou placeholder de baixa resolução (LQIP). Em conexões lentas, o usuário vê espaços em branco.  
**Ação recomendada:** Adicionar `aspect-ratio` e `background-color` como placeholder via CSS nas imagens, e usar `loading="lazy"` em todas (verificar se já estão definidos nos blogs).

---

### 8. Formulário de anúncio não valida tamanho de arquivo no front
**Problema:** O modal de publicar anúncio aceita upload de até 5 fotos, mas a hint diz "Máx. 5MB por foto" sem validação JS. Se o usuário enviar um arquivo maior, o erro só aparece na hora do upload no Supabase Storage.  
**Ação recomendada:**
```js
// Antes de fazer upload
if (file.size > 5 * 1024 * 1024) {
  alert('Arquivo muito grande. Máximo: 5MB.');
  return;
}
```

---

### 9. Página de configurações sem confirmação ao sair com mudanças não salvas
**Problema:** O formulário de configurações em `configuracoes.html` não avisa o usuário se ele sair da página com alterações não salvas.  
**Ação recomendada:** Usar o evento `beforeunload`:
```js
let mudou = false;
form.addEventListener('change', () => mudou = true);
window.addEventListener('beforeunload', e => {
  if (mudou) e.preventDefault();
});
```

---

### 10. WhatsApp no anúncio não valida formato do número
**Problema:** O campo de WhatsApp no formulário de anúncio é `type="text"` sem máscara ou validação regex. Números inválidos podem ser salvos no banco e gerar links quebrados.  
**Ação recomendada:** Validar o formato antes do submit:
```js
const wpp = document.getElementById('car-whatsapp').value.replace(/\D/g,'');
if (!/^\d{10,11}$/.test(wpp)) { /* mostrar erro */ return; }
```

---

## 🟢 Prioridade Baixa (Polimento e manutenção)

### 11. Confirmar RLS no Supabase — auditoria de tabelas sem segurança ativada
**Ação:** Rodar no SQL Editor do Supabase:
```sql
SELECT tablename FROM pg_tables
WHERE schemaname = 'public' AND rowsecurity = FALSE;
```
Qualquer tabela listada deve ser avaliada para habilitar RLS.

---

### 12. `index.html` da raiz tem redirect duplo
**Situação:** O arquivo redireciona via `<meta http-equiv="refresh">` **e** via `window.location.replace`. Redundante mas inofensivo.  
**Ação:** Simplificar deixando apenas o JS.

---

### 13. Adicionar `robots.txt` e `sitemap.xml`
**Problema:** Sem esses arquivos, o Googlebot não sabe quais páginas indexar nem em que frequência.  
**Ação recomendada:**

`robots.txt` (raiz):
```
User-agent: *
Allow: /
Sitemap: https://seudominio.com/sitemap.xml
```

`sitemap.xml` (raiz) listando as URLs públicas (inicio, marketplace, dicas, blogs, contato, como-utilizar).

---

### 14. Adicionar `lang` correto nos blogs individuais
**Verificar:** Se os arquivos de blog herdam `lang="pt-BR"` ou estão sem o atributo. O atributo `lang` correto no `<html>` melhora acessibilidade (leitores de tela) e SEO.

---

### 15. Cooldown/debounce visual no botão de login
**Situação:** O backend do Supabase Auth já faz rate limiting, mas o botão de login não desabilita visualmente após tentativas falhas, deixando o usuário confuso.  
**Ação:** Adicionar cooldown de 5–10s no botão após erro de autenticação.

---

## 📊 Resumo de Prioridades

| # | Item | Prioridade | Esforço estimado |
|---|------|:----------:|:---------------:|
| 1 | Link "Central de Ajuda" quebrado | 🔴 Alta | 2h |
| 2 | Converter imagens de blog para webp | 🔴 Alta | 1–2h |
| 3 | Auditoria `escapeHtml()` em innerHTML | 🔴 Alta | 1h |
| 4 | Favicon em todas as páginas | 🔴 Alta | 30min |
| 5 | `<link rel="canonical">` | 🟡 Média | 30min |
| 6 | Paginação no marketplace | 🟡 Média | 3–5h |
| 7 | Skeleton loader nos blogs | 🟡 Média | 1h |
| 8 | Validar tamanho de arquivo no front | 🟡 Média | 30min |
| 9 | `beforeunload` em configurações | 🟡 Média | 30min |
| 10 | Validar formato do WhatsApp | 🟡 Média | 30min |
| 11 | Auditoria RLS no Supabase | 🟢 Baixa | 30min |
| 12 | Simplificar `index.html` | 🟢 Baixa | 10min |
| 13 | `robots.txt` + `sitemap.xml` | 🟢 Baixa | 30min |
| 14 | `lang` nos blogs | 🟢 Baixa | 15min |
| 15 | Cooldown no botão de login | 🟢 Baixa | 20min |

---

## 🏗️ Sugestões Futuras (Médio/Longo Prazo)

- **Página de anúncio individual com URL própria** (ex: `/anuncio/123`) — hoje o anúncio abre em modal, o que impede compartilhamento direto e indexação do Google.
- **Notificações em tempo real** — usar o Supabase Realtime para avisar quando o usuário recebe uma nova mensagem, sem precisar recarregar a página de mensagens.
- **Upload de imagens com compressão no front** — usar a [Canvas API](https://developer.mozilla.org/en-US/docs/Web/API/Canvas_API) ou biblioteca como `browser-image-compression` para reduzir o tamanho antes do upload ao Supabase Storage, melhorando performance e reduzindo custo de armazenamento.
- **Pesquisa com full-text search** — habilitar `pg_trgm` ou `to_tsvector` no Supabase para busca por modelo, descrição e cor com relevância, em vez de `ILIKE`.
- **Migração para bundler (Vite)** — à medida que o projeto crescer, um bundler permitirá tree-shaking, importações limpas, TypeScript e testes automatizados.
