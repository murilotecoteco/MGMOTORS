



const supabase = createClient(supabaseUrl, supabaseKey);

let perfilUsuarioId = null;
let notaEscolhida = 0;

// --- Helper de escrita com aviso ao usuário (Melhoria 2) ---
// Executa uma promise do Supabase (insert/update/delete/upsert) e, se falhar,
// mostra um alerta claro para o usuário em vez de falhar silenciosamente.
// Retorna `null` em caso de erro, ou `data` em caso de sucesso.
async function executarOuAvisar(promise, mensagemErroPadrao = "Algo deu errado. Tente novamente.") {
  const { data, error } = await promise;
  if (error) {
    console.error(error);
    alert(mensagemErroPadrao + (error.message ? `\n(${error.message})` : ""));
    return null;
  }
  return data;
}

const urlParams = new URLSearchParams(window.location.search);
const perfilIdUrl = urlParams.get('id');
const fotoPerfil = document.getElementById("fotoPerfil");
const capaFoto = document.getElementById("capaFoto");
const nomeExibido = document.getElementById("nomeExibido");
const bioExibido = document.getElementById("bioExibido");
const redesExibido = document.getElementById("redesExibido");
const btnSeguir = document.getElementById("btnSeguir");

let usuarioAtual = await carregarHeaderGlobal(supabase);


async function carregarPerfil() {
  const isOutro = perfilIdUrl && perfilIdUrl !== usuarioAtual?.id;
  perfilUsuarioId = isOutro ? perfilIdUrl : usuarioAtual?.id;
  document.getElementById("tabs-proprio").style.display = isOutro ? "none" : "block";
  document.getElementById("tabs-outro").style.display = isOutro ? "block" : "none";
  document.getElementById("btnEditarFoto").style.display = isOutro ? "none" : "block";
  document.getElementById("btnEditarCapa").style.display = isOutro ? "none" : "block";
  btnSeguir.style.display = isOutro && usuarioAtual ? "block" : "none";
  document.getElementById("btnDenunciarPerfil").style.display = isOutro && usuarioAtual ? "block" : "none";
  if (!perfilUsuarioId) return;
  // Melhoria 1: talvez o perfil ainda não exista na tabela `usuarios` (ex: conta recém-criada).
  // `.maybeSingle()` retorna data:null sem lançar erro 406 (PGRST116), evitando travar em "Carregando...".
  const { data: perfil } = await supabase.from("usuarios").select("*").eq("id", perfilUsuarioId).maybeSingle();
  if (!perfil) {
    nomeExibido.textContent = "Usuário";
    return;
  }
  nomeExibido.textContent = perfil.nome || "Usuário";
  fotoPerfil.src = perfil.foto || "https://via.placeholder.com/150";
  capaFoto.src = perfil.capa_foto || "https://images.unsplash.com/photo-1503376780359-7e1a0b6e3b6c?w=1200&h=200&fit=crop";
  bioExibido.textContent = perfil.bio || "Sem biografia";
  document.getElementById("seguidoresCount").textContent = perfil.seguidores || 0;
  document.getElementById("seguindoCount").textContent = perfil.seguindo || 0;
  if (perfil.nota_media > 0) {
    document.getElementById("nota-media-container").style.display = "flex";
    const estrelas = "★".repeat(Math.round(perfil.nota_media)) + "☆".repeat(5-Math.round(perfil.nota_media));
    document.getElementById("nota-estrelas").textContent = estrelas;
    document.getElementById("nota-texto").textContent = ` ${Number(perfil.nota_media).toFixed(1)} (${perfil.total_avaliacoes} avaliações)`;
  }
  let redes = "";
  if (perfil.instagram) redes += `<a href="https://instagram.com/${perfil.instagram.replace('@','')}" target="_blank" class="redes-link">📷 Instagram</a>`;
  if (perfil.site) redes += `<a href="${perfil.site}" target="_blank" class="redes-link">🌐 Site</a>`;
  redesExibido.innerHTML = redes;
  if (usuarioAtual && isOutro) {
    // Melhoria 1: "ainda não segue" é o resultado esperado na primeira vez -> maybeSingle().
    const { data: segue } = await supabase.from("seguidores").select("id").eq("seguidor_id",usuarioAtual.id).eq("seguido_id",perfilUsuarioId).maybeSingle();
    if (segue) { btnSeguir.textContent = "Seguindo"; btnSeguir.classList.add("seguindo"); }
    else { btnSeguir.textContent = "Seguir"; btnSeguir.classList.remove("seguindo"); }
  }
  if (isOutro) await carregarAnunciosOutro();
  else { await carregarMeusAnuncios(); await carregarPausados(); }
  await carregarCurtidasRecebidas();
}

