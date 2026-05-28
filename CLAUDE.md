# PresenceGuard — Development Guide

PresenceGuard setzt den Microsoft-Teams-Presence-Status automatisch über
Home Assistant + Microsoft Graph (siehe [`presenceguard/README.md`](presenceguard/README.md)).

## Commit conventions (Conventional Commits)

Alle Commits und PR-Titel folgen [Conventional Commits](https://www.conventionalcommits.org/):

| Prefix | Semver-Effekt | Wann |
|--------|---------------|------|
| `feat: ...` | minor bump | Neues nutzersichtbares Feature (Automation, Blueprint, REST Command) |
| `fix: ...` | patch bump | Bugfix oder Verhaltenskorrektur |
| `chore: ...` | kein bump | Tooling, CI, Dependencies |
| `docs: ...` | kein bump | README, CHANGELOG, Kommentare |
| `refactor: ...` | kein bump | Umbau ohne Verhaltensänderung |
| `feat!: ...` / `BREAKING CHANGE` | major bump | Entfernt/benennt bestehende Inputs oder Services um |

## Release workflow

Releases laufen automatisiert über [release-please](https://github.com/googleapis/release-please):

1. `feat:` / `fix:` Commits nach `main` mergen
2. release-please öffnet automatisch eine **Release-PR** (aktualisiert `CHANGELOG.md` + Versionsdateien)
3. Release-PR prüfen und mergen
4. GitHub Release + Tag werden erstellt

Versionsstrings nicht manuell editieren — das übernimmt der Workflow.

## CI

| Workflow | Zweck |
|----------|-------|
| `.github/workflows/validate.yaml` | YAML-Syntaxcheck aller Dateien unter `presenceguard/` (inkl. Blueprint, schedule, rest_commands) bei jedem Push/PR |
| `.github/workflows/gitleaks.yml` | Secret-Scan |
| `.github/workflows/pr-title.yml` | Conventional-Commits-Check des PR-Titels |
| `.github/workflows/release-please.yml` | Automatisierter Release bei Push auf `main` |

## Branch-Strategie

- `main` — stabil
- Feature-Branches — eine Branch pro Feature, PR nach `main`
- Branch-Naming: `feat/<topic>` oder von Claude Code generierte Namen

## Key files (HA-Inhalte unter `presenceguard/`)

| Datei | Zweck |
|-------|-------|
| `presenceguard/blueprints/automation/presenceguard/presence_schedule.yaml` | Blueprint mit UI-Konfiguration (Zeitplan-Helper + Status-Dropdown) |
| `presenceguard/schedule_helper_presenceguard.yaml` | Beispiel-Zeitplan-Helper (mehrere Von/Bis-Fenster) |
| `presenceguard/rest_commands.yaml` | Graph REST Commands (`set_teams_offline`, `clear_teams_presence`, `set_teams_presence`) |
| `presenceguard/automations_presenceguard.yaml` | Klassische, fest verdrahtete Automationen |
| `presenceguard/command_line_presenceguard.yaml` | Token-Sensor |
| `presenceguard/template_presenceguard.yaml` | Status-Sensor `binary_sensor.presenceguard_token` (UI: Token-Daten vorhanden?) |
| `presenceguard/shell_commands.yaml` | Token-Refresh-Aufruf |
| `presenceguard/setup_presenceguard.sh` | Interaktiver Setup-Wizard (Einrichtung end-to-end) |

## HA Custom Tags

YAML der HA-Konfiguration nutzt `!input`, `!include` und `!secret`. Diese sind
in [`.vscode/settings.json`](.vscode/settings.json) als `yaml.customTags`
registriert und werden vom Validierungs-Workflow als Pass-through behandelt.
