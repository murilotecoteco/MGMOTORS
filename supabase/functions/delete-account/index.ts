import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  // Preflight CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Não autorizado: header Authorization ausente" }),
        { status: 401, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // Client com JWT do usuário — verifica identidade sem privilégio elevado
    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: authErr } = await userClient.auth.getUser();
    if (authErr || !user) {
      return new Response(
        JSON.stringify({ error: "Token inválido ou expirado. Faça login novamente." }),
        { status: 401, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // Admin client com service_role — só existe server-side, nunca exposto ao browser
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    // 1. Buscar caminhos das fotos para remover do Storage
    const { data: perfil } = await admin
      .from("usuarios")
      .select("foto, capa_foto")
      .eq("id", user.id)
      .maybeSingle();

    const fotoCaminhos: string[] = [];
    if (perfil?.foto) {
      const match = perfil.foto.match(/fotos-perfil\/(.+)$/);
      if (match) fotoCaminhos.push(match[1]);
    }
    if (perfil?.capa_foto) {
      const match = perfil.capa_foto.match(/fotos-perfil\/(.+)$/);
      if (match) fotoCaminhos.push(match[1]);
    }
    if (fotoCaminhos.length > 0) {
      await admin.storage.from("fotos-perfil").remove(fotoCaminhos);
    }

    // 2. Deletar linha do usuário (FKs ON DELETE CASCADE limpam o resto)
    await admin.from("usuarios").delete().eq("id", user.id);

    // 3. Deletar usuário do Auth — requer service_role
    const { error: delAuthErr } = await admin.auth.admin.deleteUser(user.id);
    if (delAuthErr) {
      return new Response(
        JSON.stringify({ error: "Falha ao remover conta do Auth: " + delAuthErr.message }),
        { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ success: true }),
      { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );

  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : "Erro interno desconhecido";
    return new Response(
      JSON.stringify({ error: msg }),
      { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }
});
