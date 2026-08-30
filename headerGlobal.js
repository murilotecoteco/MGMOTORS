// arquivo: headerGlobal.js

/**
 * Injeta o header global, marca a pagina ativa e sincroniza a area de
 * login/perfil com a sessao atual do Supabase.
 *
 * @param {import('@supabase/supabase-js').SupabaseClient} supabase Instancia ja inicializada do cliente Supabase.
 * @returns {Promise<object|null>} O objeto `user` do Supabase se houver sessao ativa, ou `null` caso contrario.
 */
export async function carregarHeaderGlobal(supabase) {
  const headerContainer = document.getElementById("header-global");
  if (!headerContainer) {
    console.warn("Container '#header-global' nao encontrado na pagina.");
    return null;
  }

  headerContainer.innerHTML = `
    <div class="logo">
      <a href="../MG-INICIO/inicio.html" class="logo-link" aria-label="Ir para o inicio da MG Motors">
        <img class="logo-img" src="../imagens/logo-mg.png" alt="Logo MG Motors">
        <span class="logo-text">MG Motors</span>
      </a>
    </div>

    <button class="nav-toggle" type="button" aria-controls="main-nav" aria-expanded="false" aria-label="Abrir menu de navegacao">
      <span></span>
      <span></span>
      <span></span>
    </button>

    <nav class="nav" id="main-nav" aria-label="Navegacao principal">
      <a href="../MG-MARKETPLACE/marketplace.html" class="nav-marketplace nav-link">Marketplace</a>
      <a href="../MG-DICAS/dicas.html" class="nav-link">Dicas</a>
      <a href="../MG-CASOS-USO/como-utilizar.html" class="nav-link">Como Utilizar</a>
      <a href="../MG-CONTATO/contato.html" class="nav-link">Contato</a>
      <a href="../MG-MENSAGENS/mensagens.html" class="nav-link">Mensagens</a>
    </nav>

    <div class="icones" aria-label="Acoes da conta">
      <a id="header-nome" class="header-nome" href="../MG-LOGIN/login.html">Entrar</a>
      <img id="header-foto" class="icone-foto" src="../imagens/usuario.png" alt="Foto de perfil do usuario">

      <a class="icone-link" href="../MG-CONFIGURACOES/configuracoes.html" aria-label="Configuracoes">
        <svg class="icone" aria-hidden="true" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="12" cy="12" r="3"></circle>
          <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"></path>
        </svg>
      </a>

      <a class="icone-link" href="../MG-CONTA/conta.html" aria-label="Minha conta">
        <svg class="icone" aria-hidden="true" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path>
          <circle cx="12" cy="7" r="4"></circle>
        </svg>
      </a>
    </div>
  `;

  ativarLinkAtual();
  configurarMenuMobile(headerContainer);

  const headerNome = document.getElementById("header-nome");
  const headerFoto = document.getElementById("header-foto");

  try {
    const { data, error: authError } = await supabase.auth.getUser();

    if (authError || !data?.user) {
      headerNome.textContent = "Entrar";
      headerNome.href = "../MG-LOGIN/login.html";
      headerFoto.src = "../imagens/usuario.png";
      return null;
    }

    const { data: perfil, error: dbError } = await supabase
      .from("usuarios")
      .select("nome, foto, banido")
      .eq("id", data.user.id)
      .maybeSingle();

    if (dbError) {
      console.error("Erro ao carregar dados do perfil:", dbError.message);
    }

    if (perfil?.banido) {
      await supabase.auth.signOut();
      // Preserva a página atual para exibir mensagem contextual no login
      const loginUrl = new URL("../MG-LOGIN/login.html", window.location.href).href;
      window.location.replace(loginUrl + "?banido=1");
      return null;
    }

    headerNome.textContent = perfil?.nome || data.user.email;
    headerNome.href = "../MG-CONTA/conta.html";
    headerFoto.src = perfil?.foto || "../imagens/usuario.png";
    headerFoto.alt = `Foto de perfil de ${perfil?.nome || data.user.email}`;

    return data.user;
  } catch (error) {
    console.error("Erro inesperado ao carregar header:", error);
    headerNome.textContent = "Entrar";
    headerNome.href = "../MG-LOGIN/login.html";
    headerFoto.src = "../imagens/usuario.png";
    return null;
  }
}

