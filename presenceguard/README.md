# PresenceGuard

Automatisches Setzen des **Microsoft Teams Presence-Status** über
**Home Assistant** + **Microsoft Graph API** – ganz ohne Premium, Power
Automate, Node.js oder Python-Daemon. Nur `bash`, `curl` und natives
HA-YAML.

## Was es macht

| Zeit | Aktion | Teams zeigt |
| --- | --- | --- |
| Mo–Fr **17:00** | `setUserPreferredPresence` (Offline/OffWork) | **Offline** |
| Mo–Fr **09:00** | `clearUserPreferredPresence` | echter Status |
| **Sa 00:00** | `setUserPreferredPresence` (Offline/OffWork) | **Offline** |
| **So** | – (bleibt automatisch Offline bis Mo 09:00) | **Offline** |

Der Access Token wird alle 30 Minuten (und beim HA-Start) automatisch über den
Refresh Token erneuert (delegiert, `Presence.ReadWrite`).

---

## Warum `setUserPreferredPresence` statt `setPresence`?

Die naheliegende Lösung wäre `presence/setPresence`. Laut Microsoft-Doku
funktioniert das für diesen Zweck aber **nicht** zuverlässig:

1. **`Offline` ist keine gültige `setPresence`-Kombination.** `setPresence`
   unterstützt nur `Available/Available`, `Busy/InACall`,
   `Busy/InAConferenceCall`, `Away/Away`, `DoNotDisturb/Presenting`.
2. **App-Sessions werden vom Teams-Client überstimmt.** Läuft Teams parallel,
   gewinnt dessen „Available"-Session gegen eine App-Session.
3. **`sessionId` muss die Application-ID sein** – ein frei gewählter Wert wie
   `"presenceguard"` wird von Graph nicht akzeptiert.

`setUserPreferredPresence` (`Offline`/`OffWork`) setzt dagegen den
**bevorzugten** Status, der den tatsächlichen Teams-Status **überschreibt** –
genau das gewünschte „erscheint offline". `clearUserPreferredPresence` hebt
das wieder auf. Beide brauchen die delegierte Berechtigung `Presence.ReadWrite`
(siehe [`entra_app_setup.md`](entra_app_setup.md)).

> Hinweis: Der bevorzugte Status wirkt nur, solange mindestens eine
> Presence-Session existiert (z. B. Teams-Client angemeldet). Ohne Session ist
> der Nutzer ohnehin Offline – das gewünschte Ergebnis tritt also in beiden
> Fällen ein.

---

## Dateien

| Datei | Zweck |
| --- | --- |
| `entra_app_setup.md` | App Registration in Entra ID (beide Auth-Wege) |
| `setup_presenceguard.sh` | **Interaktiver Setup-Wizard** – führt durch die komplette Einrichtung |
| `token_setup.sh` | Einmaliger Token-Grab via Authorization Code + PKCE → Refresh Token |
| `token_refresh.sh` | Erneuert das Access Token via Refresh Token; ermittelt die user_id automatisch (/me) |
| `secrets.yaml` | Vorlage mit Platzhaltern für `/config/secrets.yaml` |
| `rest_commands.yaml` | `set_teams_offline` + `clear_teams_presence` + parametrierbar `set_teams_presence` |
| `command_line_presenceguard.yaml` | Token-Sensor (umgeht das 255-Zeichen-State-Limit) |
| `template_presenceguard.yaml` | **Status-Sensor** `binary_sensor.presenceguard_token` – zeigt in der UI, ob Token-Daten da sind |
| `shell_commands.yaml` | Aufruf von `token_refresh.sh` |
| `scripts_presenceguard.yaml` | Skript **Token erneuern** (Button-/Assist-fähig) |
| `automations_presenceguard.yaml` | Die 4 fest verdrahteten Automationen (Klassik) |
| `blueprints/automation/presenceguard/presence_schedule.yaml` | **Blueprint** mit UI-Konfiguration (Zeitplan-Helper + Status-Dropdown) |
| `schedule_helper_presenceguard.yaml` | Beispiel-Zeitplan-Helper (mehrere Von/Bis-Fenster) |

---

## Schnellstart per Wizard (empfohlen)

Statt der manuellen Schritte unten kannst du den interaktiven Assistenten nutzen.
Lege zuerst die App Registration an ([`entra_app_setup.md`](entra_app_setup.md)),
dann:

```bash
cd presenceguard
./setup_presenceguard.sh
```

