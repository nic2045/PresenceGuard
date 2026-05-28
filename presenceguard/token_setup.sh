#!/usr/bin/env bash
# PresenceGuard – einmaliger Token-Grab via OAuth2 Authorization Code Flow + PKCE.
#
# NUR für den DELEGIERTEN Weg nötig (Presence.ReadWrite, kein Admin-Consent).
# Beim App-only-Weg (Client Credentials) brauchst du dieses Script NICHT –
# dort holt token_refresh.sh das Token allein über client_id + client_secret.
#
# Dieser Flow ist an die Browser-Session deines Geräts gebunden (Redirect auf
# localhost) und damit phishing-resistenter als der Device Code Flow. PKCE
# (S256) bindet den ausgestellten Token zusätzlich an genau diese Anfrage.
#
# Du führst dieses Script EINMAL manuell auf deinem Rechner aus (der einen
# Browser hat). Den ausgegebenen refresh_token trägst du anschließend in
# secrets.yaml ein (Key: presence_refresh_token).
#
# Voraussetzungen: bash, curl, openssl. (jq optional; python3 optional –
# automatisiert das Abfangen des Redirects, sonst URL manuell zurückpasten.)
#
# Aufruf:
#   TENANT_ID=... CLIENT_ID=... ./token_setup.sh
# oder einfach ohne Variablen starten und die Werte eingeben.
#
# Voraussetzung in der App Registration (siehe entra_app_setup.md):
#   Redirect URI vom Typ "Mobile & desktop" -> http://localhost
#   (Loopback; der Port wird von Entra ignoriert.)

set -euo pipefail

SCOPE="offline_access openid profile Presence.ReadWrite"
REDIRECT_PORT="${REDIRECT_PORT:-8400}"
REDIRECT_URI="http://localhost:${REDIRECT_PORT}"

if ! command -v openssl >/dev/null 2>&1; then
  echo "FEHLER: openssl wird für PKCE benötigt, ist aber nicht installiert." >&2
  exit 1
fi

# --- Eingaben einsammeln -----------------------------------------------------
TENANT_ID="${TENANT_ID:-}"
CLIENT_ID="${CLIENT_ID:-}"
# Optional: nur falls die App als Confidential Client (mit Secret) läuft.
CLIENT_SECRET="${CLIENT_SECRET:-}"

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

# --- Hilfsfunktionen ---------------------------------------------------------
json_get() {
  # $1 = key, liest JSON von stdin, gibt den ersten String-Wert aus
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg k "$1" '.[$k] // empty'
  else
    sed -n 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1
  fi
}

