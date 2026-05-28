#!/usr/bin/env bash
# PresenceGuard – Access Token via Refresh Token erneuern.
#
# Wird von Home Assistant per shell_command (alle ~30 Min + beim Start)
# aufgerufen. Holt mit dem Refresh Token einen frischen access_token und
# schreibt ihn nach /config/presence_token.json.
#
# Auth-Modell: DELEGIERT (Authorization Code Flow, Berechtigung
# Presence.ReadWrite). Den Refresh Token besorgst du einmalig mit
# token_setup.sh (siehe README/entra_app_setup.md).
#
# Microsoft Entra rotiert Refresh Tokens: bei jeder Erneuerung kommt ein neuer
# refresh_token zurück. Diesen persistieren wir in
# /config/presence_refresh_token.txt und nutzen ihn beim nächsten Lauf
# bevorzugt vor dem (initialen) Wert aus secrets.yaml.
#
# Voraussetzungen: bash, curl. (jq optional.)

set -euo pipefail

SECRETS_FILE="${SECRETS_FILE:-/config/secrets.yaml}"
TOKEN_FILE="${TOKEN_FILE:-/config/presence_token.json}"
REFRESH_FILE="${REFRESH_FILE:-/config/presence_refresh_token.txt}"
SCOPE="offline_access openid profile Presence.ReadWrite"

# --- secrets.yaml-Wert auslesen (einfache key: "value" Zeilen) ---------------
secret_get() {
  grep -E "^[[:space:]]*${1}:" "$SECRETS_FILE" 2>/dev/null \
    | head -n1 \
    | sed -E "s/^[[:space:]]*${1}:[[:space:]]*//" \
    | sed -E 's/^["'\'']//; s/["'\'']$//' \
    | tr -d '\r'
}

# Platzhalterwerte aus dem Template als "leer" behandeln.
clean_value() {
  case "$1" in
    *REPLACE*) printf '' ;;
    *) printf '%s' "$1" ;;
  esac
}

json_get() {
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg k "$1" '.[$k] // empty'
  else
    sed -n 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1
  fi
}

if [ ! -r "$SECRETS_FILE" ]; then
  echo "FEHLER: secrets.yaml nicht lesbar: $SECRETS_FILE" >&2
  exit 1
fi

CLIENT_ID="$(secret_get presence_client_id)"
CLIENT_SECRET="$(clean_value "$(secret_get presence_client_secret)")"
TENANT_ID="$(secret_get presence_tenant_id)"
USER_ID="$(secret_get presence_user_id)"

# Rotierten Refresh Token bevorzugen, sonst initialen aus secrets.yaml.
REFRESH_TOKEN=""
if [ -s "$REFRESH_FILE" ]; then
  REFRESH_TOKEN="$(tr -d '\r\n' < "$REFRESH_FILE")"
else
  REFRESH_TOKEN="$(clean_value "$(secret_get presence_refresh_token)")"
fi

if [ -z "$CLIENT_ID" ] || [ -z "$TENANT_ID" ]; then
  echo "FEHLER: client_id oder tenant_id fehlt." >&2
  exit 1
fi

if [ -z "$REFRESH_TOKEN" ]; then
  echo "FEHLER: Kein Refresh Token gefunden." >&2
  echo "Einmalig token_setup.sh ausführen und presence_refresh_token in" >&2
  echo "secrets.yaml eintragen. Siehe entra_app_setup.md / README.md." >&2
  exit 1
fi

TOKEN_ENDPOINT="https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/token"

# --- Token-Request (Refresh Token Flow) --------------------------------------
set -- \
  -d "client_id=${CLIENT_ID}" \
  -d "grant_type=refresh_token" \
  -d "refresh_token=${REFRESH_TOKEN}" \
  --data-urlencode "scope=${SCOPE}"

# Client Secret nur anhängen, wenn die App ein Confidential Client ist
# (public client flows = No). Beim empfohlenen Public-Client-/PKCE-Weg leer.
if [ -n "$CLIENT_SECRET" ]; then
  set -- "$@" --data-urlencode "client_secret=${CLIENT_SECRET}"
fi

RESP="$(curl -sS -X POST "$TOKEN_ENDPOINT" "$@")"

ACCESS_TOKEN="$(printf '%s' "$RESP" | json_get access_token)"
NEW_REFRESH="$(printf '%s' "$RESP" | json_get refresh_token)"

if [ -z "$ACCESS_TOKEN" ]; then
  echo "FEHLER: Kein access_token erhalten. Antwort:" >&2
  printf '%s\n' "$RESP" >&2
  exit 1
fi

# --- user_id automatisch auflösen --------------------------------------------
# Delegiert darf nur der ANGEMELDETE Nutzer seinen Status setzen. Steht in
# secrets.yaml z. B. eine UPN, die Graph auf ein anderes Objekt auflöst, gibt
# es 401 "Cannot set the presence of another user". Daher die echte Object ID
# des angemeldeten Kontos via /me holen und verwenden.
ME_ID="$(curl -sS -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  "https://graph.microsoft.com/v1.0/me" | json_get id)"
if [ -n "$ME_ID" ]; then
  if [ -n "$USER_ID" ] && [ "$USER_ID" != "$ME_ID" ]; then
    echo "Hinweis: presence_user_id ($USER_ID) != angemeldeter Nutzer ($ME_ID) – nutze angemeldeten Nutzer." >&2
  fi
  USER_ID="$ME_ID"
fi

# --- Persistieren ------------------------------------------------------------
# Rotierten Refresh Token sichern (falls einer zurückkam).
if [ -n "$NEW_REFRESH" ]; then
  umask 077
  printf '%s' "$NEW_REFRESH" > "${REFRESH_FILE}.tmp"
  mv "${REFRESH_FILE}.tmp" "$REFRESH_FILE"
fi

# Access Token + user_id für die rest_command-Sensoren ablegen.
# user_id wird mitgespeichert, damit rest_commands.yaml ohne !secret auskommt.
TS="$(date +%s)"
umask 077
printf '{"access_token":"%s","user_id":"%s","ts":"%s"}' \
  "$ACCESS_TOKEN" "$USER_ID" "$TS" > "${TOKEN_FILE}.tmp"
mv "${TOKEN_FILE}.tmp" "$TOKEN_FILE"

echo "OK: access_token erneuert ($(date '+%Y-%m-%d %H:%M:%S'))."
