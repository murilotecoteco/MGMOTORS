// arquivo: mgConfig.js
//
// Configuração central do Supabase. Todas as páginas devem importar
// supabaseUrl e supabaseKey daqui em vez de declarar os valores localmente.
//
// Os valores NÃO estão no código: vêm de variáveis de ambiente da Vercel
// (SUPABASE_URL e SUPABASE_KEY), expostas pelo endpoint /api/config.
// O top-level await faz toda página que importar este módulo aguardar a
// configuração chegar antes de executar.

// Valores sintaticamente válidos para permitir que a interface carregue em
// estado degradado quando o endpoint de configuração estiver indisponível.
// As chamadas ao Supabase falharão de forma controlada, mas a página não
// ficará em branco por causa de uma exceção no topo do módulo.
let config = {
  supabaseUrl: "https://config-indisponivel.invalid",
  supabaseKey: "config-indisponivel"
};
export let configError = null;
try {
  const res = await fetch("/api/config");
  if (!res.ok) throw new Error("/api/config respondeu " + res.status);
  config = await res.json();
} catch (e) {
  configError = e;
  console.error(
    "Não foi possível carregar a configuração do Supabase via /api/config. " +
    "A interface continuará em modo degradado.", e
  );
}

export const supabaseUrl = config.supabaseUrl;
export const supabaseKey = config.supabaseKey;

// --- Helper de segurança (anti-XSS) ---
// Escapa caracteres especiais de HTML antes de qualquer dado (vindo do banco
// ou do usuário) ser interpolado dentro de um innerHTML. Usar sempre que o
// valor não for controlado pelo próprio código (nome, email, cidade, motivo
// de denúncia, legenda de post, etc.).
export function escapeHtml(valor) {
  if (valor === null || valor === undefined) return "";
  return String(valor)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

// Aceita somente URLs HTTP(S) para imagens vindas do banco ou de uploads.
// Isso evita que valores como javascript:, data: ou blob: sejam colocados em
// atributos src. O retorno ainda deve passar por escapeHtml quando for usado
// dentro de innerHTML.
export function safeImageUrl(valor, fallback = "../imagens/image.webp") {
  const bruto = String(valor || "").trim();
  if (!bruto) return fallback;
  try {
    const url = new URL(bruto, window.location.href);
    if (url.protocol !== "http:" && url.protocol !== "https:") return fallback;
    return url.href;
  } catch {
    return fallback;
  }
}
