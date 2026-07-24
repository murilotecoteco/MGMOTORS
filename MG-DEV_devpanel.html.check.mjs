


const supabase = createClient(supabaseUrl, supabaseKey);
// A lista de e-mails admin NÃO fica mais aqui. A checagem real (e a
// proteção real) está nas policies de RLS no Supabase, via função
// is_admin(). Isso aqui é só pra decidir se mostra ou esconde a tela;
// não é mais a barreira de segurança.
async function souAdmin() {
  const { data, error } = await supabase.rpc("is_admin");
  return !error && data === true;
}

function toast(msg) {
  const t = document.getElementById("toast");
  t.textContent = msg;
  t.classList.add("show");
  setTimeout(() => t.classList.remove("show"), 3000);
}

async function init() {
  const { data } = await supabase.auth.getUser();
  if (!data?.user || !(await souAdmin())) { document.getElementById("acesso-negado").style.display = "flex"; return; }
  document.getElementById("acesso-negado").style.display = "none";
  document.getElementById("painel").style.display = "block";
  carregarDashboard();
  carregarPendentes();
  carregarDenuncias();
  carregarUsuarios();
}

async function carregarDashboard() {
  const [u, a, p, d, b, pa] = await Promise.all([
    supabase.from("usuarios").select("id",{count:"exact",head:true}),
    supabase.from("anuncios").select("id",{count:"exact",head:true}).eq("status","ativo"),
    supabase.from("anuncios").select("id",{count:"exact",head:true}).eq("status","pendente"),
    supabase.from("denuncias").select("id",{count:"exact",head:true}).eq("status","pendente"),
    supabase.from("usuarios").select("id",{count:"exact",head:true}).eq("banido",true)
  ]);
  document.getElementById("stat-total-usuarios").textContent = u.count || 0;
  document.getElementById("stat-total-anuncios").textContent = a.count || 0;
  document.getElementById("stat-pendentes").textContent = p.count || 0;
  document.getElementById("stat-denuncias").textContent = d.count || 0;
  document.getElementById("stat-banidos").textContent = b.count || 0;
}

async function carregarPendentes() {
  const { data } = await supabase.from("anuncios").select("*, marcas(nome), modelos(nome)").eq("status","pendente").order("criado_em",{ascending:false});
  const cont = document.getElementById("lista-pendentes");
  if (!data || data.length === 0) { cont.innerHTML = '<div class="empty-dev">✅ Nenhum anúncio pendente</div>'; return; }
  cont.innerHTML = "";
  for (const a of data) {
    const { data: fotos } = await supabase.from("fotos_anuncio").select("url_foto").eq("anuncio_id",a.id).limit(1);
    const foto = fotos?.[0]?.url_foto || "";
    const d = document.createElement("div");
    d.className = "card-dev";
    d.innerHTML = `
      <div class="card-dev-header">
        ${foto ? `<img src="${foto}" class="anuncio-img">` : ""}
        <div style="flex:1;">
          <h3>${escapeHtml(a.marcas?.nome)} ${escapeHtml(a.modelos?.nome)} — ${a.ano_fabricacao}/${a.ano_modelo}</h3>
          <p>R$ ${Number(a.preco).toLocaleString("pt-BR")} · ${Number(a.quilometragem).toLocaleString()} km · ${escapeHtml(a.cidade) || "Cidade não informada"}</p>
          <p style="margin-top:4px;font-size:12px;color:rgba(255,255,255,.35);">Publicado: ${new Date(a.criado_em).toLocaleString("pt-BR")}</p>
        </div>
        <div>
          <button class="btn-dev btn-aprovar" data-id="${a.id}">✅ Aprovar</button>
          <button class="btn-dev btn-rejeitar" data-id="${a.id}">❌ Rejeitar</button>
        </div>
      </div>
    `;
    d.querySelector(".btn-aprovar").onclick = async () => {
      await supabase.from("anuncios").update({status:"ativo"}).eq("id",a.id);
      toast("✅ Anúncio aprovado"); d.remove(); carregarDashboard();
    };
    d.querySelector(".btn-rejeitar").onclick = async () => {
      if (!confirm("Rejeitar este anúncio?")) return;
      await supabase.from("anuncios").update({status:"rejeitado"}).eq("id",a.id);
      toast("❌ Anúncio rejeitado"); d.remove(); carregarDashboard();
    };
    cont.appendChild(d);
  }
}

