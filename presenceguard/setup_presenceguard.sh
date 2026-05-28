#!/usr/bin/env bash
# PresenceGuard – interaktiver Setup-Wizard.
#
# Führt durch die komplette Einrichtung statt der manuellen README-Schritte:
#   1) fragt client_id / tenant_id / user_id ab
#   2) lässt dich den Auth-Weg wählen (A delegiert / B App-only)
#   3) holt bei Weg A optional gleich den Refresh Token (token_setup.sh)
#   4) schreibt die presence_* Keys nach secrets.yaml (mit Backup)
#   5) kopiert token_refresh.sh nach <config>/presenceguard/ und macht es ausführbar
#   6) zeigt den configuration.yaml-Block
#   7) testet auf Wunsch den Token-Abruf
#
# Werte werden gemerkt: Bei einem erneuten Lauf sind bereits eingetragene Werte
# (aus secrets.yaml sowie einer kleinen State-Datei ~/.presenceguard_setup)
# vorausgefüllt – einfach mit Enter bestätigen. Geheimnisse landen NUR in
# secrets.yaml, nicht in der State-Datei.
#
# Fehler sind nicht final: schlägt der Token-Grab oder -Test fehl, fragt der
# Wizard, ob du es erneut versuchen willst.
#
# Ausführen auf dem HA-Host (Zugriff auf /config) ODER lokal nur für den
# Token-Grab. Voraussetzungen: bash, curl. Für Weg A zusätzlich openssl
# (PKCE) und ein Browser; python3/jq sind optional.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATE_FILE="${PG_STATE_FILE:-$HOME/.presenceguard_setup}"

# --- kleine UI-Helfer --------------------------------------------------------
c_bold=$'\033[1m'; c_dim=$'\033[2m'; c_ok=$'\033[32m'; c_warn=$'\033[33m'
c_err=$'\033[31m'; c_off=$'\033[0m'
say()  { printf '%s\n' "$*"; }
hdr()  { printf '\n%s== %s ==%s\n' "$c_bold" "$*" "$c_off"; }
ok()   { printf '%s✓%s %s\n' "$c_ok" "$c_off" "$*"; }
warn() { printf '%s!%s %s\n' "$c_warn" "$c_off" "$*"; }
err()  { printf '%s✗ %s%s\n' "$c_err" "$*" "$c_off" >&2; }

# ask "Frage" "default" -> Antwort auf stdout
ask() {
  local prompt="$1" def="${2:-}" reply
  if [ -n "$def" ]; then
    printf '%s [%s]: ' "$prompt" "$def" >&2
  else
    printf '%s: ' "$prompt" >&2
  fi
  read -r reply || true
  printf '%s' "${reply:-$def}"
}

# yesno "Frage" "J|N" (Großbuchstabe = Default) -> exit 0 für ja
yesno() {
  local prompt="$1" def="${2:-N}" reply
  printf '%s [%s]: ' "$prompt" "$( [ "$def" = "J" ] && echo "J/n" || echo "j/N")" >&2
  read -r reply || true
  reply="${reply:-$def}"
  case "$reply" in [jJyY]*) return 0 ;; *) return 1 ;; esac
}

require_nonempty() {
  # $1 = Wert, $2 = Feldname
  if [ -z "$1" ]; then err "$2 darf nicht leer sein."; return 1; fi
  return 0
}

# Liest eine "key: value" Zeile aus einer secrets-Datei (Platzhalter -> leer).
read_secret() {
  local key="$1" file="$2" val
  [ -f "$file" ] || return 0
  val="$(grep -E "^[[:space:]]*${key}:" "$file" 2>/dev/null | head -n1 \
        | sed -E "s/^[[:space:]]*${key}:[[:space:]]*//" \
        | sed -E 's/^["'\'']//; s/["'\'']$//' | tr -d '\r')"
  case "$val" in *REPLACE*) val="" ;; esac
  printf '%s' "$val"
}

# Schreibt/ersetzt eine "key: \"value\"" Zeile in einer secrets-Datei.
upsert_secret() {
  local key="$1" val="$2" file="$3"
  touch "$file"
  grep -vE "^[[:space:]]*${key}:" "$file" > "${file}.pgtmp" 2>/dev/null || true
  printf '%s: "%s"\n' "$key" "$val" >> "${file}.pgtmp"
  mv "${file}.pgtmp" "$file"
}

