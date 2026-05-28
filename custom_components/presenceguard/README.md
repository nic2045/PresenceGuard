# PresenceGuard – Custom Integration (HA-native)

UI-native Alternative zum YAML/Bash-Setup: Anmeldung **direkt in Home Assistant**
(OAuth2), automatische Token-Erneuerung und – wenn die Anmeldung abläuft – eine
**Reauth-Karte in Einstellungen → Reparaturen** zum erneuten Anmelden. Kein
`token_setup.sh`, kein `secrets.yaml`, kein Shell-Command.

> Auth-Modell: **delegiert** (`Presence.ReadWrite`, nur dein eigenes Konto –
> least privilege). Kein Admin-Consent nötig.

## Installation

1. Ordner `custom_components/presenceguard/` nach `<config>/custom_components/`
   kopieren (oder das Repo in **HACS** als *Custom repository* vom Typ
   *Integration* hinzufügen). HA neu starten.
2. **Entra ID App Registration** anlegen (siehe
   [`../presenceguard/entra_app_setup.md`](../presenceguard/entra_app_setup.md)),
   aber als Redirect-URI vom Typ **Web**:
   `https://my.home-assistant.io/redirect/oauth`.
   Berechtigung: delegiert **`Presence.ReadWrite`**. Ein **Client Secret**
   erstellen (Web-App = Confidential Client).
3. In HA: **Einstellungen → Geräte & Dienste → Integration hinzufügen →
   PresenceGuard**. Beim ersten Mal nach **Application Credentials**
   (Client ID + Client Secret) gefragt → eintragen.
4. Es öffnet sich die **Microsoft-Anmeldung**. Anmelden, `Presence.ReadWrite`
   bestätigen – fertig.

## Was du bekommst

- `binary_sensor.presenceguard_token` – „Verbunden", solange der Token gültig ist
  (Attribute: aktuelle availability/activity).
- Services:
  - `presenceguard.set_offline` – Offline (OffWork) setzen
  - `presenceguard.clear_presence` – bevorzugten Status aufheben
  - `presenceguard.set_presence` – `availability` (+ optional `activity`) setzen

Diese Services lassen sich genau wie die bisherigen `rest_command.*` in
Automationen/Blueprint verwenden.

## Reauth (Reparaturen)

Läuft die Anmeldung ab (z. B. Conditional-Access „Sign-in frequency"), erkennt
die Integration das beim nächsten Poll und meldet `ConfigEntryAuthFailed` →
Home Assistant zeigt **automatisch eine Reauth-Karte** unter *Einstellungen →
Geräte & Dienste* bzw. *Reparaturen*. Ein Klick → erneute Microsoft-Anmeldung,
und es läuft weiter. Kein Terminal nötig.

> Hinweis: Diese Integration ist die UI-native Alternative. Das klassische
> YAML/Bash-Setup unter [`../presenceguard/`](../presenceguard/) bleibt
> unverändert nutzbar – nutze **eines von beiden**, nicht parallel für dasselbe
> Konto.