Der Wizard fragt `client_id` / `tenant_id` / `user_id` ab, lässt dich den
Auth-Weg wählen, holt bei Bedarf den Refresh Token, schreibt `secrets.yaml`
(mit Backup), kopiert die Dateien nach `<config>/presenceguard/`, zeigt den
`configuration.yaml`-Block und testet auf Wunsch den Token-Abruf. Danach nur
noch HA neu starten.

> Am einfachsten direkt auf dem HA-Host ausführen (Zugriff auf `/config`).
> Für den delegierten Weg (Browser-Login) kannst du den Token-Schritt auch
> lokal erledigen und den Wert später einfügen.

---

## Setup end-to-end (manuell)

### 1. Entra ID App Registration
Folge [`entra_app_setup.md`](entra_app_setup.md). Ergebnis: `client_id`,
`tenant_id` (und optional ein `client_secret`, falls Confidential Client).
Berechtigung: delegiert **`Presence.ReadWrite`** (kein Admin nötig, steuert nur
dein eigenes Konto).

### 2. Refresh Token holen (einmalig, lokal)
Auf einem Rechner **mit Browser** ausführen (Authorization Code Flow + PKCE):
```bash
TENANT_ID=<deine-tenant-id> CLIENT_ID=<deine-client-id> ./token_setup.sh
```
Das Script öffnet (bzw. zeigt) eine Anmelde-URL. Melde dich mit dem
Microsoft-365-Konto an und bestätige `Presence.ReadWrite`. Der Browser leitet
auf `http://localhost:8400` zurück; das Script fängt den Code automatisch ab
(via `python3`) oder du fügst die zurückgeleitete URL einmal manuell ein. Am
Ende gibt es `presence_refresh_token: "..."` aus.

> Voraussetzungen: `bash`, `curl`, `openssl`; `python3`/`jq` optional. Die
> Redirect-URI `http://localhost` muss registriert sein. Anderer Port?
> `REDIRECT_PORT=...` voranstellen.

### 3. Dateien auf den HA-Host kopieren
Lege die YAML-Dateien **und** das Script `token_refresh.sh` im Verzeichnis
`/config/presenceguard/` ab. Das Script wird per `shell_command` aufgerufen und
läuft im Home-Assistant-Core-Container (`bash` + `curl` sind dort vorhanden) –
es muss **ausführbar** sein:
```bash
mkdir -p /config/presenceguard
# token_refresh.sh hierher kopieren:
cp token_refresh.sh /config/presenceguard/
chmod +x /config/presenceguard/token_refresh.sh
```

So bindet `shell_commands.yaml` das Script ein – der Pfad ist fest auf
`/config/presenceguard/token_refresh.sh` verdrahtet:
```yaml
# shell_commands.yaml
refresh_presence_token: "bash /config/presenceguard/token_refresh.sh"
```
Legst du das Script woanders ab, passe diesen Pfad entsprechend an. Der
`shell_command`-Key (`refresh_presence_token`) ist genau der Wert, den das
Blueprint unter **Token-Refresh Shell Command** erwartet.

### 4. Secrets eintragen
Übernimm die Keys aus [`secrets.yaml`](secrets.yaml) in deine
`/config/secrets.yaml`: `presence_client_id`, `presence_tenant_id` und
`presence_refresh_token` (aus Schritt 2). `presence_user_id` kann **leer**
bleiben (wird automatisch ermittelt), `presence_client_secret` nur bei
Confidential Client.

### 5. configuration.yaml ergänzen
```yaml
rest_command: !include presenceguard/rest_commands.yaml
shell_command: !include presenceguard/shell_commands.yaml
command_line: !include presenceguard/command_line_presenceguard.yaml
template: !include presenceguard/template_presenceguard.yaml
automation presenceguard: !include presenceguard/automations_presenceguard.yaml
script: !include presenceguard/scripts_presenceguard.yaml   # optional: Button/Assist „Token erneuern"
```
> Lege die YAML-Dateien dazu nach `/config/presenceguard/`.
> Falls du `command_line:` oder `template:` bereits anderweitig nutzt, führe die
> Einträge in einer Liste zusammen statt den Key doppelt zu definieren.
> `template:` ist optional – es liefert nur den Status-Sensor (siehe unten) und
> ist für die eigentliche Funktion nicht erforderlich.

### 6. Token initial erzeugen & prüfen
```bash
bash /config/presenceguard/token_refresh.sh
cat /config/presence_token.json   # sollte access_token + user_id enthalten
```

### 7. HA neu laden / neu starten
**Developer Tools → YAML → Check Configuration**, dann
**Restart**. Danach existiert `sensor.presence_token` und die Automationen
sind aktiv.

