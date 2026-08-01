# Relatório de Melhorias — MG Motors

**Escopo:** revisão do projeto `mgmotors-finalizado` (site estático multi-página com Supabase como backend, sem bundler, imports via CDN esm.sh).

**Status geral:** projeto bem estruturado. Já existem 4 rodadas de melhorias de robustez aplicadas anteriormente (documentadas em `MELHORIAS-ROBUSTEZ.md`): uso de `.maybeSingle()` em leituras onde "0 linhas" é normal, tratamento de erro em toda ação de escrita via helper `executarOuAvisar()`, campo Estado (UF) como `<select>` validado, e revisão de fallbacks perigosos em inserts. A segurança de administrador também já está correta: a checagem real fica nas RLS policies do Supabase via função `is_admin()`, não em lista de e-mails no front-end.

As pendências abaixo são de polimento (SEO, performance, headers, manutenção), não bugs críticos.

---

## 1. Segurança

| Item | Situação | Ação recomendada |
|---|---|---|
| Chave do Supabase em `mgConfig.js` | É a chave `sb_publishable_...` (anon), não é segredo — ok manter no front | Confirmar que **todas** as tabelas sensíveis têm RLS ativado, não só as principais. Rodar no SQL editor do Supabase: `select * from pg_tables where schemaname='public' and rowsecurity=false;` |
| `escapeHtml()` (definida em `mgConfig.js`) | Usada em vários pontos já revisados | Auditar se **todo** `innerHTML` que injeta dado vindo do banco (legenda de post, nome de usuário, motivo de denúncia, mensagens do chat) passa por `escapeHtml()`. É o ponto mais fácil de esquecer ao criar um card novo. |
| Login por senha | Sem rate limit visível no front (Supabase Auth já limita no backend) | Adicionar cooldown/debounce visual no botão de login após tentativas falhas, para melhor UX e reduzir tentativas automatizadas. |
| Versão do `@supabase/supabase-js` via esm.sh | Import sem versão fixa (`https://esm.sh/@supabase/supabase-js`) | Fixar versão explícita, ex: `https://esm.sh/@supabase/supabase-js@2.45.4`, para evitar quebra silenciosa se o CDN servir uma major nova. |

---

## 2. Performance

- **Imagens duplicadas em `imagens/`**: cada marca tem `.png` (grande) e `.webp` (pequeno) lado a lado, ex: `bmw.png` (200K) vs `bmw.webp` (28K). Nas referências revisadas no código (`inicio.html`, `headerGlobal.js`, `marketplace.html`, `conta.html`, `mensagens.html`, `devpanel.html`) só aparecem os `.webp`. Se os `.png` não forem usados como fallback em `<picture>`, são órfãos — remover reduz peso do deploy.
- **`loading="lazy"`**: encontrado em apenas 4 ocorrências em todo o site. Aplicar em:
  - Cards de anúncio no marketplace (`MG-MARKETPLACE/marketplace.html`)
  - Fotos dos posts de blog (`MG-DICAS/blogs/*`, que sozinha soma **7.8MB** dos 19MB totais do projeto)
  - Avatares/fotos de perfil em conta, mensagens e header
  - Manter `loading="eager"` apenas na imagem hero acima da dobra (já está correto em `inicio.html`).
- **Imagens de blog não otimizadas**: pasta `MG-DICAS/blogs/` tem imagens em `.jpg`/`.jpeg`/`.png` misturadas com `.webp` (ex: `mclaren/mclaren-img/maclaren_p1.jpeg`, `porsche/porsche-img/Ferdinand_Porsche.jpg`). Converter as que ainda não são `.webp`.

---

## 3. SEO

- Todas as páginas revisadas (`inicio.html`, `marketplace.html`, `dicas.html`) têm apenas `<title>`, **sem** `<meta name="description">` e **sem** Open Graph (`og:title`, `og:description`, `og:image`). Isso afeta compartilhamento em redes sociais e indexação no Google.
- Ação: adicionar em cada página, dentro do `<head>`:
  ```html
  <meta name="description" content="[descrição específica da página, 120-160 caracteres]">
  <meta property="og:title" content="[título]">
  <meta property="og:description" content="[descrição]">
  <meta property="og:image" content="[url de imagem representativa]">
  <meta property="og:type" content="website">
  ```

---

## 4. Configuração de deploy (`vercel.json`)

Atual:
```json
{
  "rewrites": [
    { "source": "/(.*)", "destination": "/$1" }
  ]
}
```
Esse rewrite é essencialmente um no-op. Sugestão de melhoria — adicionar headers de cache para estáticos e headers básicos de segurança:
```json
{
  "headers": [
    {
      "source": "/imagens/(.*)",
      "headers": [
        { "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }
      ]
    },
    {
      "source": "/(.*)",
      "headers": [
        { "key": "X-Content-Type-Options", "value": "nosniff" },
        { "key": "X-Frame-Options", "value": "DENY" },
        { "key": "Referrer-Policy", "value": "strict-origin-when-cross-origin" }
      ]
    }
  ]
}
```

---

## 5. Acessibilidade

- Pontos fortes já presentes: `aria-label`, `aria-expanded` no menu mobile (`headerGlobal.js`), `aria-live="polite"` no feedback de formulários (`login.html`, `register.html`).
- Verificar: o toggle de tema claro/escuro (`tema.js` aplica o tema salvo, mas não localizei o botão de troca no header global revisado) — se existir em outra página, garantir `aria-pressed` refletindo o estado atual.

---

## 6. Arquitetura / manutenção

- **Sem `package.json`/bundler**: tudo via CDN esm.sh. Funciona bem para um projeto deste porte, mas reforça a necessidade de fixar versões (ver item de Segurança).
- **Arquivos `.check.mjs` na raiz do output** (`MG-DEV_devpanel.html.check.mjs`, `MG-CONTA_conta.html.check.mjs`): parecem scripts de verificação de uma sessão de revisão anterior, extraídos do JS inline dessas páginas. Se não fazem parte do site em produção, remover do pacote final de deploy evita confusão e exposição desnecessária de lógica interna (mesmo que não seja sensível).
- **`index.html` da raiz**: faz redirect duplo (`<meta http-equiv="refresh">` + `window.location.replace`). Redundante, mas inofensivo — pode simplificar deixando só o JS.

---

## Resumo de prioridade sugerida

1. **SEO** (meta description + Open Graph) — baixo esforço, alto impacto em compartilhamento/indexação.
2. **Performance de imagens** (lazy loading + remover PNGs órfãos + converter blog para webp) — reduz o peso de 19MB significativamente.
3. **`vercel.json`** (cache + headers de segurança) — baixo esforço.
4. **Fixar versão do supabase-js** — previne quebra silenciosa futura.
5. **Auditoria de `escapeHtml()`** em pontos novos de `innerHTML`.
6. **Limpeza dos arquivos `.check.mjs`** antes do deploy final.