async function carregarMeusAnuncios() {
  if (!perfilUsuarioId) return;
  const { data: anuncios } = await supabase.from("anuncios").select("*, marcas(nome), modelos(nome)").eq("usuario_id",perfilUsuarioId).neq("pausado",true).order("criado_em",{ascending:false});
  document.getElementById("anunciosCount").textContent = anuncios?.length || 0;
  const cont = document.getElementById("meus-anuncios-lista");
  if (!anuncios || anuncios.length === 0) { cont.innerHTML = "<p style='text-align:center;'>Nenhum anúncio ativo.</p>"; return; }
  cont.innerHTML = "";
  for (const a of anuncios) {
    const { data: fotos } = await supabase.from("fotos_anuncio").select("url_foto").eq("anuncio_id",a.id).order("ordem").limit(1);
    const foto = fotos?.[0]?.url_foto || "../imagens/sem-foto.png";
    const card = document.createElement("div"); card.className = "anuncio-card";
    const statusBadge = a.status === 'pendente' ? '<span style="background:#fff3cd;color:#856404;padding:3px 8px;border-radius:12px;font-size:11px;font-weight:800;">⏳ Pendente aprovação</span>' : '';
    // Estrutura estática com <h3> vazio; marca/modelo preenchidos via textContent (sem risco de XSS)
    card.innerHTML = `<img src="${foto}" alt=""><div class="anuncio-info"><h3></h3><p>${a.ano_fabricacao} | ${a.quilometragem.toLocaleString()} km</p>${statusBadge}<div class="anuncio-preco">R$ ${Number(a.preco).toLocaleString("pt-BR")}</div><div class="anuncio-curtidas">❤️ ${a.curtidas||0} curtidas</div><button class="btn-excluir-anuncio" data-id="${a.id}">🗑 Excluir</button></div>`;
    card.querySelector('img').alt = (a.marcas?.nome || '');
    card.querySelector('.anuncio-info h3').textContent = `${a.marcas?.nome || ''} ${a.modelos?.nome || ''}`.trim();
    card.addEventListener("click", e => { if (!e.target.matches('.btn-excluir-anuncio')) window.location.href = `../MG-MARKETPLACE/marketplace.html?carro=${a.id}`; });
    cont.appendChild(card);
  }
  cont.querySelectorAll(".btn-excluir-anuncio").forEach(btn => btn.addEventListener("click", async e => {
    e.stopPropagation(); if (!confirm("Excluir anúncio?")) return;
    const ok = await executarOuAvisar(supabase.from("anuncios").delete().eq("id",btn.dataset.id), "Não foi possível excluir o anúncio.");
    if (ok === null) return;
    carregarMeusAnuncios();
  }));
}

async function carregarPausados() {
  const { data } = await supabase.from("anuncios").select("*, marcas(nome), modelos(nome)").eq("usuario_id",perfilUsuarioId).eq("pausado",true);
  const cont = document.getElementById("pausados-lista");
  if (!data || data.length === 0) { cont.innerHTML = "<p style='text-align:center;'>Nenhum anúncio pausado.</p>"; return; }
  cont.innerHTML = "";
  for (const a of data) {
    const { data: fotos } = await supabase.from("fotos_anuncio").select("url_foto").eq("anuncio_id",a.id).limit(1);
    const foto = fotos?.[0]?.url_foto || "../imagens/sem-foto.png";
    const card = document.createElement("div"); card.className = "anuncio-card";
    // Estrutura estática com <h3> vazio; marca/modelo preenchidos via textContent (sem risco de XSS)
    card.innerHTML = `<img src="${foto}" alt="" style="filter:grayscale(.6)"><div class="anuncio-info" style="opacity:.8;"><h3></h3><p>${a.ano_fabricacao} | ${a.quilometragem.toLocaleString()} km</p><span style="background:#e0e0e0;color:#666;padding:3px 8px;border-radius:12px;font-size:11px;font-weight:800;">⏸ Pausado</span><div class="anuncio-preco">R$ ${Number(a.preco).toLocaleString("pt-BR")}</div><button class="btn-reativar" data-id="${a.id}" style="width:100%;padding:8px;background:#28a745;color:#fff;border:none;border-radius:8px;cursor:pointer;font-weight:800;margin-top:8px;">▶ Reativar</button></div>`;
    card.querySelector('img').alt = (a.marcas?.nome || '');
    card.querySelector('.anuncio-info h3').textContent = `${a.marcas?.nome || ''} ${a.modelos?.nome || ''}`.trim();
    cont.appendChild(card);
  }
  cont.querySelectorAll(".btn-reativar").forEach(btn => btn.addEventListener("click", async e => {
    e.stopPropagation();
    const ok = await executarOuAvisar(supabase.from("anuncios").update({pausado:false,status:"ativo"}).eq("id",btn.dataset.id), "Não foi possível reativar o anúncio.");
    if (ok === null) return;
    alert("✅ Anúncio reativado com sucesso!"); carregarPausados(); carregarMeusAnuncios();
  }));
}