### 8. Testen
**Developer Tools → Actions**:
- `rest_command.set_teams_offline` ausführen → Teams sollte **Offline** zeigen.
- `rest_command.clear_teams_presence` ausführen → echter Status kehrt zurück.

---

## Status im UI prüfen

Ob die Token-Daten (`access_token` + `user_id`) tatsächlich vorhanden sind –
also die Voraussetzung für REST Commands und Blueprint erfüllt ist – siehst du
ohne Developer-Tools direkt in der Oberfläche, sofern `template:` eingebunden
ist (Schritt 5):

**`binary_sensor.presenceguard_token`** (device_class `connectivity`):

| Zustand | Bedeutung |
| --- | --- |
| **Verbunden** (`on`) | `access_token` **und** `user_id` vorhanden – alles bereit. |
| **Getrennt** (`off`) | Daten fehlen → `shell_command.refresh_presence_token` ausführen bzw. `token_refresh.sh` prüfen. |

Attribute des Sensors:

| Attribut | Inhalt |
| --- | --- |
| `user_id` | Die hinterlegte User-ID (GUID/UPN). |
| `token_age_minutes` | Alter des Tokens in Minuten (Refresh läuft alle ~30 Min). |
| `last_refresh` | Zeitpunkt des letzten erfolgreichen Refresh (`nie`, falls noch keiner). |

Auf ein Dashboard ziehst du den Sensor als **Entität**- oder
**Glance**-Karte. Steht er dauerhaft auf *Getrennt* oder steigt
`token_age_minutes` über ~60, läuft der Refresh nicht – siehe Troubleshooting.

> Hinweis: `sensor.presence_token` existiert dank des robusten `command_line`-
> Kommandos auch **vor** dem ersten Token-Refresh (dann ohne Attribute, der
> Status-Sensor steht auf *Getrennt*). Er wird also nicht „unavailable".

---

## Token erneuern per Button / Assist

`scripts_presenceguard.yaml` liefert das Skript
**`script.presenceguard_token_erneuern`** (ruft `token_refresh.sh` + aktualisiert
den Sensor). Einbinden via `script: !include …` (siehe Schritt 5).

**Als Button aufs Dashboard:**
```yaml
type: button
name: Teams-Token erneuern
icon: mdi:account-clock
tap_action:
  action: perform-action
  perform_action: script.presenceguard_token_erneuern
```

**Per Sprache (Assist):** Einstellungen → **Sprachassistenten** → *Assist* →
**Entitäten freigeben** → `script.presenceguard_token_erneuern` hinzufügen.
Danach genügt z. B. „**PresenceGuard Token erneuern**" bzw. „Führe … aus".

> ⚠️ Das frischt nur den Access Token auf und wirkt nur, **solange der Refresh
> Token gültig** ist. Eine abgelaufene Anmeldung (z. B. Conditional-Access
> „Sign-in frequency") kann weder Button noch Assist neu anmelden – dafür
> `token_setup.sh` ausführen.

---

## Konfiguration per UI (Blueprint)

Statt der fest verdrahteten Automationen in `automations_presenceguard.yaml`
kannst du die Zeiten und den Status komfortabel über die HA-Oberfläche
einstellen – mit einem **Zeitplan-Helper** (Von/Bis, beliebig viele Fenster)
und einem **Status-Dropdown**.

### a) Parametrierbaren REST Command bereitstellen
Stelle sicher, dass `rest_commands.yaml` (inkl. `set_teams_presence`) wie in
Schritt 5 eingebunden ist.

### b) Zeitplan-Helper anlegen
Hier definierst du **über eine Helper-Variable mehrere Zeiten** (Von/Bis pro
Wochentag). Zwei Wege:

- **UI (empfohlen):** Einstellungen → Geräte & Dienste → **Helfer** →
  *+ Helfer* → **Zeitplan**. Blöcke per Drag & Drop ziehen, mehrere Fenster pro
  Tag möglich.
- **YAML:** [`schedule_helper_presenceguard.yaml`](schedule_helper_presenceguard.yaml)
  einbinden:
  ```yaml
  schedule: !include presenceguard/schedule_helper_presenceguard.yaml
  ```

Der Helper steht „on", solange die aktuelle Zeit in einem Fenster liegt.

### c) Blueprint importieren
Kopiere `blueprints/automation/presenceguard/presence_schedule.yaml` nach
`/config/blueprints/automation/presenceguard/` (oder importiere es über
Einstellungen → Automationen & Szenen → **Blueprints** → *Blueprint importieren*).

### d) Automation aus dem Blueprint erstellen
Einstellungen → Automationen & Szenen → **+ Automation** → *Aus Blueprint*.
Dann konfigurieren:

| Eingabe | Bedeutung |
| --- | --- |
| **Zeitplan (Helper)** | Der unter b) angelegte Schedule-Helper – legt das *Von/Bis* fest |
| **Status während des Zeitplans** | Dropdown: Offline / Abwesend / Bin gleich zurück / Beschäftigt / Nicht stören |
| **Aktion bei Zeitplan-Ende** | Status aufheben (echter Status) oder festen Status setzen |
| **Token-Sensor** | Standard `sensor.presence_token` |
| **Token-Refresh Shell Command** | Standard `refresh_presence_token` |
| **Token-Status-Sensor (für Warnung)** | Standard `binary_sensor.presenceguard_token` |
| **Warnen ab Token-Alter (Minuten)** | Über diesem Alter gilt der Refresh als hängend (Standard 90) |
| **Warnen bei Status Getrennt ab (Minuten)** | „Getrennt"-Dauer bis zur Warnung (Standard 15) |
| **Link zum Erneuern** | URL, die in der Warnmeldung als *Jetzt erneuern* verlinkt wird |
| **Zusätzliche Benachrichtigung (optional)** | z. B. Push via `notify.mobile_app_…`; leer = nur UI-Meldung |

