// arquivo: mgConfig.js
//
// Configuração central do Supabase. Todas as páginas devem importar
// supabaseUrl e supabaseKey daqui em vez de declarar os valores localmente,
// para evitar divergência caso a chave ou o projeto mudem no futuro.

export const supabaseUrl = "https://ilswwmjojfuvcgyymymb.supabase.co";
export const supabaseKey = "sb_publishable_0vy8zcMmKEd8oomSUQvJ4Q_SMpqFcxD";

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
