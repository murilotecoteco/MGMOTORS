// arquivo: mgConfig.js
//
// Configuração central do Supabase. Todas as páginas devem importar
// supabaseUrl e supabaseKey daqui em vez de declarar os valores localmente.
//
// Os valores NÃO estão no código: vêm de variáveis de ambiente da Vercel
// (SUPABASE_URL e SUPABASE_KEY), expostas pelo endpoint /api/config.
// O top-level await faz toda página que importar este módulo aguardar a
// configuração chegar antes de executar.

let config;
try {
  const res = await fetch("/api/config");
  if (!res.ok) throw new Error("/api/config respondeu " + res.status);
  config = await res.json();
} catch (e) {
  throw new Error(
    "Não foi possível carregar a configuração do Supabase via /api/config. " +
    "Verifique se as variáveis SUPABASE_URL e SUPABASE_KEY estão definidas na Vercel. (" + e.message + ")"
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
