# Navbar publicada — teste responsivo

- Data: 2026-11-13
- Ambiente: produção pública, `https://mgmotorss.vercel.app/MG-INICIO/inicio.html`
- Navegador: Chromium 157.0.8103.38 (Arch Linux)
- Método: abertura da página pública, acionamento do menu quando o botão estava
  visível e medição do `scrollWidth` em relação à largura do viewport.

| Viewport | Menu | Resultado |
|---|---|---|
| 1920×1080 | Menu horizontal, sem botão | PASS — sem rolagem horizontal; cabeçalho com 76 px. |
| 1366×768 | Menu horizontal, sem botão | PASS — sem rolagem horizontal; cabeçalho com 76 px. |
| 768×1024 | Botão acionado; `aria-expanded=true` | PASS — navegação aberta, sem rolagem horizontal; cabeçalho com 383 px. |
| 390×844 | Botão acionado; `aria-expanded=true` | PASS — navegação aberta, sem rolagem horizontal; cabeçalho com 385 px. |

Os dados estruturados estão em `navbar-publicado-20261113.json`; as capturas
correspondentes são `navbar-publicado-20261113-{largura}x{altura}.png`.

Esse resultado confirma a responsividade técnica do cabeçalho publicado nas
quatro resoluções observadas. Não mede compreensão, acessibilidade assistiva ou
satisfação de usuários; esses pontos requerem avaliação específica.