# --- State (gemerkte Nicht-Geheimnisse) -------------------------------------
ST_CONFIG_DIR=""; ST_CLIENT_ID=""; ST_TENANT_ID=""; ST_USER_ID=""; ST_AUTH=""
load_state() {
  [ -f "$STATE_FILE" ] || return 0
  local k v
  while IFS='=' read -r k v; do
    case "$k" in
      PG_CONFIG_DIR) ST_CONFIG_DIR="$v" ;;
      PG_CLIENT_ID)  ST_CLIENT_ID="$v" ;;
      PG_TENANT_ID)  ST_TENANT_ID="$v" ;;
      PG_USER_ID)    ST_USER_ID="$v" ;;
      PG_AUTH)       ST_AUTH="$v" ;;
    esac
  done < "$STATE_FILE"
}
save_state() {
  umask 077
  {
    printf 'PG_CONFIG_DIR=%s\n' "$CONFIG_DIR"
    printf 'PG_CLIENT_ID=%s\n'  "$CLIENT_ID"
    printf 'PG_TENANT_ID=%s\n'  "$TENANT_ID"
    printf 'PG_USER_ID=%s\n'    "$USER_ID"
    printf 'PG_AUTH=%s\n'       "$AUTH"
  } > "$STATE_FILE" 2>/dev/null && say "${c_dim}(Werte gemerkt in $STATE_FILE)${c_off}"
}

# =============================================================================
hdr "PresenceGuard Setup-Wizard"
say "Dieser Assistent richtet PresenceGuard Schritt für Schritt ein."
say "${c_dim}Abbrechen jederzeit mit Strg+C. Eingaben werden für einen erneuten"
say "Durchlauf gemerkt – beim nächsten Mal einfach mit Enter bestätigen.${c_off}"
load_state
[ -f "$STATE_FILE" ] && ok "Frühere Eingaben gefunden – Felder sind vorausgefüllt."

# --- Config-Verzeichnis ------------------------------------------------------
hdr "1/6  Home-Assistant Config-Verzeichnis"
CONFIG_DIR="$(ask "Pfad zum HA-Config-Verzeichnis" "${ST_CONFIG_DIR:-${PG_CONFIG_DIR:-/config}}")"
SECRETS_FILE="${CONFIG_DIR}/secrets.yaml"
if [ ! -d "$CONFIG_DIR" ]; then
  warn "Verzeichnis $CONFIG_DIR existiert nicht."
  if ! yesno "Trotzdem fortfahren (z. B. nur Token holen)?" "N"; then exit 1; fi
fi

# --- Stammdaten (Default: secrets.yaml > State > leer) -----------------------
hdr "2/6  Entra-App-Daten"
say "Diese Werte stammen aus der App Registration (siehe entra_app_setup.md)."
def_cid="$(read_secret presence_client_id "$SECRETS_FILE")"; [ -n "$def_cid" ] || def_cid="$ST_CLIENT_ID"
def_tid="$(read_secret presence_tenant_id "$SECRETS_FILE")"; [ -n "$def_tid" ] || def_tid="$ST_TENANT_ID"
def_uid="$(read_secret presence_user_id   "$SECRETS_FILE")"; [ -n "$def_uid" ] || def_uid="$ST_USER_ID"

CLIENT_ID="";  while [ -z "$CLIENT_ID" ]; do CLIENT_ID="$(ask "Application (client) ID" "$def_cid")"; require_nonempty "$CLIENT_ID" "client_id" || true; done
TENANT_ID="";  while [ -z "$TENANT_ID" ]; do TENANT_ID="$(ask "Directory (tenant) ID" "$def_tid")"; require_nonempty "$TENANT_ID" "tenant_id" || true; done
USER_ID="";    while [ -z "$USER_ID"   ]; do USER_ID="$(ask "User Object ID oder UPN (z. B. du@firma.de)" "$def_uid")"; require_nonempty "$USER_ID" "user_id" || true; done

