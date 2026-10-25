#!/usr/bin/env bash
# =============================================================================
# MGMOTORS — Roteiro de teste de segurança (RLS / Storage / RPC)
# -----------------------------------------------------------------------------
# ⚠️  STAGING ONLY. NÃO RODE AS SEÇÕES [5]–[7] CONTRA PRODUÇÃO.
#     A seção [6] apaga e recria o perfil do usuário de teste; a [7] grava e
#     apaga um arquivo no Storage. Use um projeto Supabase descartável e uma
#     conta de teste criada só para isso.
#
# Uso:
#   export SUPABASE_URL="https://SEU-PROJETO-STAGING.supabase.co"
#   export SUPABASE_ANON_KEY="sb_publishable_..."
#   ./supabase/tests/rls-security-check.sh
#
# Resultado: cada linha imprime PASS (seguro) ou FAIL (vulnerável).
# Use este roteiro ANTES e DEPOIS das correções — ele é a evidência de que a
# Row Level Security realmente isola os dados entre usuários.
#
# Requer: curl. Por padrão, nenhum dado real é alterado. O teste de escalação
# de privilégio da seção [6] é destrutivo por desenho e só roda quando
# ALLOW_DESTRUCTIVE_PROBES=1 E CONFIRM_STAGING=1 forem informados.
# =============================================================================
set -uo pipefail

# --- trava de segurança: sondas destrutivas só em staging declarado ---------
if [ "${ALLOW_DESTRUCTIVE_PROBES:-}" = "1" ] && [ "${CONFIRM_STAGING:-}" != "1" ]; then
  printf '\033[31mABORTADO:\033[0m ALLOW_DESTRUCTIVE_PROBES=1 exige CONFIRM_STAGING=1.\n'
  printf 'Confirme que SUPABASE_URL aponta para um projeto descartável de staging.\n'
  exit 2
fi

URL="${SUPABASE_URL:-}"
KEY="${SUPABASE_ANON_KEY:-}"

if [ -z "$URL" ] || [ -z "$KEY" ]; then
  printf '\033[31mABORTADO:\033[0m informe SUPABASE_URL e SUPABASE_ANON_KEY de um projeto de staging.\n'
  printf 'Exemplo: SUPABASE_URL=https://staging.supabase.co SUPABASE_ANON_KEY=sb_publishable_... ./supabase/tests/rls-security-check.sh\n'
  exit 2
fi

if [[ "$URL" == *"ilswwmjojfuvcgyymymb"* ]]; then
  printf '\033[31mABORTADO:\033[0m o projeto MGMOTORS de produção não pode ser usado neste roteiro.\n'
  exit 2
fi

PASS=0; FAIL=0
VERMELHO=$'\033[31m'; VERDE=$'\033[32m'; AMARELO=$'\033[33m'; RESET=$'\033[0m'

# --- helpers -----------------------------------------------------------------
anon() { # anon <METHOD> <path> [data]
  local m=$1 p=$2 d=${3:-}
  if [ -n "$d" ]; then
    curl -s -o /dev/null -w '%{http_code}' -X "$m" "$URL$p" \
      -H "apikey: $KEY" -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" -d "$d"
  else
    curl -s -o /dev/null -w '%{http_code}' -X "$m" "$URL$p" \
      -H "apikey: $KEY" -H "Authorization: Bearer $KEY"
  fi
}
auth() { # auth <METHOD> <path> [data]  (usa $AUTH_TOKEN)
  local m=$1 p=$2 d=${3:-}
  if [ -n "$d" ]; then
    curl -s -o /dev/null -w '%{http_code}' -X "$m" "$URL$p" \
      -H "apikey: $KEY" -H "Authorization: Bearer $AUTH_TOKEN" -H "Content-Type: application/json" -d "$d"
  else
    curl -s -o /dev/null -w '%{http_code}' -X "$m" "$URL$p" \
      -H "apikey: $KEY" -H "Authorization: Bearer $AUTH_TOKEN"
  fi
}
body() { # body <path> [anon|auth]
  local p=$1 mode=${2:-anon}
  if [ "$mode" = "auth" ]; then
    curl -s "$URL$p" -H "apikey: $KEY" -H "Authorization: Bearer $AUTH_TOKEN"
  else
    curl -s "$URL$p" -H "apikey: $KEY" -H "Authorization: Bearer $KEY"
  fi
}