async function carregarDenuncias() {
  const { data } = await supabase.from("denuncias").select("*").eq("status","pendente").order("criado_em",{ascending:false});
  const cont = document.getElementById("lista-denuncias");
  if (!data || data.length === 0) { cont.innerHTML = '<div class="empty-dev">✅ Nenhuma denúncia pendente</div>'; return; }
  cont.innerHTML = "";
  for (const den of data) {
    // Buscar info do denunciante
    let denuncianteInfo = '';
    const { data: denunciante } = await supabase.from("usuarios").select("nome,email,foto").eq("id", den.denunciante_id).single();
    if (denunciante) {
      denuncianteInfo = `<div style="display:flex;align-items:center;gap:8px;margin-top:8px;padding:8px;background:rgba(255,255,255,.04);border-radius:8px;">
        <img src="${denunciante.foto || '../imagens/usuario.png'}" style="width:30px;height:30px;border-radius:50%;object-fit:cover;" onerror="this.src='../imagens/usuario.png'">
        <div><div style="font-size:12px;font-weight:800;color:#e6edf3;">Denunciado por: ${escapeHtml(denunciante.nome || denunciante.email)}</div><div style="font-size:11px;color:rgba(255,255,255,.4);">${escapeHtml(denunciante.email)}</div></div>
        <a href="../MG-CONTA/conta.html?id=${den.denunciante_id}" target="_blank" class="btn-dev" style="background:rgba(255,215,0,.1);color:#ffd700;border:1px solid rgba(255,215,0,.2);text-decoration:none;padding:4px 10px;font-size:11px;">👤 Ver</a>
      </div>`;
    }
    // Buscar info do alvo
    let alvoInfo = '';
    if (den.tipo === 'perfil') {
      const { data: alvo } = await supabase.from("usuarios").select("nome,email,foto").eq("id", den.alvo_id).single();
      if (alvo) {
        alvoInfo = `<div style="display:flex;align-items:center;gap:8px;margin-top:6px;padding:8px;background:rgba(232,64,64,.06);border-radius:8px;border:1px solid rgba(232,64,64,.15);">
          <img src="${alvo.foto || '../imagens/usuario.png'}" style="width:30px;height:30px;border-radius:50%;object-fit:cover;" onerror="this.src='../imagens/usuario.png'">
          <div><div style="font-size:12px;font-weight:800;color:#e84040;">Usuário denunciado: ${escapeHtml(alvo.nome || alvo.email)}</div><div style="font-size:11px;color:rgba(255,255,255,.4);">${escapeHtml(alvo.email)}</div></div>
          <a href="../MG-CONTA/conta.html?id=${den.alvo_id}" target="_blank" class="btn-dev" style="background:rgba(232,64,64,.1);color:#e84040;border:1px solid rgba(232,64,64,.2);text-decoration:none;padding:4px 10px;font-size:11px;">👤 Ver perfil</a>
        </div>`;
      }
    } else if (den.tipo === 'anuncio') {
      const { data: anuncio } = await supabase.from("anuncios").select("*, marcas(nome), modelos(nome)").eq("id", den.alvo_id).single();
      if (anuncio) {
        const { data: fotos } = await supabase.from("fotos_anuncio").select("url_foto").eq("anuncio_id", den.alvo_id).limit(1);
        const fotoAnuncio = fotos?.[0]?.url_foto || '';
        alvoInfo = `<div style="display:flex;align-items:center;gap:8px;margin-top:6px;padding:8px;background:rgba(255,165,0,.06);border-radius:8px;border:1px solid rgba(255,165,0,.15);">
          ${fotoAnuncio ? `<img src="${fotoAnuncio}" style="width:55px;height:38px;border-radius:6px;object-fit:cover;">` : ''}
          <div style="flex:1;"><div style="font-size:12px;font-weight:800;color:#ffa500;">Anúncio: ${escapeHtml(anuncio.marcas?.nome)} ${escapeHtml(anuncio.modelos?.nome)} (${anuncio.ano_fabricacao})</div>
          <div style="font-size:11px;color:rgba(255,255,255,.4);">R$ ${Number(anuncio.preco).toLocaleString('pt-BR')} · ${escapeHtml(anuncio.cidade)}</div></div>
        </div>`;
      }
    }
    const d = document.createElement("div");
    d.className = "card-dev";
    d.innerHTML = `
      <div class="card-dev-header">
        <div style="flex:1;">
          <div style="display:flex;align-items:center;gap:8px;margin-bottom:6px;">
            <span class="badge badge-pend">Pendente</span>
            <span style="font-size:13px;color:rgba(255,255,255,.4);">${den.tipo === 'anuncio' ? '📢 Anúncio' : den.tipo === 'mensagem' ? '💬 Mensagem/Foto' : '👤 Perfil'}</span>
          </div>
          <h3>${escapeHtml(den.motivo)}</h3>
          ${den.descricao ? `<p style="font-size:12px;color:rgba(255,255,255,.5);margin-top:4px;">${escapeHtml(den.descricao)}</p>` : ''}
          <p style="font-size:11px;color:rgba(255,255,255,.3);margin-top:4px;">${new Date(den.criado_em).toLocaleString("pt-BR")}</p>
          ${alvoInfo}
          ${denuncianteInfo}
        </div>
        <div style="display:flex;flex-direction:column;gap:6px;">
          ${den.tipo === 'anuncio' ? `<button class="btn-dev btn-rejeitar" data-id="${den.alvo_id}" data-den="${den.id}">🚫 Banir anúncio</button>` : den.tipo === 'mensagem' ? `<small style="color:rgba(255,255,255,.5);font-size:11px;">Msg ID: ${den.alvo_id?.substring(0,8)}...</small>` : `<button class="btn-dev btn-banir" data-uid="${den.alvo_id}" data-den="${den.id}">🔨 Banir usuário</button><button class="btn-dev btn-desbanir" data-uid="${den.alvo_id}" data-den="${den.id}">✅ Desbanir usuário</button>`}
          <button class="btn-dev btn-aprovar" data-den="${den.id}" data-tipo="ignorar">✅ Ignorar</button>
        </div>
      </div>
    `;
    const ignorar = d.querySelector('[data-tipo="ignorar"]');
    ignorar.onclick = async () => {
      await supabase.from("denuncias").update({status:"resolvido",resolvido_em:new Date().toISOString()}).eq("id",den.id);
      toast("Denúncia ignorada"); d.remove(); carregarDashboard();
    };
    const banirAnuncio = d.querySelector('.btn-rejeitar');
    if (banirAnuncio) banirAnuncio.onclick = async () => {
      await supabase.from("anuncios").update({status:"banido"}).eq("id",den.alvo_id);
      await supabase.from("denuncias").update({status:"resolvido",resolvido_em:new Date().toISOString()}).eq("id",den.id);
      toast("🚫 Anúncio removido"); d.remove(); carregarDashboard();
    };
    const banirUser = d.querySelector('.btn-banir');
    if (banirUser) banirUser.onclick = async () => {
      const motivo = prompt("Motivo do banimento:");
      if (!motivo) return;
      await supabase.from("usuarios").update({banido:true}).eq("id",den.alvo_id);
      await supabase.from("denuncias").update({status:"resolvido",resolvido_em:new Date().toISOString()}).eq("id",den.id);
      toast("🔨 Usuário banido"); d.remove(); carregarDashboard();
    };
    const desbanirUser = d.querySelector('.btn-desbanir');
    if (desbanirUser) desbanirUser.onclick = async () => {
      await supabase.from("usuarios").update({banido:false}).eq("id",den.alvo_id);
      await supabase.from("denuncias").update({status:"resolvido",resolvido_em:new Date().toISOString()}).eq("id",den.id);
      toast("✅ Usuário desbanido"); d.remove(); carregarDashboard();
    };
    cont.appendChild(d);
  }
}

