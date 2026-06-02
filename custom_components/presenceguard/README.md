# PresenceGuard – Custom Integration (HA-native)

UI-native alternative to the YAML/bash setup: sign in **directly in Home Assistant**
(OAuth2), automatic token renewal and – when the sign-in expires – a
**reauth card in Settings → Repairs** for signing in again. No
`token_setup.sh`, no `secrets.yaml`, no shell command.

> Auth model: **delegated** (`Presence.ReadWrite`, only your own account –
> least privilege). No admin consent needed.

## Installation

1. Copy the `custom_components/presenceguard/` folder to `<config>/custom_components/`
   (or add the repo in **HACS** as a *custom repository* of type
   *Integration*). Restart HA.
2. Create an **Entra ID App Registration** (see
   [`../presenceguard/entra_app_setup.md`](../presenceguard/entra_app_setup.md)),
   but with a redirect URI of type **Web**:
   `https://my.home-assistant.io/redirect/oauth`.
   Permission: delegated **`Presence.ReadWrite`**. Create a **client secret**
   (web app = confidential client).
3. In HA: **Settings → Devices & Services → Add integration →
   PresenceGuard**. The first time you will be asked for **application credentials**
   (client ID + client secret) → enter them.
4. The **Microsoft sign-in** opens. Sign in, confirm `Presence.ReadWrite` –
   done.

## What you get

- `sensor.presenceguard_presence` – the live Teams availability
  (Available/Busy/Away/DoNotDisturb/Offline…) with a status-dependent icon;
  attribute `activity`.
- `select.presenceguard_set_presence` – change the preferred Teams presence
  right from the device page; pick a status (Available/Busy/Away/DoNotDisturb/
  BeRightBack/Offline) or `Auto` to clear it again.
- `binary_sensor.presenceguard_token` – "Connected" as long as the token is valid.
- Services:
  - `presenceguard.set_offline` – set Offline (OffWork)
  - `presenceguard.clear_presence` – clear the preferred status
  - `presenceguard.set_presence` – set `availability` (+ optional `activity`)
  - `presenceguard.set_status_message` – set the Teams status message (note),
    optional `expiry_minutes`; empty message clears it

These services can be used in automations/blueprints exactly like the previous
`rest_command.*`.

## Dashboard: colored presence history

Home Assistant's built-in history renders `sensor.presenceguard_presence` as a
categorical timeline, but assigns colors automatically. To pin a fixed color to
each Teams state (so you can tell the status apart at a glance), use the
[History Explorer Card](https://github.com/alexarch21/history-explorer-card)
(HACS) and map each state under `stateColors`:

```yaml
type: custom:history-explorer-card
stateColors:
  sensor.presenceguard_presence.Available: '#6BB700'      # green
  sensor.presenceguard_presence.AvailableIdle: '#A0D468'  # light green
  sensor.presenceguard_presence.Busy: '#C4314B'           # red
  sensor.presenceguard_presence.BusyIdle: '#E08299'       # light red
  sensor.presenceguard_presence.DoNotDisturb: '#C50F1F'   # dark red
  sensor.presenceguard_presence.Away: '#FFAA44'           # amber
  sensor.presenceguard_presence.BeRightBack: '#FFD24D'    # light amber
  sensor.presenceguard_presence.Offline: '#8A8886'        # gray
  sensor.presenceguard_presence.PresenceUnknown: '#C8C6C4' # light gray
graphs:
  - type: timeline
    entities:
      - entity: sensor.presenceguard_presence
```

Colors accept HEX, `rgb(...)`, CSS color names, or HA CSS variables (e.g.
`--primary-color`). The `*Idle` / `PresenceUnknown` rows are short-lived and can
be dropped if you prefer a leaner config.

## Reauth (Repairs)

When the sign-in expires (e.g. Conditional Access "Sign-in frequency"), the
integration detects this on the next poll and reports `ConfigEntryAuthFailed` →
Home Assistant **automatically shows a reauth card** under *Settings →
Devices & Services* or *Repairs*. One click → sign in to Microsoft again,
and it keeps running. No terminal needed.

> Note: This integration is the UI-native alternative. The classic
> YAML/bash setup under [`../presenceguard/`](../presenceguard/) remains
> usable unchanged – use **one of the two**, not both in parallel for the same
> account.