async function carregarAnunciosOutro() {
  const { data } = await supabase.from("anuncios").select("*, marcas(nome), modelos(nome)").eq("usuario_id",perfilUsuarioId).eq("status","ativo").neq("pausado",true);
  document.getElementById("anunciosCount").textContent = data?.length || 0;
  const cont = document.getElementById("anuncios-outro-lista");
  if (!data || data.length === 0) { cont.innerHTML = "<p style='text-align:center;'>Nenhum anúncio ativo.</p>"; return; }
  cont.innerHTML = "";
  for (const a of data) {
    const { data: fotos } = await supabase.from("fotos_anuncio").select("url_foto").eq("anuncio_id",a.id).limit(1);
    const foto = fotos?.[0]?.url_foto || "../imagens/sem-foto.png";
    const card = document.createElement("div"); card.className = "anuncio-card";
    // Estrutura estática com <h3> vazio; marca/modelo preenchidos via textContent (sem risco de XSS)
    card.innerHTML = `<img src="${foto}" alt=""><div class="anuncio-info"><h3></h3><p>${a.ano_fabricacao} | ${a.quilometragem.toLocaleString()} km</p><div class="anuncio-preco">R$ ${Number(a.preco).toLocaleString("pt-BR")}</div><div class="anuncio-curtidas">❤️ ${a.curtidas||0} curtidas</div></div>`;
    card.querySelector('img').alt = (a.marcas?.nome || '');
    card.querySelector('.anuncio-info h3').textContent = `${a.marcas?.nome || ''} ${a.modelos?.nome || ''}`.trim();
    card.addEventListener("click", () => window.location.href = `../MG-MARKETPLACE/marketplace.html?carro=${a.id}`);
    cont.appendChild(card);
  }
}

async function carregarCurtidasRecebidas() {
  const { data } = await supabase.from("anuncios").select("curtidas").eq("usuario_id",perfilUsuarioId);
  document.getElementById("curtidasRecebidasCount").textContent = data?.reduce((s,a)=>s+(a.curtidas||0),0)||0;
}

btnSeguir.addEventListener("click", async () => {
  if (!usuarioAtual) { alert("Faça login"); window.location.href="../MG-LOGIN/login.html"; return; }
  const seg = btnSeguir.classList.contains("seguindo");
  if (seg) {
    const ok = await executarOuAvisar(supabase.from("seguidores").delete().eq("seguidor_id",usuarioAtual.id).eq("seguido_id",perfilUsuarioId), "Não foi possível deixar de seguir.");
    if (ok === null) return;
    btnSeguir.textContent="Seguir"; btnSeguir.classList.remove("seguindo");
  } else {
    const ok = await executarOuAvisar(supabase.from("seguidores").insert({seguidor_id:usuarioAtual.id,seguido_id:perfilUsuarioId}), "Não foi possível seguir este usuário.");
    if (ok === null) return;
    btnSeguir.textContent="Seguindo"; btnSeguir.classList.add("seguindo");
  }
  // Perfil já foi carregado acima; maybeSingle() evita 406 em leitura concorrente.
  const { data: p } = await supabase.from("usuarios").select("seguidores").eq("id",perfilUsuarioId).maybeSingle();
  document.getElementById("seguidoresCount").textContent = p?.seguidores||0;
});

