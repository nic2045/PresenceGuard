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
# Ausführen auf dem HA-Host (Zugriff auf /config) ODER lokal nur für den
# Token-Grab. Voraussetzungen: bash, curl. Für Weg A zusätzlich openssl
# (PKCE) und ein Browser; python3/jq sind optional.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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
  if [ -z "$1" ]; then err "$2 darf nicht leer sein."; exit 1; fi
}

# Schreibt/ersetzt eine "key: \"value\"" Zeile in einer secrets-Datei.
upsert_secret() {
  local key="$1" val="$2" file="$3"
  touch "$file"
  grep -vE "^[[:space:]]*${key}:" "$file" > "${file}.pgtmp" 2>/dev/null || true
  printf '%s: "%s"\n' "$key" "$val" >> "${file}.pgtmp"
  mv "${file}.pgtmp" "$file"
}

# =============================================================================
hdr "PresenceGuard Setup-Wizard"
say "Dieser Assistent richtet PresenceGuard Schritt für Schritt ein."
say "${c_dim}Abbrechen jederzeit mit Strg+C.${c_off}"

# --- Config-Verzeichnis ------------------------------------------------------
hdr "1/6  Home-Assistant Config-Verzeichnis"
CONFIG_DIR="$(ask "Pfad zum HA-Config-Verzeichnis" "${PG_CONFIG_DIR:-/config}")"
SECRETS_FILE="${CONFIG_DIR}/secrets.yaml"
if [ ! -d "$CONFIG_DIR" ]; then
  warn "Verzeichnis $CONFIG_DIR existiert nicht."
  if ! yesno "Trotzdem fortfahren (z. B. nur Token holen)?" "N"; then exit 1; fi
fi

# --- Stammdaten --------------------------------------------------------------
hdr "2/6  Entra-App-Daten"
say "Diese Werte stammen aus der App Registration (siehe entra_app_setup.md)."
CLIENT_ID="$(ask "Application (client) ID")"; require_nonempty "$CLIENT_ID" "client_id"
TENANT_ID="$(ask "Directory (tenant) ID")";   require_nonempty "$TENANT_ID" "tenant_id"
USER_ID="$(ask "User Object ID oder UPN (z. B. du@firma.de)")"; require_nonempty "$USER_ID" "user_id"

# --- Auth-Weg ----------------------------------------------------------------
hdr "3/6  Auth-Weg wählen"
say "  ${c_bold}A${c_off}  Delegiert – Presence.ReadWrite, KEIN Admin nötig, nur dein Konto."
say "      (einmaliger Browser-Login, danach Refresh Token)"
say "  ${c_bold}B${c_off}  App-only  – Presence.ReadWrite.All, Admin-Consent, tenant-weit."
say "      (kein Login, dafür Client Secret)"
AUTH="$(ask "Weg A oder B" "A")"
AUTH="$(printf '%s' "$AUTH" | tr '[:lower:]' '[:upper:]')"

REFRESH_TOKEN=""
CLIENT_SECRET=""

case "$AUTH" in
  A)
    hdr "Weg A: Refresh Token besorgen"
    if yesno "Hast du bereits einen Refresh Token?" "N"; then
      REFRESH_TOKEN="$(ask "Refresh Token einfügen")"
      require_nonempty "$REFRESH_TOKEN" "refresh_token"
    else
      if [ ! -x "$SCRIPT_DIR/token_setup.sh" ] && [ ! -f "$SCRIPT_DIR/token_setup.sh" ]; then
        err "token_setup.sh nicht gefunden in $SCRIPT_DIR"; exit 1
      fi
      say "Starte token_setup.sh (öffnet den Browser-Login) ..."
      TOKEN_LOG="$(mktemp)"
      # Prompts/Anmeldung laufen interaktiv; Ausgabe wird mitprotokolliert.
      if TENANT_ID="$TENANT_ID" CLIENT_ID="$CLIENT_ID" \
           bash "$SCRIPT_DIR/token_setup.sh" | tee "$TOKEN_LOG"; then
        REFRESH_TOKEN="$(sed -n 's/^presence_refresh_token:[[:space:]]*"\(.*\)"$/\1/p' "$TOKEN_LOG" | head -n1)"
      fi
      rm -f "$TOKEN_LOG"
      if [ -z "$REFRESH_TOKEN" ]; then
        err "Konnte keinen Refresh Token aus token_setup.sh lesen."; exit 1
      fi
      ok "Refresh Token erhalten."
    fi
    ;;
  B)
    hdr "Weg B: Client Secret"
    say "${c_dim}Eingabe wird nicht angezeigt.${c_off}"
    printf 'Client Secret (Value): ' >&2
    read -rs CLIENT_SECRET || true; printf '\n' >&2
    require_nonempty "$CLIENT_SECRET" "client_secret"
    ;;
  *)
    err "Ungültige Auswahl: $AUTH (erwartet A oder B)"; exit 1 ;;
esac

# --- secrets.yaml schreiben --------------------------------------------------
hdr "4/6  secrets.yaml schreiben"
say "Ziel: $SECRETS_FILE"
if yesno "presence_* Keys jetzt schreiben (Backup wird angelegt)?" "J"; then
  if [ -f "$SECRETS_FILE" ]; then
    cp "$SECRETS_FILE" "${SECRETS_FILE}.bak.$(date +%s)"
    ok "Backup angelegt."
  fi
  upsert_secret presence_client_id     "$CLIENT_ID"  "$SECRETS_FILE"
  upsert_secret presence_tenant_id     "$TENANT_ID"  "$SECRETS_FILE"
  upsert_secret presence_user_id       "$USER_ID"    "$SECRETS_FILE"
  upsert_secret presence_refresh_token "$REFRESH_TOKEN" "$SECRETS_FILE"
  upsert_secret presence_client_secret "$CLIENT_SECRET" "$SECRETS_FILE"
  ok "secrets.yaml aktualisiert."
else
  warn "Übersprungen – trage die Keys manuell ein (siehe secrets.yaml-Vorlage)."
fi

# --- Dateien kopieren --------------------------------------------------------
hdr "5/6  Scripte & YAML nach $CONFIG_DIR/presenceguard/"
TARGET_DIR="${CONFIG_DIR}/presenceguard"
if yesno "token_refresh.sh + YAML-Dateien dorthin kopieren?" "J"; then
  mkdir -p "$TARGET_DIR"
  cp "$SCRIPT_DIR/token_refresh.sh" "$TARGET_DIR/"
  chmod +x "$TARGET_DIR/token_refresh.sh"
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

# --- Test --------------------------------------------------------------------
if [ -x "$TARGET_DIR/token_refresh.sh" ] && yesno $'\nToken jetzt testweise abrufen?' "J"; then
  if SECRETS_FILE="$SECRETS_FILE" \
       TOKEN_FILE="${CONFIG_DIR}/presence_token.json" \
       REFRESH_FILE="${CONFIG_DIR}/presence_refresh_token.txt" \
       bash "$TARGET_DIR/token_refresh.sh"; then
    ok "Token erfolgreich erzeugt: ${CONFIG_DIR}/presence_token.json"
  else
    err "Token-Abruf fehlgeschlagen – siehe Meldung oben (Troubleshooting in der README)."
  fi
fi

hdr "Fertig"
say "Nächste Schritte:"
say "  1. Developer Tools → YAML → Check Configuration"
say "  2. Home Assistant neu starten"
say "  3. binary_sensor.presenceguard_token sollte 'Verbunden' zeigen"
say "  4. rest_command.set_teams_offline testen"
ok "Viel Erfolg!"
