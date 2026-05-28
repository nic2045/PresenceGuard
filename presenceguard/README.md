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

Der Access Token wird alle 30 Minuten (und beim HA-Start) automatisch über
den Refresh Token erneuert.

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
das wieder auf. Beide brauchen dieselbe delegierte Berechtigung
`Presence.ReadWrite`.

> Hinweis: Der bevorzugte Status wirkt nur, solange mindestens eine
> Presence-Session existiert (z. B. Teams-Client angemeldet). Ohne Session ist
> der Nutzer ohnehin Offline – das gewünschte Ergebnis tritt also in beiden
> Fällen ein.

---

## Dateien

| Datei | Zweck |
| --- | --- |
| `entra_app_setup.md` | App Registration in Entra ID (Schritt für Schritt) |
| `token_setup.sh` | Einmaliger Token-Grab via Device Code Flow → Refresh Token |
| `token_refresh.sh` | Erneuert den Access Token via Refresh Token (von HA aufgerufen) |
| `secrets.yaml` | Vorlage mit Platzhaltern für `/config/secrets.yaml` |
| `rest_commands.yaml` | `set_teams_offline` + `clear_teams_presence` + parametrierbar `set_teams_presence` |
| `command_line_presenceguard.yaml` | Token-Sensor (umgeht das 255-Zeichen-State-Limit) |
| `template_presenceguard.yaml` | **Status-Sensor** `binary_sensor.presenceguard_token` – zeigt in der UI, ob Token-Daten da sind |
| `shell_commands.yaml` | Aufruf von `token_refresh.sh` |
| `automations_presenceguard.yaml` | Die 4 fest verdrahteten Automationen (Klassik) |
| `blueprints/automation/presenceguard/presence_schedule.yaml` | **Blueprint** mit UI-Konfiguration (Zeitplan-Helper + Status-Dropdown) |
| `schedule_helper_presenceguard.yaml` | Beispiel-Zeitplan-Helper (mehrere Von/Bis-Fenster) |

---

## Setup end-to-end

### 1. Entra ID App Registration
Folge [`entra_app_setup.md`](entra_app_setup.md). Ergebnis: `client_id`,
`tenant_id`, `user_id` (und optional `client_secret`).

### 2. Refresh Token holen (einmalig, lokal)
```bash
TENANT_ID=<deine-tenant-id> CLIENT_ID=<deine-client-id> ./token_setup.sh
```
Im Browser unter `https://microsoft.com/devicelogin` den angezeigten Code
eingeben, anmelden, Berechtigung bestätigen. Das Script gibt am Ende
`presence_refresh_token: "..."` aus.

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

(`token_setup.sh` muss nicht auf den HA-Host – es ist ein Einmal-Tool.)

### 4. Secrets eintragen
Übernimm die Keys aus [`secrets.yaml`](secrets.yaml) in deine
`/config/secrets.yaml` und fülle die Werte – inklusive des
`presence_refresh_token` aus Schritt 2.

### 5. configuration.yaml ergänzen
```yaml
rest_command: !include presenceguard/rest_commands.yaml
shell_command: !include presenceguard/shell_commands.yaml
command_line: !include presenceguard/command_line_presenceguard.yaml
template: !include presenceguard/template_presenceguard.yaml
automation presenceguard: !include presenceguard/automations_presenceguard.yaml
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

Die Blueprint-Automation frischt vor jedem Graph-Aufruf den Token auf, setzt
zum Fenster-Start den gewählten Status und führt zum Fenster-Ende die gewählte
End-Aktion aus.

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
| `AADSTS7000218` in token_setup.sh | „Allow public client flows" auf **Yes** stellen (entra_app_setup.md, Schritt 2). |
| Kein `refresh_token` | Scope `offline_access` fehlt oder User-Consent verweigert. |
| REST Command → `401` | Token abgelaufen → `shell_command.refresh_presence_token` ausführen; prüfe, ob `sensor.presence_token` ein `access_token`-Attribut hat. |
| REST Command → `403` | `Presence.ReadWrite` fehlt / kein Consent. |
| Status ändert sich nicht | Teams-Client muss angemeldet sein, damit eine Presence-Session existiert; `user_id` korrekt (GUID/UPN)? |
| `sensor.presence_token` hat keine Attribute / `binary_sensor.presenceguard_token` = *Getrennt* | `/config/presence_token.json` fehlt oder ist leer → token_refresh.sh manuell laufen lassen. |

---

## Kompatibilität
Getestet für **HA OS** und **HA Supervised**. `shell_command` läuft im
Home-Assistant-Core-Container; `bash` und `curl` sind dort vorhanden, `jq`
wird nur genutzt falls verfügbar (sonst portabler Fallback).