# --- Auth-Weg (Default aus vorhandenen Secrets ableiten) ---------------------
hdr "3/6  Auth-Weg wählen"
def_auth="${ST_AUTH:-A}"
[ -n "$(read_secret presence_refresh_token "$SECRETS_FILE")" ] && def_auth="A"
[ -n "$(read_secret presence_client_secret "$SECRETS_FILE")" ] && def_auth="B"
say "  ${c_bold}A${c_off}  Delegiert – Presence.ReadWrite, KEIN Admin nötig, nur dein Konto."
say "      (einmaliger Browser-Login, danach Refresh Token)"
say "  ${c_bold}B${c_off}  App-only  – Presence.ReadWrite.All, Admin-Consent, tenant-weit."
say "      (kein Login, dafür Client Secret)"
AUTH="$(ask "Weg A oder B" "$def_auth")"
AUTH="$(printf '%s' "$AUTH" | tr '[:lower:]' '[:upper:]')"

REFRESH_TOKEN=""
CLIENT_SECRET=""

# token_setup.sh interaktiv ausführen und Refresh Token herauslesen.
run_token_setup() {
  local setup="$SCRIPT_DIR/token_setup.sh" log
  if [ ! -f "$setup" ]; then err "token_setup.sh nicht gefunden in $SCRIPT_DIR"; return 1; fi
  log="$(mktemp)"
  say "Starte token_setup.sh (öffnet den Browser-Login) ..."
  if TENANT_ID="$TENANT_ID" CLIENT_ID="$CLIENT_ID" bash "$setup" | tee "$log"; then
    REFRESH_TOKEN="$(sed -n 's/^presence_refresh_token:[[:space:]]*"\(.*\)"$/\1/p' "$log" | head -n1)"
  fi
  rm -f "$log"
  [ -n "$REFRESH_TOKEN" ]
}

case "$AUTH" in
  A)
    hdr "Weg A: Refresh Token besorgen"
    existing_rt="$(read_secret presence_refresh_token "$SECRETS_FILE")"
    if [ -n "$existing_rt" ] && yesno "Vorhandenen Refresh Token in secrets.yaml behalten?" "J"; then
      REFRESH_TOKEN="$existing_rt"; ok "Vorhandenen Refresh Token übernommen."
    elif yesno "Hast du bereits einen Refresh Token zum Einfügen?" "N"; then
      while [ -z "$REFRESH_TOKEN" ]; do
        REFRESH_TOKEN="$(ask "Refresh Token einfügen")"
        [ -n "$REFRESH_TOKEN" ] || warn "Leer – bitte erneut."
      done
    else
      until run_token_setup; do
        err "Token-Grab fehlgeschlagen."
        yesno "Erneut versuchen?" "J" || { err "Abgebrochen ohne Refresh Token."; exit 1; }
      done
      ok "Refresh Token erhalten."
    fi
    ;;
  B)
    hdr "Weg B: Client Secret"
    existing_cs="$(read_secret presence_client_secret "$SECRETS_FILE")"
    if [ -n "$existing_cs" ] && yesno "Vorhandenes Client Secret in secrets.yaml behalten?" "J"; then
      CLIENT_SECRET="$existing_cs"; ok "Vorhandenes Client Secret übernommen."
    else
      say "${c_dim}Eingabe wird nicht angezeigt.${c_off}"
      while [ -z "$CLIENT_SECRET" ]; do
        printf 'Client Secret (Value): ' >&2
        read -rs CLIENT_SECRET || true; printf '\n' >&2
        [ -n "$CLIENT_SECRET" ] || warn "Leer – bitte erneut."
      done
    fi
    ;;
  *)
    err "Ungültige Auswahl: $AUTH (erwartet A oder B)"; exit 1 ;;
esac

# Nicht-geheime Werte merken (für den nächsten Durchlauf).
save_state

# --- secrets.yaml schreiben --------------------------------------------------
hdr "4/6  secrets.yaml schreiben"
say "Ziel: $SECRETS_FILE"
if yesno "presence_* Keys jetzt schreiben (Backup wird angelegt)?" "J"; then
  if [ -f "$SECRETS_FILE" ]; then
    cp "$SECRETS_FILE" "${SECRETS_FILE}.bak.$(date +%s)" && ok "Backup angelegt."
  fi
  upsert_secret presence_client_id     "$CLIENT_ID"      "$SECRETS_FILE"
  upsert_secret presence_tenant_id     "$TENANT_ID"      "$SECRETS_FILE"
  upsert_secret presence_user_id       "$USER_ID"        "$SECRETS_FILE"
  upsert_secret presence_refresh_token "$REFRESH_TOKEN"  "$SECRETS_FILE"
  upsert_secret presence_client_secret "$CLIENT_SECRET"  "$SECRETS_FILE"
  ok "secrets.yaml aktualisiert."
