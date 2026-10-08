export const CURRENT_TERMS_VERSION = "1.0";
export const CURRENT_PRIVACY_VERSION = "1.0";

export function consentimentoAtual(perfil) {
  return perfil?.terms_version === CURRENT_TERMS_VERSION
    && perfil?.privacy_version === CURRENT_PRIVACY_VERSION
    && Boolean(perfil?.terms_accepted_at)
    && Boolean(perfil?.privacy_accepted_at);
}

export async function registrarAceiteLegal(supabase) {
  return supabase.rpc("registrar_aceite_legal", {
    p_terms_version: CURRENT_TERMS_VERSION,
    p_privacy_version: CURRENT_PRIVACY_VERSION
  });
}
