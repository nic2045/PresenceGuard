#!/usr/bin/env bash
# PresenceGuard – einmaliger Token-Grab via OAuth2 Device Code Flow.
#
# Holt interaktiv einen Refresh Token für die delegierte Berechtigung
# Presence.ReadWrite. Du führst dieses Script EINMAL manuell aus (lokal auf
# deinem Rechner oder per SSH-Add-on auf dem HA-Host). Den ausgegebenen
# refresh_token trägst du anschließend in secrets.yaml ein
# (Key: presence_refresh_token).
#
# Voraussetzungen: bash, curl. (jq ist optional – wird genutzt wenn vorhanden.)
#
# Aufruf:
#   TENANT_ID=... CLIENT_ID=... ./token_setup.sh
# oder einfach ohne Variablen starten und die Werte eingeben.

set -euo pipefail

SCOPE="offline_access openid profile Presence.ReadWrite"

# --- Eingaben einsammeln -----------------------------------------------------
TENANT_ID="${TENANT_ID:-}"
CLIENT_ID="${CLIENT_ID:-}"

if [ -z "$TENANT_ID" ]; then
  printf 'Tenant ID (Directory ID): '
  read -r TENANT_ID
fi
if [ -z "$CLIENT_ID" ]; then
  printf 'Client ID (Application ID): '
  read -r CLIENT_ID
fi

if [ -z "$TENANT_ID" ] || [ -z "$CLIENT_ID" ]; then
  echo "FEHLER: TENANT_ID und CLIENT_ID sind erforderlich." >&2
  exit 1
fi

AUTHORITY="https://login.microsoftonline.com/${TENANT_ID}"

# --- kleiner JSON-Feld-Extraktor (ohne jq-Zwang) -----------------------------
json_get() {
  # $1 = key, liest JSON von stdin, gibt den ersten String-Wert aus
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg k "$1" '.[$k] // empty'
  else
    sed -n 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1
  fi
}

# --- Schritt 1: Device Code anfordern ----------------------------------------
echo
echo ">> Fordere Device Code an ..."
DEVICE_RESP="$(curl -sS -X POST \
  "${AUTHORITY}/oauth2/v2.0/devicecode" \
  -d "client_id=${CLIENT_ID}" \
  --data-urlencode "scope=${SCOPE}")"

DEVICE_CODE="$(printf '%s' "$DEVICE_RESP" | json_get device_code)"
USER_CODE="$(printf '%s' "$DEVICE_RESP" | json_get user_code)"
VERIFICATION_URI="$(printf '%s' "$DEVICE_RESP" | json_get verification_uri)"
INTERVAL="$(printf '%s' "$DEVICE_RESP" | sed -n 's/.*"interval"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' | head -n1)"
[ -n "$INTERVAL" ] || INTERVAL=5

if [ -z "$DEVICE_CODE" ]; then
  echo "FEHLER beim Device-Code-Request. Antwort:" >&2
  printf '%s\n' "$DEVICE_RESP" >&2
  exit 1
fi

echo
echo "============================================================"
echo "  1. Öffne im Browser:  ${VERIFICATION_URI}"
echo "  2. Gib diesen Code ein:  ${USER_CODE}"
echo "  3. Melde dich mit dem Microsoft-365-Konto an, dessen"
echo "     Teams-Status gesteuert werden soll, und bestätige die"
echo "     Berechtigung (Presence.ReadWrite)."
echo "============================================================"
echo
echo ">> Warte auf Anmeldung ..."

# --- Schritt 2: Token-Endpoint pollen ----------------------------------------
while true; do
  sleep "$INTERVAL"
  TOKEN_RESP="$(curl -sS -X POST \
    "${AUTHORITY}/oauth2/v2.0/token" \
    -d "grant_type=urn:ietf:params:oauth:grant-type:device_code" \
    -d "client_id=${CLIENT_ID}" \
    -d "device_code=${DEVICE_CODE}")"

  ERROR="$(printf '%s' "$TOKEN_RESP" | json_get error)"
  case "$ERROR" in
    authorization_pending) continue ;;
    slow_down) INTERVAL=$((INTERVAL + 5)); continue ;;
    "" ) break ;;  # kein Fehler -> fertig
    * )
      echo "FEHLER: $ERROR" >&2
      printf '%s' "$TOKEN_RESP" | json_get error_description >&2
      exit 1
      ;;
  esac
done

REFRESH_TOKEN="$(printf '%s' "$TOKEN_RESP" | json_get refresh_token)"
ACCESS_TOKEN="$(printf '%s' "$TOKEN_RESP" | json_get access_token)"

if [ -z "$REFRESH_TOKEN" ]; then
  echo "FEHLER: Kein refresh_token erhalten. Ist 'offline_access' im Scope und erlaubt?" >&2
  printf '%s\n' "$TOKEN_RESP" >&2
  exit 1
fi

echo
echo "ERFOLG! Anmeldung abgeschlossen."
echo "------------------------------------------------------------"
echo "Trage diesen Wert in secrets.yaml ein:"
echo
echo "presence_refresh_token: \"${REFRESH_TOKEN}\""
echo
echo "------------------------------------------------------------"
[ -n "$ACCESS_TOKEN" ] && echo "(Ein Access Token wurde ebenfalls ausgestellt und ist ~60-90 Min gültig.)"
echo "Danach token_refresh.sh testen – siehe README.md."