document.getElementById("btnDenunciarPerfil").addEventListener("click", () => { document.getElementById("modal-denuncia").style.display="flex"; });
document.getElementById("btn-enviar-denuncia")?.addEventListener("click", async () => {
  const motivo = document.getElementById("denuncia-motivo").value;
  if (!motivo || !usuarioAtual) { alert("Selecione um motivo."); return; }
  const ok = await executarOuAvisar(supabase.from("denuncias").insert({tipo:"perfil",alvo_id:perfilUsuarioId,denunciante_id:usuarioAtual.id,motivo,descricao:document.getElementById("denuncia-desc").value}), "Não foi possível enviar a denúncia.");
  if (ok === null) return;
  document.getElementById("modal-denuncia").style.display="none";
  alert("✅ Denúncia enviada. Analisaremos em breve.");
});

document.querySelectorAll(".estrela").forEach(e => {
  e.style.cursor="pointer"; e.style.fontSize="28px"; e.style.color="#ddd";
  e.addEventListener("mouseover", () => { document.querySelectorAll(".estrela").forEach((s,i)=>s.style.color=i<Number(e.dataset.v)?"#ffd700":"#ddd"); });
  e.addEventListener("mouseout", () => { document.querySelectorAll(".estrela").forEach((s,i)=>s.style.color=i<notaEscolhida?"#ffd700":"#ddd"); });
  e.addEventListener("click", () => { notaEscolhida=Number(e.dataset.v); document.querySelectorAll(".estrela").forEach((s,i)=>s.style.color=i<notaEscolhida?"#ffd700":"#ddd"); });
});

document.getElementById("btn-enviar-avaliacao")?.addEventListener("click", async () => {
  if (!usuarioAtual) { alert("Faça login para avaliar."); return; }
  if (!notaEscolhida) { alert("Selecione uma nota."); return; }
  const { error } = await supabase.from("avaliacoes").upsert({avaliador_id:usuarioAtual.id,avaliado_id:perfilUsuarioId,nota:notaEscolhida,comentario:document.getElementById("avaliacao-comentario").value},{onConflict:"avaliador_id,avaliado_id"});
  if (error) { alert("Erro: "+error.message); return; }
  const { data: avals } = await supabase.from("avaliacoes").select("nota").eq("avaliado_id",perfilUsuarioId);
  if (avals?.length) {
    const media = avals.reduce((s,a)=>s+a.nota,0)/avals.length;
    // Atualização derivada da média — falha aqui não bloqueia o usuário, mas é avisada no console.
    const { error: errMedia } = await supabase.from("usuarios").update({nota_media:media,total_avaliacoes:avals.length}).eq("id",perfilUsuarioId);
    if (errMedia) console.error("Falha ao atualizar média do avaliado:", errMedia.message);
  }
  alert("⭐ Avaliação enviada!");
});

document.getElementById("btnEditarFoto").addEventListener("click", ()=>document.getElementById("uploadFoto").click());
document.getElementById("btnEditarCapa").addEventListener("click", ()=>document.getElementById("uploadCapa").click());

document.getElementById("uploadFoto").addEventListener("change", async e => {
  const file = e.target.files[0]; if (!file||!usuarioAtual) return;
  if (!file.type.startsWith('image/')||file.size>5*1024*1024) { alert("Imagem inválida ou > 5MB"); return; }
  const cam = `perfil/${usuarioAtual.id}/foto_${Date.now()}.jpg`;
  const { error: ue } = await supabase.storage.from("fotos-perfil").upload(cam, file);
  if (ue) { alert("Erro: "+ue.message); return; }
  const { data: u } = supabase.storage.from("fotos-perfil").getPublicUrl(cam);
  const ok = await executarOuAvisar(supabase.from("usuarios").update({foto:u.publicUrl}).eq("id",usuarioAtual.id), "Não foi possível salvar a foto de perfil.");
  if (ok === null) return;
  fotoPerfil.src=u.publicUrl; document.getElementById("header-foto").src=u.publicUrl; alert("Foto atualizada!");
});