urlencode() {
  # RFC-3986-konformes Encoding (reines bash, kein externes Tool nötig).
  local s="$1" out="" c i
  for (( i=0; i<${#s}; i++ )); do
    c="${s:i:1}"
    case "$c" in
      [a-zA-Z0-9.~_-]) out+="$c" ;;
      *) printf -v c '%%%02X' "'$c"; out+="$c" ;;
    esac
  done
  printf '%s' "$out"
}

b64url() {
  # base64url ohne Padding von stdin
  openssl base64 -A | tr '+/' '-_' | tr -d '='
}

# --- PKCE-Paar erzeugen ------------------------------------------------------
CODE_VERIFIER="$(openssl rand 32 | b64url)"
CODE_CHALLENGE="$(printf '%s' "$CODE_VERIFIER" | openssl dgst -sha256 -binary | b64url)"
STATE="$(openssl rand 16 | b64url)"

# --- Schritt 1: Authorize-URL bauen ------------------------------------------
AUTH_URL="${AUTHORITY}/oauth2/v2.0/authorize"
AUTH_URL+="?client_id=$(urlencode "$CLIENT_ID")"
AUTH_URL+="&response_type=code"
AUTH_URL+="&redirect_uri=$(urlencode "$REDIRECT_URI")"
AUTH_URL+="&response_mode=query"
AUTH_URL+="&scope=$(urlencode "$SCOPE")"
AUTH_URL+="&state=$(urlencode "$STATE")"
AUTH_URL+="&code_challenge=$(urlencode "$CODE_CHALLENGE")"
AUTH_URL+="&code_challenge_method=S256"

echo
echo "============================================================"
echo "  Öffne diese URL im Browser und melde dich mit dem"
echo "  Microsoft-365-Konto an, dessen Teams-Status gesteuert"
echo "  werden soll (Berechtigung Presence.ReadWrite bestätigen):"
echo
echo "  ${AUTH_URL}"
echo "============================================================"
echo

# Versuche, den Browser automatisch zu öffnen (best effort).
if command -v xdg-open >/dev/null 2>&1; then xdg-open "$AUTH_URL" >/dev/null 2>&1 || true
elif command -v open >/dev/null 2>&1; then open "$AUTH_URL" >/dev/null 2>&1 || true
fi

# --- Schritt 2: Authorization Code abfangen ----------------------------------
AUTH_CODE=""
RETURNED_STATE=""

if command -v python3 >/dev/null 2>&1; then
  echo ">> Warte auf Redirect zu ${REDIRECT_URI} ..."
  LISTENER="$(mktemp)"
  cat > "$LISTENER" <<'PY'
import http.server, socketserver, urllib.parse, sys
port = int(sys.argv[1])
result = {}

class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        params = dict(urllib.parse.parse_qsl(urllib.parse.urlparse(self.path).query))
        result.update(params)
        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.end_headers()
        ok = 'code' in params
        msg = ('Anmeldung erfolgreich. Du kannst dieses Fenster schliessen.'
               if ok else 'Fehler bei der Anmeldung. Siehe Terminal.')
        self.wfile.write(('<html><body style="font-family:sans-serif">'
                          '<h2>PresenceGuard</h2><p>%s</p></body></html>' % msg).encode())

    def log_message(self, *a):
        pass

with socketserver.TCPServer(('127.0.0.1', port), H) as httpd:
    httpd.handle_request()

if 'code' in result:
    print('code=' + result['code'])
    print('state=' + result.get('state', ''))
elif 'error' in result:
    sys.stderr.write(result.get('error', '') + ': ' + result.get('error_description', '') + '\n')
    sys.exit(1)
else:
    sys.exit(1)
PY
  if CAPTURE="$(python3 "$LISTENER" "$REDIRECT_PORT")"; then
    AUTH_CODE="$(printf '%s\n' "$CAPTURE" | sed -n 's/^code=//p')"
    RETURNED_STATE="$(printf '%s\n' "$CAPTURE" | sed -n 's/^state=//p')"
  fi
  rm -f "$LISTENER"
else
  echo ">> python3 nicht gefunden – manueller Modus."
  echo "   Nach dem Anmelden leitet der Browser auf ${REDIRECT_URI}/?code=..."
  echo "   weiter (die Seite lädt nicht – das ist ok)."
  echo "   Kopiere die KOMPLETTE Adresse aus der Adressleiste und füge sie hier ein:"
  printf 'Redirect-URL: '
  read -r REDIRECT_BACK
  QUERY="${REDIRECT_BACK#*\?}"
  AUTH_CODE="$(printf '%s' "$QUERY" | sed -n 's/.*\bcode=\([^&]*\).*/\1/p')"
  RETURNED_STATE="$(printf '%s' "$QUERY" | sed -n 's/.*\bstate=\([^&]*\).*/\1/p')"
fi

if [ -z "$AUTH_CODE" ]; then
  echo "FEHLER: Kein Authorization Code erhalten." >&2
  exit 1
fi

# CSRF-Schutz: state muss übereinstimmen (im manuellen Modus URL-codiert).
if [ -n "$RETURNED_STATE" ] && [ "$RETURNED_STATE" != "$STATE" ] \
   && [ "$RETURNED_STATE" != "$(urlencode "$STATE")" ]; then
  echo "FEHLER: state stimmt nicht überein (möglicher CSRF). Abbruch." >&2
  exit 1
fi

# --- Schritt 3: Code gegen Tokens tauschen -----------------------------------
echo ">> Tausche Authorization Code gegen Tokens ..."
set -- \
  -d "client_id=${CLIENT_ID}" \
  -d "grant_type=authorization_code" \
  -d "code=${AUTH_CODE}" \
  --data-urlencode "redirect_uri=${REDIRECT_URI}" \
  -d "code_verifier=${CODE_VERIFIER}" \
  --data-urlencode "scope=${SCOPE}"

# Client Secret nur anhängen, wenn als Confidential Client konfiguriert.
if [ -n "$CLIENT_SECRET" ] && [ "$CLIENT_SECRET" != "REPLACE_OR_LEAVE_EMPTY" ]; then
  set -- "$@" --data-urlencode "client_secret=${CLIENT_SECRET}"
fi

TOKEN_RESP="$(curl -sS -X POST "${AUTHORITY}/oauth2/v2.0/token" "$@")"

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