function ativarLinkAtual() {
  const currentPath = window.location.pathname;

  document.querySelectorAll(".nav-link").forEach((link) => {
    const nomeDaPagina = link.getAttribute("href")?.split("/").pop();
    if (nomeDaPagina && currentPath.endsWith(nomeDaPagina)) {
      link.classList.add("ativo");
      link.setAttribute("aria-current", "page");
    }
  });
}


function configurarMenuMobile(headerContainer) {
  const nav = document.getElementById("main-nav");
  const navToggle = headerContainer.querySelector(".nav-toggle");

  const fecharMenu = () => {
    nav?.classList.remove("aberta");
    navToggle?.setAttribute("aria-expanded", "false");
    navToggle?.setAttribute("aria-label", "Abrir menu de navegacao");
    document.body.classList.remove("nav-aberta");
  };

  navToggle?.addEventListener("click", () => {
    const aberto = navToggle.getAttribute("aria-expanded") === "true";
    nav?.classList.toggle("aberta", !aberto);
    navToggle.setAttribute("aria-expanded", String(!aberto));
    navToggle.setAttribute("aria-label", aberto ? "Abrir menu de navegacao" : "Fechar menu de navegacao");
    document.body.classList.toggle("nav-aberta", !aberto);
  });

  nav?.addEventListener("click", (event) => {
    if (event.target.closest("a")) fecharMenu();
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") fecharMenu();
  });
}

/* ═══════════════════════════════════════════════════════
   TOAST NOTIFICATIONS — window.mgToast(msg, tipo, titulo)
   tipo: 'success' | 'error' | 'info' | 'warning'
   ═══════════════════════════════════════════════════════ */
(function initToast() {
  if (document.getElementById('mg-toast-container')) return;
  const c = document.createElement('div');
  c.id = 'mg-toast-container';
  c.setAttribute('aria-live', 'polite');
  c.setAttribute('aria-atomic', 'false');
  document.body.appendChild(c);
})();

window.mgToast = function(msg, tipo = 'info', titulo = '') {
  let c = document.getElementById('mg-toast-container');
  if (!c) {
    c = document.createElement('div');
    c.id = 'mg-toast-container';
    c.setAttribute('aria-live', 'polite');
    document.body.appendChild(c);
  }
  const t = document.createElement('div');
  t.className = `mg-toast ${tipo}`;
  t.setAttribute('role', 'alert');
  const tituloMap = { success: 'Sucesso', error: 'Erro', info: 'Informação', warning: 'Atenção' };
  const tituloFinal = titulo || tituloMap[tipo] || 'Aviso';
  // M1: Constrói via DOM (textContent) — nunca innerHTML com dados externos (anti-XSS)
  const iconEl = document.createElement('div');
  iconEl.className = 'mg-toast-icon';
  iconEl.setAttribute('aria-hidden', 'true');
  const bodyEl = document.createElement('div');
  bodyEl.className = 'mg-toast-body';
  const titleEl = document.createElement('div');
  titleEl.className = 'mg-toast-title';
  titleEl.textContent = tituloFinal;
  const msgEl = document.createElement('div');
  msgEl.className = 'mg-toast-msg';
  msgEl.textContent = msg;
  bodyEl.appendChild(titleEl);
  bodyEl.appendChild(msgEl);
  t.appendChild(iconEl);
  t.appendChild(bodyEl);
  c.appendChild(t);
  const dur = tipo === 'error' ? 5500 : 3800;
  setTimeout(() => {
    t.classList.add('hide');
    setTimeout(() => t.remove(), 300);
  }, dur);
};

/* ═══════════════════════════════════════════════════════
   BOTÃO VOLTAR AO TOPO — injetado automaticamente
   ═══════════════════════════════════════════════════════ */
(function initBtnTopo() {
  if (document.getElementById('btn-topo')) return;
  const btn = document.createElement('button');
  btn.id = 'btn-topo';
  btn.setAttribute('aria-label', 'Voltar ao topo');
  btn.setAttribute('title', 'Voltar ao topo');
  btn.innerHTML = `<svg viewBox="0 0 24 24"><polyline points="18 15 12 9 6 15"/></svg>`;
  document.body.appendChild(btn);

  const onScroll = () => btn.classList.toggle('visivel', window.scrollY > 320);
  window.addEventListener('scroll', onScroll, { passive: true });
  btn.addEventListener('click', () => window.scrollTo({ top: 0, behavior: 'smooth' }));
})();

