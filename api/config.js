// api/config.js
//
// Endpoint público que entrega a configuração do Supabase (URL e chave
// publishable/anon) para o front-end estático. Os valores vêm das variáveis
// de ambiente da Vercel (SUPABASE_URL e SUPABASE_KEY), então não ficam no
// código. A chave é pública por natureza — a segurança real está nas
// policies de RLS do banco.

export default async function handler(req, res) {
  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseKey = process.env.SUPABASE_KEY;

  if (!supabaseUrl || !supabaseKey) {
    return res.status(500).json({
      error: "Variáveis SUPABASE_URL e/ou SUPABASE_KEY não definidas na Vercel."
    });
  }

  res.setHeader("Cache-Control", "no-store");
  return res.status(200).json({ supabaseUrl, supabaseKey });
}