async function carregarUsuarios(busca = "") {
  let query = supabase.from("usuarios").select("*").order("criado_em",{ascending:false}).limit(50);
  if (busca) query = query.or(`nome.ilike.%${busca}%,email.ilike.%${busca}%`);
  const { data } = await query;
  const cont = document.getElementById("lista-usuarios");
  if (!data || data.length === 0) { cont.innerHTML = '<div class="empty-dev">Nenhum usuário encontrado</div>'; return; }
  cont.innerHTML = "";
  for (const u of data) {
    const d = document.createElement("div");
    d.className = "card-dev";
    d.innerHTML = `
      <div class="card-dev-header">
        <img src="${u.foto || '../imagens/usuario.png'}" class="user-foto" onerror="this.src='../imagens/usuario.png'">
        <div style="flex:1;">
          <h3>${escapeHtml(u.nome) || "Sem nome"} ${u.banido ? '<span class="badge badge-ban" style="margin-left:8px;">Banido</span>' : ''}</h3>
          <p>${escapeHtml(u.email)} ${u.cidade ? `· ${escapeHtml(u.cidade)}` : ""}</p>
          <p style="font-size:11px;color:rgba(255,255,255,.3);">Desde ${new Date(u.criado_em || Date.now()).toLocaleDateString("pt-BR")}</p>
        </div>
        <div>
          ${u.banido
            ? `<button class="btn-dev btn-desbanir" data-uid="${u.id}">✅ Desbanir</button>`
            : `<button class="btn-dev btn-banir" data-uid="${u.id}">🔨 Banir</button>`}
          <a href="../MG-CONTA/conta.html?id=${u.id}" target="_blank" class="btn-dev" style="background:rgba(255,215,0,.1);color:#ffd700;border:1px solid rgba(255,215,0,.2);text-decoration:none;">👤 Ver perfil</a>
        </div>
      </div>
    `;
    const btnBanir = d.querySelector('.btn-banir');
    if (btnBanir) btnBanir.onclick = async () => {
      const motivo = prompt("Motivo do banimento:");
      if (!motivo) return;
      await supabase.from("usuarios").update({banido:true}).eq("id",u.id);
      toast("🔨 Usuário banido"); carregarUsuarios(busca);
    };
    const btnDesbanir = d.querySelector('.btn-desbanir');
    if (btnDesbanir) btnDesbanir.onclick = async () => {
      await supabase.from("usuarios").update({banido:false}).eq("id",u.id);
      toast("✅ Usuário desbanido"); carregarUsuarios(busca);
    };
    cont.appendChild(d);
  }
}

