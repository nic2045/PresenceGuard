#!/usr/bin/env bash
# PresenceGuard – Access Token via Refresh Token erneuern.
#
# Wird von Home Assistant per shell_command (alle ~30 Min + beim Start)
# aufgerufen. Liest die Zugangsdaten aus /config/secrets.yaml, holt einen
# frischen access_token und schreibt ihn nach /config/presence_token.json.
#
# Microsoft Entra rotiert Refresh Tokens: bei jeder Erneuerung kommt ein
# neuer refresh_token zurück. Diesen persistieren wir in
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
CLIENT_SECRET="$(secret_get presence_client_secret)"
TENANT_ID="$(secret_get presence_tenant_id)"
USER_ID="$(secret_get presence_user_id)"

# Rotierten Refresh Token bevorzugen, sonst initialen aus secrets.yaml
if [ -s "$REFRESH_FILE" ]; then
  REFRESH_TOKEN="$(tr -d '\r\n' < "$REFRESH_FILE")"
else
  REFRESH_TOKEN="$(secret_get presence_refresh_token)"
fi

if [ -z "$CLIENT_ID" ] || [ -z "$TENANT_ID" ] || [ -z "$REFRESH_TOKEN" ]; then
  echo "FEHLER: client_id, tenant_id oder refresh_token fehlt." >&2
  exit 1
fi

# --- Token-Request -----------------------------------------------------------
set -- \
  -d "client_id=${CLIENT_ID}" \
  -d "grant_type=refresh_token" \
  -d "refresh_token=${REFRESH_TOKEN}" \
  --data-urlencode "scope=${SCOPE}"

# Client Secret nur anhängen, wenn als Confidential Client konfiguriert.
if [ -n "$CLIENT_SECRET" ] && [ "$CLIENT_SECRET" != "REPLACE_OR_LEAVE_EMPTY" ]; then
  set -- "$@" --data-urlencode "client_secret=${CLIENT_SECRET}"
fi

RESP="$(curl -sS -X POST \
  "https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/token" \
  "$@")"

ACCESS_TOKEN="$(printf '%s' "$RESP" | json_get access_token)"
NEW_REFRESH="$(printf '%s' "$RESP" | json_get refresh_token)"

if [ -z "$ACCESS_TOKEN" ]; then
  echo "FEHLER: Kein access_token erhalten. Antwort:" >&2
  printf '%s\n' "$RESP" >&2
  exit 1
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