else
  warn "Übersprungen – trage die Keys manuell ein (siehe secrets.yaml-Vorlage)."
fi

# --- Dateien kopieren --------------------------------------------------------
hdr "5/6  Scripte & YAML nach $CONFIG_DIR/presenceguard/"
TARGET_DIR="${CONFIG_DIR}/presenceguard"
if yesno "token_refresh.sh + YAML-Dateien dorthin kopieren?" "J"; then
  if mkdir -p "$TARGET_DIR" 2>/dev/null; then
    cp "$SCRIPT_DIR/token_refresh.sh" "$TARGET_DIR/" && chmod +x "$TARGET_DIR/token_refresh.sh"
    for f in rest_commands.yaml shell_commands.yaml command_line_presenceguard.yaml \
             template_presenceguard.yaml automations_presenceguard.yaml \
             schedule_helper_presenceguard.yaml; do
      [ -f "$SCRIPT_DIR/$f" ] && cp "$SCRIPT_DIR/$f" "$TARGET_DIR/"
    done
    if [ -d "$SCRIPT_DIR/blueprints" ]; then
      mkdir -p "$CONFIG_DIR/blueprints/automation/presenceguard"
      cp "$SCRIPT_DIR"/blueprints/automation/presenceguard/*.yaml \
         "$CONFIG_DIR/blueprints/automation/presenceguard/" 2>/dev/null || true
    fi
    ok "Dateien kopiert nach $TARGET_DIR."
  else
    err "Konnte $TARGET_DIR nicht anlegen (Rechte?). Bitte manuell kopieren."
  fi
else
  warn "Übersprungen – kopiere die Dateien manuell."
fi

# --- configuration.yaml-Hinweis ---------------------------------------------
hdr "6/6  configuration.yaml ergänzen"
say "Füge diesen Block in ${CONFIG_DIR}/configuration.yaml ein (falls noch nicht vorhanden):"
cat <<'YAML'

  rest_command:   !include presenceguard/rest_commands.yaml
  shell_command:  !include presenceguard/shell_commands.yaml
  command_line:   !include presenceguard/command_line_presenceguard.yaml
  template:       !include presenceguard/template_presenceguard.yaml
  automation presenceguard: !include presenceguard/automations_presenceguard.yaml
YAML
say "${c_dim}(command_line:/template: ggf. mit bestehenden Einträgen zu einer Liste zusammenführen.)${c_off}"

# --- Test (mit Wiederholung) -------------------------------------------------
run_token_test() {
  SECRETS_FILE="$SECRETS_FILE" \
    TOKEN_FILE="${CONFIG_DIR}/presence_token.json" \
    REFRESH_FILE="${CONFIG_DIR}/presence_refresh_token.txt" \
    bash "$TARGET_DIR/token_refresh.sh"
}
if [ -x "$TARGET_DIR/token_refresh.sh" ] && yesno $'\nToken jetzt testweise abrufen?' "J"; then
  while true; do
    if run_token_test; then
      ok "Token erfolgreich erzeugt: ${CONFIG_DIR}/presence_token.json"
      break
    fi
    err "Token-Abruf fehlgeschlagen – siehe Meldung oben (Troubleshooting in der README)."
    say "Tipp: secrets.yaml prüfen/korrigieren, dann erneut versuchen."
    yesno "Erneut versuchen?" "J" || break
  done
fi

hdr "Fertig"
say "Nächste Schritte:"
say "  1. Developer Tools → YAML → Check Configuration"
say "  2. Home Assistant neu starten"
say "  3. binary_sensor.presenceguard_token sollte 'Verbunden' zeigen"
say "  4. rest_command.set_teams_offline testen"
say "${c_dim}Erneuter Lauf? Einfach nochmal ausführen – deine Eingaben sind vorausgefüllt.${c_off}"
ok "Viel Erfolg!"
