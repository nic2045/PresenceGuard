#!/usr/bin/env bash
# PresenceGuard – Access Token erneuern (von HA per shell_command aufgerufen).
#
# Unterstützt BEIDE Auth-Wege und wählt automatisch:
#
#   1) DELEGIERT (Authorization Code Flow): Liegt ein Refresh Token vor
#      (rotiert in /config/presence_refresh_token.txt oder initial aus
#      secrets.yaml: presence_refresh_token), wird grant_type=refresh_token
#      genutzt. Entra rotiert den Refresh Token – der neue wird persistiert.
#      Berechtigung: delegated Presence.ReadWrite (kein Admin-Consent nötig).
#      Vorbereitung: einmalig token_setup.sh ausführen.
#
#   2) APP-ONLY (Client Credentials Flow): Ist KEIN Refresh Token vorhanden,
#      aber ein client_secret, wird grant_type=client_credentials genutzt.
#      Berechtigung: application Presence.ReadWrite.All (Admin-Consent nötig).
#      Kein interaktiver Login, kein token_setup.sh.
#
# Das Ergebnis ist in beiden Fällen /config/presence_token.json mit
# access_token + user_id + Zeitstempel.
#
# Voraussetzungen: bash, curl. (jq optional.)

set -euo pipefail

SECRETS_FILE="${SECRETS_FILE:-/config/secrets.yaml}"
TOKEN_FILE="${TOKEN_FILE:-/config/presence_token.json}"
REFRESH_FILE="${REFRESH_FILE:-/config/presence_refresh_token.txt}"
SCOPE_DELEGATED="offline_access openid profile Presence.ReadWrite"
SCOPE_APP="https://graph.microsoft.com/.default"

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

TOKEN_ENDPOINT="https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/token"
NEW_REFRESH=""

# --- Modus wählen ------------------------------------------------------------
if [ -n "$REFRESH_TOKEN" ]; then
  # ----- (1) DELEGIERT: Refresh Token Flow -----------------------------------
  set -- \
    -d "client_id=${CLIENT_ID}" \
    -d "grant_type=refresh_token" \
    -d "refresh_token=${REFRESH_TOKEN}" \
    --data-urlencode "scope=${SCOPE_DELEGATED}"

  # Client Secret nur anhängen, wenn als Confidential Client konfiguriert.
  if [ -n "$CLIENT_SECRET" ]; then
    set -- "$@" --data-urlencode "client_secret=${CLIENT_SECRET}"
  fi

  RESP="$(curl -sS -X POST "$TOKEN_ENDPOINT" "$@")"
  NEW_REFRESH="$(printf '%s' "$RESP" | json_get refresh_token)"
else
  # ----- (2) APP-ONLY: Client Credentials Flow -------------------------------
  if [ -z "$CLIENT_SECRET" ]; then
    echo "FEHLER: Kein Refresh Token UND kein Client Secret gefunden." >&2
    echo "Entweder token_setup.sh ausführen (delegiert) oder presence_client_secret" >&2
    echo "in secrets.yaml setzen (App-only). Siehe entra_app_setup.md." >&2
    exit 1
  fi

  RESP="$(curl -sS -X POST "$TOKEN_ENDPOINT" \
    -d "client_id=${CLIENT_ID}" \
    -d "grant_type=client_credentials" \
    --data-urlencode "client_secret=${CLIENT_SECRET}" \
    --data-urlencode "scope=${SCOPE_APP}")"
fi

ACCESS_TOKEN="$(printf '%s' "$RESP" | json_get access_token)"

if [ -z "$ACCESS_TOKEN" ]; then
  echo "FEHLER: Kein access_token erhalten. Antwort:" >&2
  printf '%s\n' "$RESP" >&2
  exit 1
fi

# --- user_id auflösen --------------------------------------------------------
if [ -n "$REFRESH_TOKEN" ]; then
  # DELEGIERT: Nur der ANGEMELDETE Nutzer darf seinen Status setzen. Steht in
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
else
  # APP-ONLY: kein /me. Ist presence_user_id eine UPN (enthält @), in die
  # Object ID auflösen (GET /users/{upn}). Das braucht zusätzlich die
  # Application-Permission User.Read.All (Admin-Consent). Schlägt es fehl, wird
  # die UPN unverändert weiterverwendet.
  case "$USER_ID" in
    *@*)
      RESOLVED_ID="$(curl -sS -H "Authorization: Bearer ${ACCESS_TOKEN}" \
        "https://graph.microsoft.com/v1.0/users/${USER_ID}" | json_get id)"
      if [ -n "$RESOLVED_ID" ]; then
        echo "UPN $USER_ID -> Object ID $RESOLVED_ID aufgelöst." >&2
        USER_ID="$RESOLVED_ID"
      else
        echo "Hinweis: UPN $USER_ID konnte nicht in eine Object ID aufgelöst werden" >&2
        echo "(fehlt User.Read.All? Admin-Consent?). Nutze UPN unverändert." >&2
      fi
      ;;
  esac
fi

# --- Persistieren ------------------------------------------------------------
# Rotierten Refresh Token sichern (nur im delegierten Modus relevant).
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
