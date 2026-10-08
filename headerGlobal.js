// arquivo: headerGlobal.js

import { consentimentoAtual, registrarAceiteLegal } from "./legalConsent.js";

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

  if (!supabase) {
    headerNome.textContent = "Entrar";
    headerNome.href = "../MG-LOGIN/login.html";
    headerFoto.src = "../imagens/usuario.png";
    mostrarBannerTermos();
    return null;
  }

  try {
    const { data, error: authError } = await supabase.auth.getUser();

    if (authError || !data?.user) {
      headerNome.textContent = "Entrar";
      headerNome.href = "../MG-LOGIN/login.html";
      headerFoto.src = "../imagens/usuario.png";
      mostrarBannerTermos();
      return null;
    }

    const { data: perfil, error: dbError } = await supabase
      .from("usuarios")
      .select("nome, foto, banido, terms_accepted_at, privacy_accepted_at, terms_version, privacy_version")
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

    if (!consentimentoAtual(perfil)) {
      mostrarBannerTermos({ supabase, usuario: data.user, perfil });
    }

    return data.user;
  } catch (error) {
    console.error("Erro inesperado ao carregar header:", error);
    headerNome.textContent = "Entrar";
    headerNome.href = "../MG-LOGIN/login.html";
    headerFoto.src = "../imagens/usuario.png";
    mostrarBannerTermos();
    return null;
  }
}

/* ═══════════════════════════════════════════════════════
   BANNER DE TERMOS — exibido para usuários deslogados
   Aparece uma vez por dispositivo (salvo em localStorage).
   ═══════════════════════════════════════════════════════ */
function mostrarBannerTermos({ supabase = null, usuario = null, perfil = null } = {}) {
  const autenticado = Boolean(supabase && usuario);
  if (!autenticado && localStorage.getItem("mg_termos_aceitos")) return;
  if (autenticado && consentimentoAtual(perfil)) return;

  /* Resolve o caminho das páginas legais relativamente à origem */
  const base = new URL("../MG-LEGAL/", window.location.href).href;
  const urlTermos      = base + "termos.html";
  const urlPrivacidade = base + "privacidade.html";

  /* ── Estilos injetados ── */
  const style = document.createElement("style");
  style.textContent = `
    #mg-banner-termos {
      position: fixed;
      bottom: 0; left: 0; right: 0;
      z-index: 9990;
      background: #0f172a;
      border-top: 1px solid rgba(255,255,255,0.08);
      box-shadow: 0 -8px 40px rgba(0,0,0,0.45);
      padding: 20px clamp(20px, 5vw, 60px);
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 24px;
      flex-wrap: wrap;
      transform: translateY(110%);
      transition: transform 0.42s cubic-bezier(0.16,1,0.3,1);
    }
    #mg-banner-termos.visivel {
      transform: translateY(0);
    }
    #mg-banner-termos.oculto {
      transform: translateY(110%);
    }
    .mg-banner-texto {
      flex: 1 1 300px;
      font-family: "Ruda", "Segoe UI", system-ui, sans-serif;
    }
    .mg-banner-titulo {
      font-size: 15px;
      font-weight: 800;
      color: #fff;
      margin-bottom: 6px;
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .mg-banner-titulo svg {
      flex-shrink: 0;
      color: #2563eb;
    }
    .mg-banner-desc {
      font-size: 13.5px;
      color: rgba(255,255,255,0.62);
      line-height: 1.55;
      font-weight: 500;
    }
    .mg-banner-desc a {
      color: #60a5fa;
      text-decoration: none;
      font-weight: 700;
      transition: color 0.18s;
    }
    .mg-banner-desc a:hover { color: #93c5fd; text-decoration: underline; }
    .mg-banner-acoes {
      display: flex;
      gap: 10px;
      align-items: center;
      flex-shrink: 0;
    }
    #mg-banner-aceitar {
      background: #2563eb;
      color: #fff;
      border: none;
      border-radius: 8px;
      padding: 10px 22px;
      font-size: 14px;
      font-weight: 800;
      font-family: inherit;
      cursor: pointer;
      transition: background 0.18s, transform 0.18s;
      white-space: nowrap;
    }
    #mg-banner-aceitar:hover {
      background: #1d4ed8;
      transform: translateY(-1px);
    }
    #mg-banner-rejeitar {
      background: transparent;
      color: rgba(255,255,255,0.45);
      border: 1px solid rgba(255,255,255,0.12);
      border-radius: 8px;
      padding: 10px 16px;
      font-size: 13px;
      font-weight: 700;
      font-family: inherit;
      cursor: pointer;
      transition: color 0.18s, border-color 0.18s;
      white-space: nowrap;
    }
    #mg-banner-rejeitar:hover {
      color: rgba(255,255,255,0.75);
      border-color: rgba(255,255,255,0.28);
    }
    @media (max-width: 600px) {
      #mg-banner-termos { flex-direction: column; align-items: stretch; gap: 16px; }
      .mg-banner-acoes { flex-direction: column; }
      #mg-banner-aceitar, #mg-banner-rejeitar { width: 100%; text-align: center; }
    }
  `;
  document.head.appendChild(style);

  /* ── HTML do banner ── */
  const banner = document.createElement("div");
  banner.id = "mg-banner-termos";
  banner.setAttribute("role", "dialog");
  banner.setAttribute("aria-modal", "false");
  banner.setAttribute("aria-label", "Consentimento de Termos e Privacidade");
  banner.innerHTML = `
    <div class="mg-banner-texto">
      <div class="mg-banner-titulo">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
          <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>
        </svg>
        ${autenticado ? "Atualize seu aceite legal" : "Sua privacidade importa para nós"}
      </div>
      <p class="mg-banner-desc">
        ${autenticado ? "Para continuar usando todos os recursos, confirme seu aceite da versão atual dos nossos" : "Ao usar a MG Motors, você concorda com nossos"}
        <a href="${urlTermos}" target="_blank" rel="noopener">Termos de Uso</a>
        e nossa
        <a href="${urlPrivacidade}" target="_blank" rel="noopener">Política de Privacidade</a>.
        Leia os documentos antes de continuar.
      </p>
    </div>
    <div class="mg-banner-acoes">
      <button id="mg-banner-rejeitar" type="button">${autenticado ? "Agora não" : "Recusar"}</button>
      <button id="mg-banner-aceitar" type="button">Aceitar e Continuar</button>
    </div>
  `;
  document.body.appendChild(banner);

  /* Slide-in após um frame para a transição funcionar */
  requestAnimationFrame(() => {
    requestAnimationFrame(() => banner.classList.add("visivel"));
  });

  const fechar = async (aceito) => {
    if (aceito && autenticado) {
      const { error } = await registrarAceiteLegal(supabase);
      if (error) {
        window.mgToast?.("Não foi possível registrar seu aceite. Tente novamente.", "error");
        return;
      }
    }
    if (aceito && !autenticado) localStorage.setItem("mg_termos_aceitos", "1");
    banner.classList.remove("visivel");
    banner.classList.add("oculto");
    setTimeout(() => banner.remove(), 450);
  };

  document.getElementById("mg-banner-aceitar").addEventListener("click", () => fechar(true));
  document.getElementById("mg-banner-rejeitar").addEventListener("click", () => {
    fechar(false);
    if (!autenticado) {
      /* Redireciona para a página de termos para o usuário ler antes de decidir */
      setTimeout(() => window.location.href = urlTermos, 300);
    }
  });
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