document.getElementById("uploadCapa").addEventListener("change", async e => {
  const file = e.target.files[0]; if (!file||!usuarioAtual) return;
  const cam = `perfil/${usuarioAtual.id}/capa_${Date.now()}.jpg`;
  const { error: ue } = await supabase.storage.from("fotos-perfil").upload(cam, file);
  if (ue) { alert("Erro no upload da capa: "+ue.message); return; }
  const { data: u } = supabase.storage.from("fotos-perfil").getPublicUrl(cam);
  const ok = await executarOuAvisar(supabase.from("usuarios").update({capa_foto:u.publicUrl}).eq("id",usuarioAtual.id), "Não foi possível salvar a capa.");
  if (ok === null) return;
  capaFoto.src=u.publicUrl; alert("Capa atualizada!");
});

document.getElementById("form-dados")?.addEventListener("submit", async e => {
  e.preventDefault(); if (!usuarioAtual) return;
  const { error } = await supabase.from("usuarios").update({nome:document.getElementById("nome").value,idade:document.getElementById("idade").value?Number(document.getElementById("idade").value):null,cidade:document.getElementById("cidade").value,estado:document.getElementById("estado").value,telefone:document.getElementById("telefone").value,bio:document.getElementById("bio").value,instagram:document.getElementById("instagram").value,site:document.getElementById("site").value,atualizado_em:new Date().toISOString()}).eq("id",usuarioAtual.id);
  if (error) { alert("Erro: "+error.message); return; }
  alert("Dados salvos!"); nomeExibido.textContent = document.getElementById("nome").value;
});

document.getElementById("excluirConta")?.addEventListener("click", async () => {
  if (!confirm("Excluir conta permanentemente?")) return;
  const ok = await executarOuAvisar(supabase.from("usuarios").delete().eq("id",usuarioAtual.id), "Não foi possível excluir a conta.");
  if (ok === null) return;
  await supabase.auth.signOut(); alert("Conta excluída"); window.location.href="../MG-LOGIN/login.html";
});

async function carregarDadosForm() {
  if (!usuarioAtual) return;
  // Melhoria 1: maybeSingle() — perfil do próprio usuário pode não ter sido criado ainda.
  const { data } = await supabase.from("usuarios").select("*").eq("id",usuarioAtual.id).maybeSingle();
  if (data) {
    document.getElementById("nome").value = data.nome||"";
    document.getElementById("idade").value = data.idade||"";
    document.getElementById("cidade").value = data.cidade||"";
    document.getElementById("estado").value = data.estado||"";
    document.getElementById("telefone").value = data.telefone||"";
    document.getElementById("bio").value = data.bio||"";
    document.getElementById("instagram").value = data.instagram||"";
    document.getElementById("site").value = data.site||"";
    document.getElementById("email").value = usuarioAtual.email||"";
    document.getElementById("dataCriacao").value = usuarioAtual.created_at?new Date(usuarioAtual.created_at).toLocaleDateString("pt-BR"):"";
  }
}

document.querySelectorAll(".tab-btn[data-tab]").forEach(btn => {
  btn.addEventListener("click", () => {
    document.querySelectorAll(".tab-btn[data-tab]").forEach(b=>b.classList.remove("active"));
    document.querySelectorAll("#tabs-proprio .tab-content").forEach(c=>c.classList.remove("active"));
    btn.classList.add("active"); document.getElementById(`tab-${btn.dataset.tab}`).classList.add("active");
  });
});
document.querySelectorAll(".tab-btn[data-tab-outro]").forEach(btn => {
  btn.addEventListener("click", () => {
    document.querySelectorAll(".tab-btn[data-tab-outro]").forEach(b=>b.classList.remove("active"));
    document.querySelectorAll("#tabs-outro .tab-content").forEach(c=>c.classList.remove("active"));
    btn.classList.add("active"); document.getElementById(`tab-${btn.dataset.tabOutro}`).classList.add("active");
    if (btn.dataset.tabOutro === "fotos-outro") {
      const uid = new URLSearchParams(location.search).get("id");
      carregarPostsOutro(uid);
    }
  });
});