Die Blueprint-Automation frischt vor jedem Graph-Aufruf den Token auf, setzt
zum Fenster-Start den gewählten Status und führt zum Fenster-Ende die gewählte
End-Aktion aus.

> **Optionale Token-Warnung:** Wird der Token zu alt (Refresh hängt) oder fehlen
> die Token-Daten, postet die Automation eine UI-Benachrichtigung mit
> **Erneuern-Link** (und optional einen Push). So verpasst du die nötige
> Neu-Anmeldung nicht – besonders bei Conditional-Access „Sign-in frequency".
> Voraussetzung: `template_presenceguard.yaml` ist eingebunden.

> **Klassik oder Blueprint?** Nutze **entweder** die festen Automationen aus
> `automations_presenceguard.yaml` **oder** die Blueprint-Automation – nicht
> beides parallel, sonst überschreiben sie sich gegenseitig. Die Token-Refresh-
> Automation (alle 30 Min) bleibt in beiden Fällen sinnvoll aktiv.

---

## Dateien zur Laufzeit (werden automatisch erzeugt)

| Pfad | Inhalt |
| --- | --- |
| `/config/presence_token.json` | aktueller `access_token` + `user_id` + Zeitstempel |
| `/config/presence_refresh_token.txt` | rotierter Refresh Token (Vorrang vor secrets.yaml) |

Beide enthalten Geheimnisse – nicht ins Git committen (in `.gitignore` lassen).

---

## Troubleshooting

| Symptom | Ursache / Fix |
| --- | --- |
| `AADSTS7000218` (token_setup.sh) | „Allow public client flows" auf **Yes** stellen (entra_app_setup.md, Abschnitt 2). |
| Kein `refresh_token` | Scope `offline_access` fehlt oder User-Consent verweigert. |
| `token_refresh.sh` → „Kein Refresh Token gefunden" | `presence_refresh_token` in `secrets.yaml` befüllen (einmalig `token_setup.sh` ausführen). |
| REST Command → `401` „Cannot set the presence of another user" | Wird automatisch vermieden – `token_refresh.sh` nutzt die /me-User-ID. Tritt es doch auf: `token_refresh.sh` neu laufen lassen. |
| REST Command → `401` (sonst) | Token abgelaufen → `shell_command.refresh_presence_token` ausführen; prüfe `access_token`-Attribut am `sensor.presence_token`. |
| REST Command → `403` | Delegiertes `Presence.ReadWrite` fehlt oder kein Consent. |
| Status ändert sich nicht | Teams-Client muss angemeldet sein, damit eine Presence-Session existiert. |
| `sensor.presence_token` hat keine Attribute / `binary_sensor.presenceguard_token` = *Getrennt* | `/config/presence_token.json` fehlt oder ist leer → token_refresh.sh manuell laufen lassen. |

---

## Kompatibilität
Getestet für **HA OS** und **HA Supervised**. `shell_command` läuft im
Home-Assistant-Core-Container; `bash` und `curl` sind dort vorhanden, `jq`
wird nur genutzt falls verfügbar (sonst portabler Fallback).