check() { # check <rótulo> <código Obtido> <códigos aceitáveis...>
  local label=$1 got=$2; shift 2
  for ok in "$@"; do
    if [ "$got" = "$ok" ]; then
      printf '  %sPASS%s  %-58s (HTTP %s)\n' "$VERDE" "$RESET" "$label" "$got"
      PASS=$((PASS+1)); return
    fi
  done
  printf '  %sFAIL%s  %-58s (HTTP %s)\n' "$VERMELHO" "$RESET" "$label" "$got"
  FAIL=$((FAIL+1))
}
check_empty() { # check_empty <rótulo> <json>  (espera array vazio)
  local label=$1 json=$2
  if [ "$(echo "$json" | tr -d '[:space:]')" = "[]" ]; then
    printf '  %sPASS%s  %-58s (vazio)\n' "$VERDE" "$RESET" "$label"
    PASS=$((PASS+1))
  else
    printf '  %sFAIL%s  %-58s (retornou dados)\n' "$VERMELHO" "$RESET" "$label"
    FAIL=$((FAIL+1))
  fi
}

# affected <METHOD> <path> [data]
#   Executa a escrita e devolve QUANTAS LINHAS foram afetadas de fato.
#   Isso evita o falso-positivo clássico: HTTP 204 significa "sucesso", mas
#   também pode significar "0 linhas casaram com o filtro" — ou seja, nada
#   provou que a policy deixou passar.
affected() {
  local m=$1 p=$2 d=${3:-}
  local hdr
  if [ -n "$d" ]; then
    hdr=$(curl -s -D - -o /dev/null -X "$m" "$URL$p" \
      -H "apikey: $KEY" -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
      -H "Prefer: count=exact" -H "Prefer: return=representation" -d "$d")
  else
    hdr=$(curl -s -D - -o /dev/null -X "$m" "$URL$p" \
      -H "apikey: $KEY" -H "Authorization: Bearer $KEY" \
      -H "Prefer: count=exact" -H "Prefer: return=representation")
  fi
  echo "$hdr" | grep -i '^content-range' | tr -d '\r' | sed 's|.*/||' | sed 's|\*||'
}
check_write_blocked() { # check_write_blocked <rótulo> <linhas afetadas>
  local label=$1 n=$2
  if [ "$n" = "0" ] || [ -z "$n" ]; then
    printf '  %sPASS%s  %-58s (0 linhas afetadas)\n' "$VERDE" "$RESET" "$label"
    PASS=$((PASS+1))
  else
    printf '  %sFAIL%s  %-58s (%s linhas afetadas!)\n' "$VERMELHO" "$RESET" "$label" "$n"
    FAIL=$((FAIL+1))
  fi
}
visible_rows() { # visible_rows <tabela> <colunas>
  curl -s -I "$URL/rest/v1/$1?select=$2&limit=1" -H "apikey: $KEY" -H "Authorization: Bearer $KEY" \
    -H "Prefer: count=exact" | grep -i '^content-range' | tr -d '\r' | sed 's|.*/||' | sed 's|\*||'
}

FAKE="00000000-0000-0000-0000-000000000000"

# --- restauração do perfil de teste (proteção da seção [6]) ------------------
PERFIL_ANTES=""
PERFIL_REMOVIDO=0

restaurar_perfil() {
  [ "$PERFIL_REMOVIDO" = "1" ] || return 0
  [ -n "$PERFIL_ANTES" ] || return 0
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$URL/rest/v1/usuarios" \
    -H "apikey: $KEY" -H "Authorization: Bearer $AUTH_TOKEN" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d "$PERFIL_ANTES")
  case "$code" in
    200|201|204)
      PERFIL_REMOVIDO=0
      printf '  %sINFO%s  perfil de teste restaurado a partir da captura "before".\n' "$VERDE" "$RESET"
      ;;
    409)
      # O DELETE pode ter sido bloqueado pelo RLS; nesse caso o perfil original
      # continua no lugar e não há nada a restaurar.
      PERFIL_REMOVIDO=0
      printf '  %sINFO%s  perfil de teste já existia; nada a restaurar.\n' "$VERDE" "$RESET"
      ;;
    *)
      printf '  %sAVISO%s  não foi possível restaurar o perfil de teste (HTTP %s).\n' "$AMARELO" "$RESET" "$code"
      printf '         Recrie manualmente a conta de teste antes de usá-la novamente.\n'
      ;;
  esac
}

cleanup() { restaurar_perfil; }
trap cleanup EXIT INT TERM

cat <<'BANNER'
================================================================================
 MGMOTORS — Teste de segurança (RLS / Storage / RPC)
================================================================================
BANNER

echo
echo "[1] ISOLAMENTO DE LEITURA (anônimo não deve ver dados privados)"
check_empty "anon SELECT usuarios (email/telefone)"      "$(body "/rest/v1/usuarios?select=email,telefone&limit=5")"
check_empty "anon SELECT usuarios_banidos"                "$(body "/rest/v1/usuarios_banidos?select=id&limit=5")"
check_empty "anon SELECT mensagens"                       "$(body "/rest/v1/mensagens?select=id&limit=5")"
check_empty "anon SELECT config_usuario"                  "$(body "/rest/v1/config_usuario?select=id&limit=5")"
check_empty "anon SELECT avaliacoes"                      "$(body "/rest/v1/avaliacoes?select=id&limit=5")"

