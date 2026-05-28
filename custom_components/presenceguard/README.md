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

- `binary_sensor.presenceguard_token` – "Connected" as long as the token is valid
  (attributes: current availability/activity).
- Services:
  - `presenceguard.set_offline` – set Offline (OffWork)
  - `presenceguard.clear_presence` – clear the preferred status
  - `presenceguard.set_presence` – set `availability` (+ optional `activity`)

These services can be used in automations/blueprints exactly like the previous
`rest_command.*`.

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
