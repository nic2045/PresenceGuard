# PresenceGuard

![HA Version](https://img.shields.io/badge/Home%20Assistant-2024.6%2B-blue?logo=homeassistant)
[![HA YAML Validation](https://github.com/nic2045/PresenceGuard/actions/workflows/validate.yaml/badge.svg)](https://github.com/nic2045/PresenceGuard/actions/workflows/validate.yaml)
[![Validate integration (hassfest + HACS)](https://github.com/nic2045/PresenceGuard/actions/workflows/validate-integration.yaml/badge.svg)](https://github.com/nic2045/PresenceGuard/actions/workflows/validate-integration.yaml)
[![Secret scan: gitleaks](https://github.com/nic2045/PresenceGuard/actions/workflows/gitleaks.yml/badge.svg)](https://github.com/nic2045/PresenceGuard/actions/workflows/gitleaks.yml)
[![HACS Custom](https://img.shields.io/badge/HACS-Custom-41BDF5.svg)](https://github.com/hacs/integration)
[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-yellow.svg)](https://www.conventionalcommits.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Automatically set your **Microsoft Teams presence status** via **Home
Assistant** + **Microsoft Graph API** – without Premium, Power Automate, Node.js
or a Python daemon. Just `bash`, `curl` and native HA YAML.

[![Open your Home Assistant instance and open the PresenceGuard repository inside the Home Assistant Community Store.](https://my.home-assistant.io/badges/hacs_repository.svg)](https://my.home-assistant.io/redirect/hacs_repository/?owner=nic2045&repository=PresenceGuard&category=integration)

## Features

### 🧩 Custom integration (UI-native)
- **OAuth login in the HA UI** — sign in to Microsoft directly in Home
  Assistant (no `token_setup.sh`, no `secrets.yaml`)
- **Automatic reauth in Repairs** — when the sign-in expires (e.g. Conditional
  Access), HA shows a reauth card to sign in again
- **Presence sensor** — `sensor.presenceguard_presence` shows the live Teams
  availability (with a status-dependent icon); `binary_sensor.presenceguard_token`
  shows the connection
- **Services** — `presenceguard.set_offline`, `presenceguard.clear_presence`,
  `presenceguard.set_presence`, and `presenceguard.set_status_message`
  (free-text note with optional expiry)
- **HACS-compatible** — installable as a custom repository

### 🕒 Time control
- **Schedule helper (`schedule`)** — any number of from/to windows per
  weekday, fully configurable in the HA UI
- **Classic automations** — alternatively fixed times (Mon–Fri 17:00 Offline,
  09:00 reset, Sat 00:00) without a helper

### 🎚️ Set the status yourself
- **Status dropdown** — Offline / Away / Be right back / Busy /
  Do not disturb
- **Action at window end** — clear the preferred status (real status)
  or set a fixed status

### 🔐 Token handling
- **Automatic refresh** — the access token is renewed every 30 min and at HA
  startup via the refresh token (delegated, `Presence.ReadWrite`); the user_id
  is determined automatically
- **Token sensor** — works around the 255-character state limit for long tokens
- **Status sensor** — `binary_sensor.presenceguard_token` shows in the UI whether
  valid token data is present

---

## Why `setUserPreferredPresence` instead of `setPresence`?

`setPresence` does not reliably support "Offline" and is overridden by a
running Teams client. `setUserPreferredPresence` (`Offline`/`OffWork`)
sets the **preferred** status, which overrides the actual Teams status;
`clearUserPreferredPresence` reverts that again. Details and the
Microsoft documentation rationale: [`presenceguard/README.md`](presenceguard/README.md#why-setuserpreferredpresence-instead-of-setpresence).

---

## Requirements

### Entra ID App Registration (required)
Delegated permission **`Presence.ReadWrite`** (no admin needed, controls only
your own account), public client flows enabled. Step by step:
[`presenceguard/entra_app_setup.md`](presenceguard/entra_app_setup.md).

### Schedule helper (for the blueprint, recommended)
**Via UI:** Settings → Devices & Services → Helpers → *+ Helper* → **Schedule**.
Drag the time windows into place — multiple windows per day are possible.

**Via YAML:** [`presenceguard/schedule_helper_presenceguard.yaml`](presenceguard/schedule_helper_presenceguard.yaml).

---

## Install

There are **two ways** – use one of them:

### A) Custom Integration (UI-native, recommended)
Sign in **directly in Home Assistant** (OAuth2), automatic token renewal
and a **reauth card in Repairs** when the sign-in expires – without
`token_setup.sh`/`secrets.yaml`. Via **HACS** (custom repository, type
*Integration*) or by copying `custom_components/presenceguard/` to `<config>/`.
Details: **[`custom_components/presenceguard/README.md`](custom_components/presenceguard/README.md)**.

### B) Classic (YAML + bash)
**Import the blueprint** (My-HA badge above) or manually:
Settings → Automations & Scenes → Blueprints → *Import blueprint* →
paste the URL:
```
https://raw.githubusercontent.com/nic2045/PresenceGuard/main/presenceguard/blueprints/automation/presenceguard/presence_schedule.yaml
```

The full setup (app registration, token, REST/shell commands, sensor,
configuration.yaml) is documented end-to-end in **[`presenceguard/README.md`](presenceguard/README.md)**.

---

## Configuration via UI (blueprint)

| Input | Meaning |
| --- | --- |
| **Schedule (helper)** | Schedule helper – defines *from/to* (multiple windows) |
| **Status during the schedule** | Dropdown: Offline / Away / Be right back / Busy / Do not disturb |
| **Action at schedule end** | Clear the status (real status) or set a fixed status |
| **Token sensor** | Default `sensor.presence_token` |
| **Token refresh shell command** | Default `refresh_presence_token` |

> **Classic or blueprint?** Use **either** the fixed automations from
> `presenceguard/automations_presenceguard.yaml` **or** the blueprint automation
> – not both in parallel.

---

## Files

| File | Purpose |
| --- | --- |
| `custom_components/presenceguard/` | **Custom integration** (OAuth UI login, reauth in Repairs, presence sensor, services) – see its [README](custom_components/presenceguard/README.md) |
| `presenceguard/blueprints/automation/presenceguard/presence_schedule.yaml` | Blueprint with UI configuration |
| `presenceguard/schedule_helper_presenceguard.yaml` | Example schedule helper |
| `presenceguard/rest_commands.yaml` | Graph REST Commands |
| `presenceguard/command_line_presenceguard.yaml` | Token sensor |
| `presenceguard/template_presenceguard.yaml` | Status sensor (UI: token data present?) |
| `presenceguard/shell_commands.yaml` | Token refresh call |
| `presenceguard/automations_presenceguard.yaml` | Classic automations |
| `presenceguard/entra_app_setup.md` | Entra ID App Registration (both ways) |
| `presenceguard/setup_presenceguard.sh` | Interactive setup wizard |
| `presenceguard/token_setup.sh` / `token_refresh.sh` | Token scripts (delegated, refresh token) |

Development notes: [`CLAUDE.md`](CLAUDE.md).

## License

[MIT](LICENSE)