async function carregarBanidos() {
  const { data } = await supabase.from("usuarios").select("id,nome,email,foto,cidade,estado").eq("banido",true).order("nome");
  const cont = document.getElementById("lista-banidos");
  if (!data || data.length === 0) { cont.innerHTML = '<div class="empty-dev">Nenhum usuário banido 🎉</div>'; return; }
  cont.innerHTML = "";
  for (const u of data) {
    const d = document.createElement("div");
    d.className = "card-dev";
    d.innerHTML = `
      <div class="card-dev-header">
        <img src="${u.foto||'../imagens/usuario.png'}" style="width:50px;height:50px;border-radius:50%;object-fit:cover;border:2px solid rgba(232,64,64,.4);" onerror="this.src='../imagens/usuario.png'">
        <div style="flex:1;">
          <h3 style="color:#e84040;">${escapeHtml(u.nome)||'Sem nome'} <span class="badge badge-ban">Banido</span></h3>
          <p style="font-size:12px;opacity:.6;">${escapeHtml(u.email)} ${u.cidade?'· '+escapeHtml(u.cidade)+'/'+escapeHtml(u.estado):''}</p>
        </div>
        <button class="btn-dev btn-desbanir" data-uid="${u.id}">✅ Desbanir</button>
      </div>
    `;
    d.querySelector(".btn-desbanir").onclick = async () => {
      await supabase.from("usuarios").update({banido:false}).eq("id",u.id);
      toast("✅ Usuário desbanido com sucesso!"); d.remove();
      document.getElementById("stat-banidos").textContent = Math.max(0, parseInt(document.getElementById("stat-banidos").textContent||0) - 1);
    };
    cont.appendChild(d);
  }
}

document.querySelectorAll(".tab").forEach(tab => {
  tab.addEventListener("click", () => {
    document.querySelectorAll(".tab").forEach(t => t.classList.remove("ativo"));
    document.querySelectorAll(".tab-content").forEach(c => c.classList.remove("ativo"));
    tab.classList.add("ativo");
    document.getElementById("tab-" + tab.dataset.tab).classList.add("ativo");
    if (tab.dataset.tab === "banidos") carregarBanidos();
  });
});

let buscaTimer;
document.getElementById("busca-usuario").addEventListener("input", e => {
  clearTimeout(buscaTimer);
  buscaTimer = setTimeout(() => carregarUsuarios(e.target.value), 400);
});

init();
