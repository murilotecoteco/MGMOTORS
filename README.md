# MG Motors

<p align="center">
  Marketplace premium de compra e venda de veículos exclusivos — esportivos, seminovos e importados.
</p>

<p align="center">

![Status](https://img.shields.io/badge/status-active-brightgreen)
![Deploy](https://img.shields.io/badge/deploy-vercel-black)

</p>

<p align="center">

![HTML5](https://img.shields.io/badge/HTML5-E34F26?style=for-the-badge&logo=html5&logoColor=white)
![CSS3](https://img.shields.io/badge/CSS3-1572B6?style=for-the-badge&logo=css3&logoColor=white)
![JavaScript](https://img.shields.io/badge/JavaScript-F7DF1E?style=for-the-badge&logo=javascript&logoColor=black)
![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)
![Vercel](https://img.shields.io/badge/Vercel-000000?style=for-the-badge&logo=vercel&logoColor=white)
![Lucide](https://img.shields.io/badge/Lucide_Icons-f56565?style=for-the-badge&logoColor=white)
![Git](https://img.shields.io/badge/Git-F05032?style=for-the-badge&logo=git&logoColor=white)

</p>

<p align="center">

<a href="https://mgmotors.vercel.app/MG-INICIO/inicio.html">
<img src="https://img.shields.io/badge/Live-Demo-blue?style=for-the-badge">
</a>

<a href="https://github.com/murilotecoteco/MGMOTORS">
<img src="https://img.shields.io/badge/GitHub-Repository-black?style=for-the-badge">
</a>

</p>

---

# Sumário

- [Sobre](#sobre)
- [Funcionalidades](#funcionalidades)
- [Páginas do Site](#páginas-do-site)
- [Stack de Tecnologias](#stack-de-tecnologias)
- [Arquitetura](#arquitetura)
- [Estrutura do Projeto](#estrutura-do-projeto)
- [Banco de Dados](#banco-de-dados)
- [Segurança](#segurança)
- [Deploy](#deploy)
- [Como Rodar Localmente](#como-rodar-localmente)
- [Roadmap](#roadmap)

---

# Sobre

**MG Motors** é um marketplace web premium focado na compra e venda de veículos exclusivos no Brasil. A plataforma conecta compradores e vendedores de carros esportivos, seminovos e importados em um ambiente seguro, moderno e sem burocracia.

O projeto foi construído inteiramente com **HTML, CSS e JavaScript puro** (sem frameworks de frontend), utilizando o **Supabase** como backend completo — autenticação, banco de dados PostgreSQL, storage e Row Level Security (RLS).

---

# Funcionalidades

- Marketplace com listagem e busca de anúncios de veículos
- Filtros avançados: marca, modelo, preço, categoria e localização (geolocalização)
- Ordenação: mais curtidos, menor preço, maior preço, mais recentes
- Publicação e gerenciamento de anúncios com upload de múltiplas fotos
- Sistema de curtidas nos anúncios
- Favoritos salvos localmente (localStorage)
- Chat interno em tempo real entre comprador e vendedor
- Envio de fotos no chat
- Perfil de usuário com bio, foto, capa, redes sociais e anúncios
- Feed de fotos estilo galeria no perfil
- Sistema de seguir/seguidores entre usuários
- Avaliação de usuários com estrelas e comentário
- Autenticação completa: cadastro, login e recuperação de senha
- Configurações da conta: tema escuro/claro, tamanho de fonte, notificações e privacidade
- Sistema de denúncias de anúncios, mensagens e perfis
- Painel administrativo (Dev Panel) com moderação de anúncios, denúncias e usuários
- Banimento e desbanimento de usuários
- Central de Ajuda com perguntas frequentes (FAQ)
- Blog com dicas de compra/venda segura e artigos sobre marcas de luxo
- Chatbot de atendimento integrado (Chatling)
- Tema escuro e claro com persistência
- Design responsivo para mobile e desktop
- Estatísticas animadas em tempo real (total de anúncios, marcas, usuários)
- Microanimações e revelação de elementos ao rolar a página
- SEO otimizado com meta tags, Open Graph e canonical URLs
- Segurança com headers HTTP via Vercel (DENY iframes, nosniff, referrer policy)

---

# Páginas do Site

| Página | Rota | Descrição |
|--------|------|-----------|
| **Início** | `/MG-INICIO/inicio.html` | Landing page com hero, busca, veículos em destaque, categorias, diferenciais e depoimentos |
| **Marketplace** | `/MG-MARKETPLACE/marketplace.html` | Listagem completa de anúncios com filtros, busca, modal de detalhes e publicação de anúncio |
| **Mensagens** | `/MG-MENSAGENS/mensagens.html` | Chat em tempo real com lista de conversas, envio de texto e fotos |
| **Perfil / Conta** | `/MG-CONTA/conta.html` | Perfil público do usuário com anúncios, galeria de fotos, seguidores, seguindo e avaliações |
| **Dicas** | `/MG-DICAS/dicas.html` | Guia completo de compra e venda segura: golpes comuns, documentação, inspeção mecânica e negociação |
| **Central de Ajuda** | `/MG-AJUDA/ajuda.html` | FAQ com acordeão por categoria (anúncios, pagamentos, conta, segurança) |
| **Contato** | `/MG-CONTATO/contato.html` | Página de contato com atendimento via WhatsApp e chatbot |
| **Como Utilizar** | `/MG-CASOS-USO/como-utilizar.html` | Documentação dos casos de uso da plataforma (UC01–UC15) |
| **Configurações** | `/MG-CONFIGURACOES/configuracoes.html` | Preferências de aparência, notificações, privacidade e conta |
| **Login** | `/MG-LOGIN/login.html` | Autenticação com email e senha via Supabase Auth |
| **Cadastro** | `/MG-LOGIN/register.html` | Criação de conta com nome, email e senha |
| **Dev Panel** | `/MG-DEV/devpanel.html` | Painel restrito para desenvolvedores: métricas, moderação de anúncios, denúncias e gestão de usuários |

### Blog — Artigos sobre Marcas de Luxo

| Artigo | Rota |
|--------|------|
| Aston Martin | `/MG-DICAS/blogs/astonmartin/astonmartin.html` |
| BMW | `/MG-DICAS/blogs/bmw/bmw.html` |
| Bugatti | `/MG-DICAS/blogs/bugatti/bugatti.html` |
| Ferrari | `/MG-DICAS/blogs/ferrari/ferrari.html` |
| Lamborghini | `/MG-DICAS/blogs/lamborghini/lamborghini.html` |
| McLaren | `/MG-DICAS/blogs/mclaren/mclaren.html` |
| Pagani | `/MG-DICAS/blogs/pagani/pagani.html` |
| Porsche | `/MG-DICAS/blogs/porsche/porsche.html` |

---

# Stack de Tecnologias

| Camada | Tecnologia |
|--------|------------|
| Frontend | HTML5, CSS3 Vanilla, JavaScript ES2022 (módulos) |
| Ícones | Lucide Icons (via CDN) |
| Backend / Auth | Supabase (PostgreSQL + Auth + Storage) |
| Banco de Dados | PostgreSQL (gerenciado pelo Supabase) |
| Deploy | Vercel |
| Chatbot | Chatling AI |
| Tipografia | Inter, Segoe UI (system fonts) |
| Versionamento | Git & GitHub |

---

# Arquitetura

```
Navegador do Usuário
        |
        v
  HTML + CSS + JS
  (sem framework)
        |
   +----+----+
   |         |
   v         v
Supabase    localStorage
   |         |
 +-+------+  +-- Favoritos
 |        |
 v        v
Auth    PostgreSQL
(JWT)   (anuncios, usuarios,
         mensagens, denuncias,
         marcas, modelos,
         fotos_anuncio, etc.)
```

Toda a lógica de backend é gerenciada pelo **Supabase**:
- **Auth**: autenticação JWT com email/senha
- **Database**: queries diretas ao PostgreSQL usando a client lib `@supabase/supabase-js`
- **RLS (Row Level Security)**: políticas no banco garantem que cada usuário só acessa e modifica seus próprios dados
- **Storage**: upload de fotos de perfil, capa e anúncios

O frontend é servido como **HTML estático** pelo Vercel, sem necessidade de servidor de aplicação.

---

# Estrutura do Projeto

```
MGMOTORS/
|
+-- MG-INICIO/
|   +-- inicio.html          # Landing page
|   +-- inicio.css
|
+-- MG-MARKETPLACE/
|   +-- marketplace.html     # Listagem + publicação de anúncios
|   +-- marketplace.css
|
+-- MG-MENSAGENS/
|   +-- mensagens.html       # Chat em tempo real
|   +-- mensagens.css
|
+-- MG-CONTA/
|   +-- conta.html           # Perfil do usuário
|   +-- conta.css
|
+-- MG-LOGIN/
|   +-- login.html           # Autenticação
|   +-- login.css
|   +-- register.html        # Cadastro
|   +-- register.css
|
+-- MG-CONFIGURACOES/
|   +-- configuracoes.html   # Preferências do usuário
|   +-- configuracoes.css
|
+-- MG-DICAS/
|   +-- dicas.html           # Guia de segurança
|   +-- dicas.css
|   +-- blogs/               # Artigos sobre marcas
|       +-- astonmartin/
|       +-- bmw/
|       +-- bugatti/
|       +-- ferrari/
|       +-- lamborghini/
|       +-- mclaren/
|       +-- pagani/
|       +-- porsche/
|
+-- MG-AJUDA/
|   +-- ajuda.html           # FAQ / Central de ajuda
|
+-- MG-CONTATO/
|   +-- contato.html         # Página de contato
|   +-- contato.css
|
+-- MG-CASOS-USO/
|   +-- como-utilizar.html   # Casos de uso documentados
|   +-- como-utilizar.css
|
+-- MG-DEV/
|   +-- devpanel.html        # Painel admin (restrito)
|   +-- devpanel.css
|
+-- imagens/                 # Assets estáticos
+-- global.css               # Estilos globais + header + toast
+-- headerGlobal.js          # Header injetado dinamicamente em todas as páginas
+-- mgConfig.js              # Configuração central do Supabase + escapeHtml()
+-- tema.js                  # Tema escuro/claro aplicado antes do render
+-- vercel.json              # Headers de segurança HTTP
+-- supabase-rls-setup.sql   # Setup completo do banco + políticas RLS
+-- index.html               # Redirect para MG-INICIO
```

---

# Banco de Dados

O schema completo com políticas de RLS está em [`supabase-rls-setup.sql`](./supabase-rls-setup.sql).

### Tabelas principais

| Tabela | Descrição |
|--------|-----------|
| `usuarios` | Perfil estendido: nome, bio, foto, capa, cidade, UF, instagram, nota_media, seguidores, seguindo, banido |
| `anuncios` | Anúncios de veículos: marca, modelo, ano, preço, quilometragem, categoria, cidade, UF, status, curtidas |
| `marcas` | Marcas de veículos cadastradas |
| `modelos` | Modelos vinculados a marcas |
| `fotos_anuncio` | Fotos dos anúncios (múltiplas por anúncio, com ordem) |
| `mensagens` | Mensagens do chat: conteúdo, tipo (texto/foto), lida, timestamps |
| `denuncias` | Denúncias de anúncios, mensagens ou perfis: motivo, status, alvo, denunciante |
| `avaliacoes` | Avaliações entre usuários: nota (1 a 5) e comentário |
| `seguidores` | Relação seguidor para seguido |
| `curtidas` | Curtidas de usuários em anúncios |
| `posts` | Fotos do feed do perfil do usuário |
| `usuarios_banidos` | Registro de banimentos com motivo e responsável |

---

# Segurança

- **Row Level Security (RLS)** ativado em todas as tabelas — usuários só leem e alteram os próprios dados
- **Escape de HTML** (`escapeHtml()` em `mgConfig.js`) aplicado em toda interpolação de dados do usuário em `innerHTML`, prevenindo XSS
- **Construção via DOM API** nas telas críticas (chat, perfil): dados do usuário são inseridos via `textContent` e `dataset`, nunca via `innerHTML` direto
- **Validação de URLs** no campo "Site" do perfil: aceita apenas `http:` e `https:`, bloqueando `javascript:` e outros esquemas perigosos
- **Validação de username** do Instagram via regex antes de gerar links
- **Headers HTTP de segurança** configurados no `vercel.json`:
  - `X-Frame-Options: DENY` — impede clickjacking
  - `X-Content-Type-Options: nosniff`
  - `Referrer-Policy: strict-origin-when-cross-origin`
- **Cache imutável** para assets de imagem (`Cache-Control: public, max-age=31536000, immutable`)
- **Verificação de banimento** no login: usuários banidos são bloqueados imediatamente
- **Dev Panel** restrito por verificação de email de desenvolvedor

---

# Deploy

O projeto é hospedado no **Vercel** como site estático.

Todo push para o branch `main` aciona automaticamente um novo deploy de produção.

URL de produção:

```
https://mgmotors.vercel.app
```

---

# Como Rodar Localmente

Como o projeto é 100% HTML/CSS/JS estático, basta abrir os arquivos num servidor local. Recomendamos a extensão **Live Server** do VS Code ou o `serve` do Node.js.

### Com Node.js

```bash
# Instale o serve globalmente (apenas uma vez)
npm install -g serve

# Clone o repositório
git clone https://github.com/murilotecoteco/MGMOTORS.git
cd MGMOTORS

# Suba o servidor
serve .
```

O site ficará disponível em:

```
http://localhost:3000/MG-INICIO/inicio.html
```

### Com VS Code Live Server

1. Instale a extensão **Live Server** (Ritwick Dey)
2. Clique com o botão direito em `MG-INICIO/inicio.html`
3. Selecione **"Open with Live Server"**

> **Atenção:** As funcionalidades que dependem do Supabase (autenticação, anúncios, chat etc.) requerem conexão com a internet, pois apontam para o projeto Supabase em produção.

---

# Roadmap

- [x] Marketplace com filtros avançados e geolocalização
- [x] Autenticação com Supabase Auth
- [x] Publicação e gestão de anúncios com fotos
- [x] Chat em tempo real com envio de fotos
- [x] Perfil de usuário com galeria, seguidores e avaliações
- [x] Sistema de denúncias e moderação
- [x] Painel administrativo (Dev Panel)
- [x] Tema escuro/claro
- [x] Central de Ajuda e blog de dicas
- [x] Headers de segurança HTTP
- [x] Row Level Security no banco de dados
- [x] Design responsivo
- [ ] Simulador de financiamento integrado
- [ ] Notificações push em tempo real
- [ ] Comparador de veículos
- [ ] Exportação de anúncios em PDF
- [ ] Verificação de identidade de vendedores

---

# Licença

Este projeto foi desenvolvido para fins educacionais e de portfólio.

Nenhuma licença foi aplicada.