async function carregarPostsOutro(uid) {
  const grid = document.getElementById("posts-grid-outro"); if (!grid) return;
  grid.innerHTML = '<p style="grid-column:1/-1;text-align:center;color:#888;font-size:13px;">Carregando...</p>';
  const { data } = await supabase.from("posts_usuario").select("*").eq("usuario_id", uid).order("criado_em", {ascending: false});
  if (!data || data.length === 0) { grid.innerHTML = '<p style="grid-column:1/-1;text-align:center;color:#888;font-size:13px;padding:30px 0;">Nenhuma foto publicada ainda.</p>'; return; }
  grid.innerHTML = data.map(p => `
    <div class="post-card-outro" data-id="${escapeHtml(p.id)}" data-imagem="${escapeHtml(p.imagem)}" data-legenda="${escapeHtml(p.legenda || '')}" data-curtidas="${Number(p.curtidas || 0)}" style="aspect-ratio:1;overflow:hidden;border-radius:8px;cursor:pointer;background:#eee;">
      <img src="${escapeHtml(p.imagem)}" style="width:100%;height:100%;object-fit:cover;" loading="lazy">
    </div>
  `).join('');
  grid.querySelectorAll(".post-card-outro").forEach(el => {
    el.addEventListener("click", () => {
      abrirFotoPostEl(el.dataset.id, el.dataset.imagem, el.dataset.legenda, el.dataset.curtidas);
    });
  });
}

async function abrirModalSeguidores(tipo) {
  const modal = document.getElementById("modal-seguidores");
  const lista = document.getElementById("modal-seg-lista");
  const titulo = document.getElementById("modal-seg-titulo");
  titulo.textContent = tipo === 'seguidores' ? '👥 Seguidores' : '👣 Seguindo';
  lista.innerHTML = '<p style="text-align:center;color:#888;">Carregando...</p>';
  modal.style.display = 'flex';
  let users = [];
  if (tipo === 'seguidores') {
    const { data } = await supabase.from("seguidores").select("seguidor_id, usuarios!seguidor_id(id,nome,foto,cidade)").eq("seguido_id", perfilUsuarioId);
    users = data?.map(r => r.usuarios) || [];
  } else {
    const { data } = await supabase.from("seguidores").select("seguido_id, usuarios!seguido_id(id,nome,foto,cidade)").eq("seguidor_id", perfilUsuarioId);
    users = data?.map(r => r.usuarios) || [];
  }
  if (!users.length) { lista.innerHTML = '<p style="text-align:center;color:#888;">Nenhum usuário aqui ainda.</p>'; return; }
  lista.innerHTML = users.map(u => `
    <a href="conta.html?id=${u.id}" style="display:flex;align-items:center;gap:12px;padding:10px;border-radius:12px;border:1.5px solid rgba(20,75,113,.1);text-decoration:none;color:inherit;transition:background .2s;" onmouseover="this.style.background='rgba(20,75,113,.05)'" onmouseout="this.style.background=''">
      <img src="${u.foto||'../imagens/usuario.png'}" style="width:42px;height:42px;border-radius:50%;object-fit:cover;" onerror="this.src='../imagens/usuario.png'">
      <div><div style="font-weight:800;font-size:14px;color:#144b71;">${escapeHtml(u.nome)||'Usuário'}</div>${u.cidade?`<div style="font-size:12px;color:#888;">${escapeHtml(u.cidade)}</div>`:''}</div>
    </a>
  `).join('');
}

document.getElementById("stat-seguidores").addEventListener("click", () => abrirModalSeguidores('seguidores'));
document.getElementById("stat-seguindo").addEventListener("click", () => abrirModalSeguidores('seguindo'));