# Fotos de anúncio: só podem ser vistas se o anúncio estiver ativo.
n_ads=$(visible_rows "anuncios" "id")
n_fotos=$(visible_rows "fotos_anuncio" "id")
if [ "${n_fotos:-0}" -le "${n_ads:-0}" ]; then
  printf '  %sPASS%s  %-58s (%s fotos / %s anuncios ativos)\n' "$VERDE" "$RESET" \
    "anon SELECT fotos_anuncio (só de anuncios ativos)" "$n_fotos" "$n_ads"
  PASS=$((PASS+1))
else
  printf '  %sFAIL%s  %-58s (%s fotos vs %s anuncios ativos)\n' "$VERMELHO" "$RESET" \
    "anon SELECT fotos_anuncio (só de anuncios ativos)" "$n_fotos" "$n_ads"
  FAIL=$((FAIL+1))
fi

echo
echo "[2] ISOLAMENTO DE ESCRITA (anônimo não pode alterar/apagar)"
# Usa contagem de linhas afetadas — status HTTP sozinho gera falso-positivo.
check_write_blocked "anon DELETE curtidas_anuncio"    "$(affected DELETE "/rest/v1/curtidas_anuncio?usuario_id=eq.$FAKE")"
check_write_blocked "anon DELETE projetos_curtidas"   "$(affected DELETE "/rest/v1/projetos_curtidas?user_id=eq.$FAKE")"
check_write_blocked "anon DELETE comunidade_curtidas" "$(affected DELETE "/rest/v1/comunidade_curtidas?user_id=eq.$FAKE")"
check_write_blocked "anon DELETE usuarios"            "$(affected DELETE "/rest/v1/usuarios?id=eq.$FAKE")"
check_write_blocked "anon DELETE fotos_anuncio"       "$(affected DELETE "/rest/v1/fotos_anuncio?id=eq.$FAKE")"
check_write_blocked "anon UPDATE anuncios"            "$(affected PATCH "/rest/v1/anuncios?id=eq.$FAKE" '{"status":"vendido"}')"
check_write_blocked "anon UPDATE usuarios"            "$(affected PATCH "/rest/v1/usuarios?id=eq.$FAKE" '{"moderador":true}')"
check_write_blocked "anon INSERT anuncios"            "$(affected POST "/rest/v1/anuncios" '{"usuario_id":"'$FAKE'","titulo":"x","preco":1}')"
check_write_blocked "anon INSERT comunidade_posts_fotos" "$(affected POST "/rest/v1/comunidade_posts_fotos" '{"post_id":"'$FAKE'","url":"http://x"}')"
check_write_blocked "anon INSERT avaliacoes"          "$(affected POST "/rest/v1/avaliacoes" '{"avaliador_id":"'$FAKE'","avaliado_id":"'$FAKE'","nota":5}')"

echo
echo "[3] FUNÇÕES RPC SENSÍVEIS"
check "anon RPC promover_moderador"     "$(anon POST "/rest/v1/rpc/promover_moderador" '{"p_email":"x@test.invalid"}')" 400 401 403
check "anon RPC criar_tabela_carrinho"   "$(anon POST "/rest/v1/rpc/criar_tabela_carrinho" '{}')" 400 401 403 404
check "anon RPC registrar_aceite_legal"  "$(anon POST "/rest/v1/rpc/registrar_aceite_legal" '{"p_terms_version":"1.0","p_privacy_version":"1.0"}')" 400 401 403

echo
echo "[4] STORAGE (anônimo não pode escrever)"
check "anon DELETE storage fotos-perfil" "$(anon DELETE "/storage/v1/object/fotos-perfil/perfil/$FAKE/x.jpg")" 400 401 403
check "anon PUT storage fotos-perfil"    "$(anon PUT "/storage/v1/object/fotos-perfil/perfil/$FAKE/x.jpg" '{"a":"b"}')" 400 401 403

