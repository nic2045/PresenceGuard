# PresenceGuard

![HA Version](https://img.shields.io/badge/Home%20Assistant-2024.6%2B-blue?logo=homeassistant)
[![HA YAML Validation](https://github.com/nic2045/PresenceGuard/actions/workflows/validate.yaml/badge.svg)](https://github.com/nic2045/PresenceGuard/actions/workflows/validate.yaml)
[![Secret scan: gitleaks](https://github.com/nic2045/PresenceGuard/actions/workflows/gitleaks.yml/badge.svg)](https://github.com/nic2045/PresenceGuard/actions/workflows/gitleaks.yml)
[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-yellow.svg)](https://www.conventionalcommits.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Automatisches Setzen des **Microsoft Teams Presence-Status** über **Home
Assistant** + **Microsoft Graph API** – ohne Premium, Power Automate, Node.js
oder Python-Daemon. Nur `bash`, `curl` und natives HA-YAML.

[![Open your Home Assistant instance and show the blueprint import dialog with a specific blueprint pre-filled.](https://my.home-assistant.io/badges/blueprint_import.svg)](https://my.home-assistant.io/redirect/blueprint_import/?blueprint_url=https%3A%2F%2Fraw.githubusercontent.com%2Fnic2045%2FPresenceGuard%2Fmain%2Fpresenceguard%2Fblueprints%2Fautomation%2Fpresenceguard%2Fpresence_schedule.yaml)

## Features

### 🕒 Zeitsteuerung
- **Zeitplan-Helper (`schedule`)** — beliebig viele Von/Bis-Fenster pro
  Wochentag, komplett in der HA-UI konfigurierbar
- **Klassik-Automationen** — alternativ feste Zeiten (Mo–Fr 17:00 Offline,
  09:00 Reset, Sa 00:00) ohne Helper

### 🎚️ Status selbst setzen
- **Status-Dropdown** — Offline / Abwesend / Bin gleich zurück / Beschäftigt /
  Nicht stören
- **Aktion bei Fenster-Ende** — bevorzugten Status aufheben (echter Status)
  oder festen Status setzen

### 🔐 Token-Handling
- **Automatischer Refresh** — Access Token wird alle 30 Min und beim HA-Start
  erneuert; `token_refresh.sh` wählt automatisch delegiert (Refresh Token) oder
  App-only (Client Credentials)
- **Token-Sensor** — umgeht das 255-Zeichen-State-Limit für lange Tokens
- **Status-Sensor** — `binary_sensor.presenceguard_token` zeigt in der UI, ob
  gültige Token-Daten vorliegen

---

## Warum `setUserPreferredPresence` statt `setPresence`?

`setPresence` unterstützt „Offline" nicht zuverlässig und wird von einem
laufenden Teams-Client überstimmt. `setUserPreferredPresence` (`Offline`/`OffWork`)
setzt den **bevorzugten** Status, der den tatsächlichen Teams-Status
überschreibt; `clearUserPreferredPresence` hebt das wieder auf. Details und
Microsoft-Doku-Begründung: [`presenceguard/README.md`](presenceguard/README.md#warum-setuserpreferredpresence-statt-setpresence).

---

## Requirements

### Entra ID App Registration (erforderlich)
Zwei Wege: **A) delegiert** `Presence.ReadWrite` (kein Admin, nur dein Konto)
oder **B) App-only** `Presence.ReadWrite.All` + Admin-Consent + Client Secret.
Schritt für Schritt:
[`presenceguard/entra_app_setup.md`](presenceguard/entra_app_setup.md).

### Zeitplan-Helper (für Blueprint, empfohlen)
**Via UI:** Einstellungen → Geräte & Dienste → Helfer → *+ Helfer* → **Zeitplan**.
Zeitfenster per Drag & Drop ziehen — mehrere Fenster pro Tag möglich.

**Via YAML:** [`presenceguard/schedule_helper_presenceguard.yaml`](presenceguard/schedule_helper_presenceguard.yaml).

---

## Install

**Blueprint importieren** (My-HA-Badge oben) oder manuell:
Einstellungen → Automationen & Szenen → Blueprints → *Blueprint importieren* →
URL einfügen:
```
https://raw.githubusercontent.com/nic2045/PresenceGuard/main/presenceguard/blueprints/automation/presenceguard/presence_schedule.yaml
```

Vollständiges Setup (App Registration, Token, REST/Shell Commands, Sensor,
configuration.yaml) ist in **[`presenceguard/README.md`](presenceguard/README.md)**
end-to-end dokumentiert.

---

## Konfiguration per UI (Blueprint)

| Eingabe | Bedeutung |
| --- | --- |
| **Zeitplan (Helper)** | Schedule-Helper – legt *Von/Bis* fest (mehrere Fenster) |
| **Status während des Zeitplans** | Dropdown: Offline / Abwesend / Bin gleich zurück / Beschäftigt / Nicht stören |
| **Aktion bei Zeitplan-Ende** | Status aufheben (echter Status) oder festen Status setzen |
| **Token-Sensor** | Standard `sensor.presence_token` |
| **Token-Refresh Shell Command** | Standard `refresh_presence_token` |

> **Klassik oder Blueprint?** Nutze **entweder** die festen Automationen aus
> `presenceguard/automations_presenceguard.yaml` **oder** die Blueprint-Automation
> – nicht beides parallel.

---

## Dateien

| Datei | Zweck |
| --- | --- |
| `presenceguard/blueprints/automation/presenceguard/presence_schedule.yaml` | Blueprint mit UI-Konfiguration |
| `presenceguard/schedule_helper_presenceguard.yaml` | Beispiel-Zeitplan-Helper |
| `presenceguard/rest_commands.yaml` | Graph REST Commands |
| `presenceguard/command_line_presenceguard.yaml` | Token-Sensor |
| `presenceguard/template_presenceguard.yaml` | Status-Sensor (UI: Token-Daten da?) |
| `presenceguard/shell_commands.yaml` | Token-Refresh-Aufruf |
| `presenceguard/automations_presenceguard.yaml` | Klassische Automationen |
| `presenceguard/entra_app_setup.md` | Entra ID App Registration (beide Wege) |
| `presenceguard/setup_presenceguard.sh` | Interaktiver Setup-Wizard |
| `presenceguard/token_setup.sh` / `token_refresh.sh` | Token-Scripte (delegiert + App-only) |

Entwicklungshinweise: [`CLAUDE.md`](CLAUDE.md).

## License

[MIT](LICENSE)