// ---- FOTOS / POSTS ----
async function carregarPostsFotos() {
  const uid = new URLSearchParams(location.search).get("id") || usuarioAtual?.id;
  if (!uid) return;
  const grid = document.getElementById("posts-grid");
  if (!grid) return;
  grid.innerHTML = '<p style="grid-column:1/-1;text-align:center;color:#888;font-size:13px;">Carregando...</p>';
  const { data } = await supabase.from("posts_usuario").select("*").eq("usuario_id", uid).order("criado_em", {ascending: false});
  if (!data || data.length === 0) {
    grid.innerHTML = '<p style="grid-column:1/-1;text-align:center;color:#888;font-size:13px;padding:30px 0;">Nenhuma foto publicada ainda.</p>'; return;
  }
  grid.innerHTML = data.map(p => `
    <div class="post-card" data-id="${escapeHtml(p.id)}" data-imagem="${escapeHtml(p.imagem)}" data-legenda="${escapeHtml(p.legenda || '')}" data-curtidas="${Number(p.curtidas || 0)}" style="position:relative;aspect-ratio:1;overflow:hidden;border-radius:8px;cursor:pointer;background:#eee;">
      <img src="${escapeHtml(p.imagem)}" style="width:100%;height:100%;object-fit:cover;" loading="lazy">
      <div style="position:absolute;bottom:0;left:0;right:0;background:linear-gradient(transparent,rgba(0,0,0,.55));padding:8px 10px;color:#fff;font-size:12px;display:flex;gap:6px;align-items:center;">
        <span>❤️ ${Number(p.curtidas||0)}</span>
      </div>
      ${uid === usuarioAtual?.id ? `<button class="post-card-excluir" data-id="${escapeHtml(p.id)}" style="position:absolute;top:6px;right:6px;background:rgba(0,0,0,.5);color:#fff;border:none;border-radius:50%;width:26px;height:26px;cursor:pointer;font-size:13px;display:flex;align-items:center;justify-content:center;">✕</button>` : ''}
    </div>
  `).join('');
  grid.querySelectorAll(".post-card").forEach(el => {
    el.addEventListener("click", () => {
      abrirFotoPostEl(el.dataset.id, el.dataset.imagem, el.dataset.legenda, el.dataset.curtidas);
    });
  });
  grid.querySelectorAll(".post-card-excluir").forEach(btn => {
    btn.addEventListener("click", (e) => {
      e.stopPropagation();
      excluirPost(btn.dataset.id, btn.closest(".post-card"));
    });
  });
}

async function excluirPost(id, card) {
  if (!confirm("Excluir esta foto?")) return;
  const ok = await executarOuAvisar(supabase.from("posts_usuario").delete().eq("id", id), "Não foi possível excluir a foto.");
  if (ok === null) return;
  card?.remove();
}

function abrirFotoPostEl(id, imagem, legenda, curtidas) {
  document.getElementById("modal-foto-post-img").src = imagem;
  document.getElementById("modal-foto-post-legenda").textContent = legenda || '';
  document.getElementById("modal-foto-post-curtidas").textContent = '❤️ ' + curtidas;
  document.getElementById("modal-foto-post").style.display = 'flex';
};

// Upload nova foto/post (função nomeada para poder re-anexar o listener após recriar o input)
async function handleUploadPostFoto(e) {
  const file = e.target.files[0]; if (!file || !usuarioAtual) return;
  if (file.size > 5 * 1024 * 1024) { alert("Foto muito grande. Máximo: 5MB."); return; }
  const legenda = prompt("Adicione uma legenda (opcional):") || '';
  const btn = document.getElementById("btn-nova-foto");
  btn.textContent = "⏳ Enviando...";
  const ext = file.name.split('.').pop();
  const path = `posts/${usuarioAtual.id}/${Date.now()}.${ext}`;
  const { data: up, error } = await supabase.storage.from("fotos-perfil").upload(path, file, {upsert: true});
  if (error) { alert("Erro ao enviar: " + error.message); btn.innerHTML = '📷 Publicar Foto<input type="file" id="upload-post-foto" accept="image/*" style="display:none">'; reatacharUploadFoto(); return; }
  const { data: url } = supabase.storage.from("fotos-perfil").getPublicUrl(path);
  const okPost = await executarOuAvisar(supabase.from("posts_usuario").insert({ usuario_id: usuarioAtual.id, imagem: url.publicUrl, legenda, curtidas: 0 }), "Não foi possível publicar a foto.");
  if (okPost === null) { btn.innerHTML = '📷 Publicar Foto<input type="file" id="upload-post-foto" accept="image/*" style="display:none">'; reatacharUploadFoto(); return; }
  btn.innerHTML = '📷 Publicar Foto<input type="file" id="upload-post-foto" accept="image/*" style="display:none">';
  reatacharUploadFoto();
  carregarPostsFotos();
}
function reatacharUploadFoto() {
  document.getElementById("upload-post-foto")?.addEventListener("change", handleUploadPostFoto);
}
reatacharUploadFoto();

// Tab switch — carregar fotos ao abrir tab
const tabOriginal = document.querySelectorAll(".tab-btn[data-tab]");
tabOriginal.forEach(btn => {
  btn.addEventListener("click", () => {
    if (btn.dataset.tab === "fotos") carregarPostsFotos();
  });
});

await carregarDadosForm();
await carregarPerfil();