# --- testes autenticados (opcionais) -----------------------------------------
if [ -n "${AUTH_TOKEN:-}" ] && [ -n "${AUTH_UID:-}" ]; then
  echo
  echo "[5] ISOLAMENTO ENTRE USUÁRIOS (sessão autenticada comum)"
  check_empty "auth SELECT usuarios de terceiros" "$(body "/rest/v1/usuarios?select=email&limit=5" auth)"
  check "auth DELETE usuarios de terceiro"  "$(auth DELETE "/rest/v1/usuarios?id=neq.$AUTH_UID")" 400 401 403

  if [ "${ALLOW_DESTRUCTIVE_PROBES:-}" = "1" ]; then
    echo
    echo "[6] ESCALAÇÃO DE PRIVILÉGIO (deve FALHAR)"
    echo "      (capturando perfil, executando carga e restaurando ao final...)"

    # Captura o perfil COMPLETO para restaurar exatamente o que existia.
    # Só use uma conta descartável: se ela for admin, as flags voltam false.
    PERFIL_ANTES=$(body "/rest/v1/usuarios?select=*&id=eq.$AUTH_UID" auth)
    PERFIL_REMOVIDO=1

    curl -s -o /dev/null -X DELETE "$URL/rest/v1/usuarios?id=eq.$AUTH_UID" \
      -H "apikey: $KEY" -H "Authorization: Bearer $AUTH_TOKEN"

    admin_code=$(auth POST "/rest/v1/usuarios" "{\"id\":\"$AUTH_UID\",\"email\":\"probe@test.invalid\",\"nome\":\"probe\",\"moderador\":true,\"is_admin\":true}")
    is_admin=$(body "/rest/v1/rpc/is_admin" auth)

    curl -s -o /dev/null -X DELETE "$URL/rest/v1/usuarios?id=eq.$AUTH_UID" \
      -H "apikey: $KEY" -H "Authorization: Bearer $AUTH_TOKEN"

    if [ "$is_admin" = "true" ]; then
      printf '  %sFAIL%s  %-58s (%s)\n' "$VERMELHO" "$RESET" "INSERT moderador=true nao pode conceder admin" "is_admin=true"
      FAIL=$((FAIL+1))
    else
      printf '  %sPASS%s  %-58s (is_admin=%s)\n' "$VERDE" "$RESET" "INSERT moderador=true nao pode conceder admin" "$is_admin"
      PASS=$((PASS+1))
    fi
    check "INSERT usuarios com moderador=true bloqueado" "$admin_code" 400 401 403 409

    # A restauração real acontece no trap de EXIT/INT/TERM.
    restaurar_perfil
  else
    printf '%s[6] Escalação de privilégio ignorada: requer ALLOW_DESTRUCTIVE_PROBES=1 e CONFIRM_STAGING=1.%s\n' "$AMARELO" "$RESET"
  fi

  if [ "${ALLOW_DESTRUCTIVE_PROBES:-}" = "1" ]; then
    echo
    echo "[7] STORAGE COM SESSAO AUTENTICADA (dono do path)"
    probe="perfil/$AUTH_UID/probe_rls_check.jpg"
    up=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$URL/storage/v1/object/fotos-perfil/$probe" \
          -H "apikey: $KEY" -H "Authorization: Bearer $AUTH_TOKEN" -H "Content-Type: image/jpeg" --data-binary "probe")
    check "auth POST no proprio path" "$up" 200 201
    rm=$(curl -s -o /dev/null -w '%{http_code}' -X DELETE "$URL/storage/v1/object/fotos-perfil/$probe" \
          -H "apikey: $KEY" -H "Authorization: Bearer $AUTH_TOKEN")
    check "auth DELETE no proprio path" "$rm" 200 204

    # Alheio: caminho de outro usuário (inexistente) não pode ser escrito
    up2=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$URL/storage/v1/object/fotos-perfil/perfil/$FAKE/probe_alheio.jpg" \
          -H "apikey: $KEY" -H "Authorization: Bearer $AUTH_TOKEN" -H "Content-Type: image/jpeg" --data-binary "probe")
    check "auth POST em path de TERCEIRO bloqueado" "$up2" 400 401 403
    curl -s -o /dev/null -X DELETE "$URL/storage/v1/object/fotos-perfil/perfil/$FAKE/probe_alheio.jpg" \
      -H "apikey: $KEY" -H "Authorization: Bearer $AUTH_TOKEN" >/dev/null 2>&1
  else
    printf '%s[7] Storage autenticado ignorado: requer ALLOW_DESTRUCTIVE_PROBES=1 e CONFIRM_STAGING=1.%s\n' "$AMARELO" "$RESET"
  fi
else
  echo
  printf '%s[5-7] Testes autenticados ignorados. Para rodar:%s\n' "$AMARELO" "$RESET"
  echo "    export AUTH_TOKEN=\"<access_token JWT>\""
  echo "    export AUTH_UID=\"<uuid do usuario>\""
  echo "    Somente em staging. [6]-[7] exigem ALLOW_DESTRUCTIVE_PROBES=1 e CONFIRM_STAGING=1."
fi

echo
echo "================================================================================"
printf ' Resultado: %s%d PASS%s  /  %s%d FAIL%s\n' "$VERDE" "$PASS" "$RESET" "$VERMELHO" "$FAIL" "$RESET"
echo "================================================================================"
[ "$FAIL" -eq 0 ] || exit 1
