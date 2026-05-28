# PresenceGuard

![HA Version](https://img.shields.io/badge/Home%20Assistant-2024.6%2B-blue?logo=homeassistant)
[![Validate integration (hassfest + HACS)](https://github.com/nic2045/PresenceGuard/actions/workflows/validate-integration.yaml/badge.svg)](https://github.com/nic2045/PresenceGuard/actions/workflows/validate-integration.yaml)
[![HA YAML Validation](https://github.com/nic2045/PresenceGuard/actions/workflows/validate.yaml/badge.svg)](https://github.com/nic2045/PresenceGuard/actions/workflows/validate.yaml)
[![Secret scan: gitleaks](https://github.com/nic2045/PresenceGuard/actions/workflows/gitleaks.yml/badge.svg)](https://github.com/nic2045/PresenceGuard/actions/workflows/gitleaks.yml)
[![HACS Custom](https://img.shields.io/badge/HACS-Custom-41BDF5.svg)](https://github.com/hacs/integration)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**Own your Microsoft Teams presence — from Home Assistant.**

PresenceGuard is a Home Assistant integration that lets you **read and set your
Microsoft Teams status** with native automations: appear **Offline** after
hours, flip to **Busy** during focus time, post a **status message** like
"In a meeting until 3 pm" — all driven by your schedules, scenes and triggers.

No Premium add-ons, no Power Automate, no scripts to babysit. You sign in once
**inside Home Assistant**, and PresenceGuard keeps the token fresh for you.

[![Open your Home Assistant instance and open the PresenceGuard repository inside the Home Assistant Community Store.](https://my.home-assistant.io/badges/hacs_repository.svg)](https://my.home-assistant.io/redirect/hacs_repository/?owner=nic2045&repository=PresenceGuard&category=integration)

---

## Why PresenceGuard?

- 🔐 **Sign in once, in the UI.** OAuth2 login with Microsoft directly in Home
  Assistant — no `secrets.yaml`, no shell scripts, no manual token copying.
- ♻️ **Stays logged in, fixes itself.** Tokens refresh automatically. If a
  Conditional-Access policy ever forces a re-login, HA shows a **one-click
  reauth card in Repairs** — no terminal required.
- 🟢 **Live status as an entity.** `sensor.presenceguard_presence` shows your
  current Teams availability with a status-aware icon — perfect for dashboards
  and automations.
- 🎛️ **Simple services.** Set Offline, set any status, clear it, or post a
  status note — straight from automations and scripts.
- 🔒 **Least privilege.** Delegated `Presence.ReadWrite` — PresenceGuard only
  ever touches **your own** account. No tenant-wide permissions, no admin
  consent required.
- 📦 **HACS-ready.** Install and update like any other community integration.

---

## What you can do

| You want to… | Use |
| --- | --- |
| Appear **Offline** after work | `presenceguard.set_offline` |
| Set **Busy / Do not disturb / Away / …** | `presenceguard.set_presence` |
| Hand control **back to Teams** | `presenceguard.clear_presence` |
| Post a **status message** (with optional expiry) | `presenceguard.set_status_message` |
| Show your **current status** on a dashboard | `sensor.presenceguard_presence` |

### Example automation

```yaml
alias: PresenceGuard – Teams offline on schedule
mode: queued
triggers:
  - trigger: state
    entity_id: schedule.work_hours
    to: "off"          # outside working hours
    id: off_hours
  - trigger: state
    entity_id: schedule.work_hours
    to: "on"
    id: work
actions:
  - choose:
      - conditions:
          - condition: trigger
            id: off_hours
        sequence:
          - action: presenceguard.set_offline
          - action: presenceguard.set_status_message
            data:
              message: "Outside working hours"
    default:
      - action: presenceguard.clear_presence
```

---

## Install (HACS — recommended)

1. **Add the repository to HACS** (badge above), or HACS → ⋮ → *Custom
   repositories* → `nic2045/PresenceGuard`, type **Integration**. Install and
   restart Home Assistant.
2. **Create an Entra ID app registration** (one-time) — see
   [`presenceguard/entra_app_setup.md`](presenceguard/entra_app_setup.md).
   For the integration use a **Web** redirect URI
   `https://my.home-assistant.io/redirect/oauth` and create a **client secret**.
   Permission: delegated **`Presence.ReadWrite`**.
3. **Settings → Devices & Services → Add Integration → PresenceGuard.** Enter
   your **Client ID** and **Client Secret**, then sign in with Microsoft.

Full integration details:
**[`custom_components/presenceguard/README.md`](custom_components/presenceguard/README.md)**.

---

## How it works

PresenceGuard uses Microsoft Graph's **`setUserPreferredPresence`** rather than
`setPresence`. The preferred status reliably **overrides** the live Teams
status (including "Offline", which `setPresence` doesn't support) and survives a
running Teams client; `clearUserPreferredPresence` hands control back. Details
and the Microsoft rationale:
[`presenceguard/README.md`](presenceguard/README.md#why-setuserpreferredpresence-instead-of-setpresence).

---

## Prefer pure YAML? (classic mode)

PresenceGuard also ships a **no-Python**, bash + YAML setup (blueprint, REST
commands, token scripts) — handy if you don't want a custom integration. It is
fully documented and still maintained:
**[`presenceguard/README.md`](presenceguard/README.md)**.

Import the classic blueprint directly:
```
https://raw.githubusercontent.com/nic2045/PresenceGuard/main/presenceguard/blueprints/automation/presenceguard/presence_schedule.yaml
```

> Use **one** approach per account — the integration **or** the classic YAML
> setup, not both at once.

---

## Files

| Path | Purpose |
| --- | --- |
| `custom_components/presenceguard/` | **The integration** (OAuth UI login, reauth in Repairs, presence sensor, services) |
| `presenceguard/` | Classic YAML/bash setup (blueprint, REST/shell commands, token scripts) |
| `brands/` | Icon assets for submission to `home-assistant/brands` |

Development notes: [`CLAUDE.md`](CLAUDE.md).

## License

[MIT](LICENSE)
