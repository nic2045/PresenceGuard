# PresenceGuard

Automatically set your **Microsoft Teams presence status** via
**Home Assistant** + **Microsoft Graph API** – entirely without Premium, Power
Automate, Node.js or a Python daemon. Just `bash`, `curl` and native
HA YAML.

> **Prefer UI-native?** There is also a **custom integration** with
> OAuth login directly in Home Assistant and automatic reauth in *Repairs*
> (no `token_setup.sh`/`secrets.yaml`):
> [`../custom_components/presenceguard/README.md`](../custom_components/presenceguard/README.md).
> This guide describes the **classic** YAML/bash approach.

## What it does

| Time | Action | Teams shows |
| --- | --- | --- |
| Mon–Fri **17:00** | `setUserPreferredPresence` (Offline/OffWork) | **Offline** |
| Mon–Fri **09:00** | `clearUserPreferredPresence` | real status |
| **Sat 00:00** | `setUserPreferredPresence` (Offline/OffWork) | **Offline** |
| **Sun** | – (stays Offline automatically until Mon 09:00) | **Offline** |

The access token is renewed automatically every 30 minutes (and at HA startup)
via the refresh token (delegated, `Presence.ReadWrite`).

---

## Why `setUserPreferredPresence` instead of `setPresence`?

The obvious solution would be `presence/setPresence`. According to the Microsoft
documentation, however, this does **not** work reliably for this purpose:

1. **`Offline` is not a valid `setPresence` combination.** `setPresence`
   only supports `Available/Available`, `Busy/InACall`,
   `Busy/InAConferenceCall`, `Away/Away`, `DoNotDisturb/Presenting`.
2. **App sessions are overridden by the Teams client.** If Teams is running in
   parallel, its "Available" session wins against an app session.
3. **`sessionId` must be the application ID** – an arbitrary value like
   `"presenceguard"` is not accepted by Graph.

`setUserPreferredPresence` (`Offline`/`OffWork`), on the other hand, sets the
**preferred** status, which **overrides** the actual Teams status –
exactly the desired "appears offline". `clearUserPreferredPresence` reverts
that again. Both require the delegated permission `Presence.ReadWrite`
(see [`entra_app_setup.md`](entra_app_setup.md)).

> Note: The preferred status only takes effect as long as at least one
> presence session exists (e.g. the Teams client is signed in). Without a session
> the user is offline anyway – so the desired result occurs in both
> cases.

---

## Files

| File | Purpose |
| --- | --- |
| `entra_app_setup.md` | App registration in Entra ID (both auth approaches) |
| `setup_presenceguard.sh` | **Interactive setup wizard** – walks you through the complete setup |
| `token_setup.sh` | One-time token grab via authorization code + PKCE → refresh token |
| `token_refresh.sh` | Renews the access token via the refresh token; determines the user_id automatically (/me) |
| `secrets.yaml` | Template with placeholders for `/config/secrets.yaml` |
| `rest_commands.yaml` | `set_teams_offline` + `clear_teams_presence` + parameterizable `set_teams_presence` |
| `command_line_presenceguard.yaml` | Token sensor (works around the 255-character state limit) |
| `template_presenceguard.yaml` | **Status sensor** `binary_sensor.presenceguard_token` – shows in the UI whether token data is present |
| `shell_commands.yaml` | Calls `token_refresh.sh` |
| `automations_presenceguard.yaml` | The 4 hard-wired automations (classic) |
| `blueprints/automation/presenceguard/presence_schedule.yaml` | **Blueprint** with UI configuration (schedule helper + status dropdown) |
| `schedule_helper_presenceguard.yaml` | Example schedule helper (multiple from/to windows) |

---

## Quick start via wizard (recommended)

Instead of the manual steps below, you can use the interactive wizard.
First create the app registration ([`entra_app_setup.md`](entra_app_setup.md)),
then:

```bash
cd presenceguard
./setup_presenceguard.sh
```

The wizard asks for `client_id` / `tenant_id` / `user_id`, lets you choose the
auth approach, fetches the refresh token if needed, writes `secrets.yaml`
(with a backup), copies the files to `<config>/presenceguard/`, shows the
`configuration.yaml` block and, if desired, tests the token retrieval. After that
you only need to restart HA.

> It is easiest to run this directly on the HA host (access to `/config`).
> For the delegated approach (browser login) you can also do the token step
> locally and paste the value in later.

---

## Setup end-to-end (manual)

### 1. Entra ID App Registration
Follow [`entra_app_setup.md`](entra_app_setup.md). Result: `client_id`,
`tenant_id` (and optionally a `client_secret`, if confidential client).
Permission: delegated **`Presence.ReadWrite`** (no admin needed, controls only
your own account).

### 2. Get the refresh token (one-time, local)
Run on a machine **with a browser** (authorization code flow + PKCE):
```bash
TENANT_ID=<your-tenant-id> CLIENT_ID=<your-client-id> ./token_setup.sh
```
The script opens (or shows) a sign-in URL. Sign in with the
Microsoft 365 account and confirm `Presence.ReadWrite`. The browser redirects
back to `http://localhost:8400`; the script catches the code automatically
(via `python3`) or you paste the redirected URL in manually once. At
the end it outputs `presence_refresh_token: "..."`.

> Prerequisites: `bash`, `curl`, `openssl`; `python3`/`jq` optional. The
> redirect URI `http://localhost` must be registered. Different port?
> Prefix with `REDIRECT_PORT=...`.

### 3. Copy the files to the HA host
Place the YAML files **and** the script `token_refresh.sh` in the directory
`/config/presenceguard/`. The script is called via `shell_command` and
runs in the Home Assistant Core container (`bash` + `curl` are present there) –
it must be **executable**:
```bash
mkdir -p /config/presenceguard
# copy token_refresh.sh here:
cp token_refresh.sh /config/presenceguard/
chmod +x /config/presenceguard/token_refresh.sh
```

This is how `shell_commands.yaml` wires the script in – the path is hard-wired to
`/config/presenceguard/token_refresh.sh`:
```yaml
# shell_commands.yaml
refresh_presence_token: "bash /config/presenceguard/token_refresh.sh"
```
If you place the script elsewhere, adjust this path accordingly. The
`shell_command` key (`refresh_presence_token`) is exactly the value the
blueprint expects under **Token refresh shell command**.

### 4. Enter secrets
Copy the keys from [`secrets.yaml`](secrets.yaml) into your
`/config/secrets.yaml`: `presence_client_id`, `presence_tenant_id` and
`presence_refresh_token` (from step 2). `presence_user_id` can stay **empty**
(it is determined automatically), `presence_client_secret` only for a
confidential client.

### 5. Extend configuration.yaml
```yaml
rest_command: !include presenceguard/rest_commands.yaml
shell_command: !include presenceguard/shell_commands.yaml
command_line: !include presenceguard/command_line_presenceguard.yaml
template: !include presenceguard/template_presenceguard.yaml
automation presenceguard: !include presenceguard/automations_presenceguard.yaml
```
> Also place the YAML files in `/config/presenceguard/`.
> If you already use `command_line:` or `template:` elsewhere, merge the
> entries into a list instead of defining the key twice.
> `template:` is optional – it only provides the status sensor (see below) and
> is not required for the actual function.

### 6. Create and check the token initially
```bash
bash /config/presenceguard/token_refresh.sh
cat /config/presence_token.json   # should contain access_token + user_id
```

### 7. Reload / restart HA
**Developer Tools → YAML → Check Configuration**, then
**Restart**. After that `sensor.presence_token` exists and the automations
are active.

### 8. Test
**Developer Tools → Actions**:
- Run `rest_command.set_teams_offline` → Teams should show **Offline**.
- Run `rest_command.clear_teams_presence` → the real status returns.

---

## Check the status in the UI

Whether the token data (`access_token` + `user_id`) is actually present –
i.e. the prerequisite for REST commands and blueprint is met – you can see
without Developer Tools directly in the interface, provided `template:` is
included (step 5):

**`binary_sensor.presenceguard_token`** (device_class `connectivity`):

| State | Meaning |
| --- | --- |
| **Connected** (`on`) | `access_token` **and** `user_id` present – everything ready. |
| **Disconnected** (`off`) | Data missing → run `shell_command.refresh_presence_token` or check `token_refresh.sh`. |

Attributes of the sensor:

| Attribute | Content |
| --- | --- |
| `user_id` | The stored user ID (GUID/UPN). |
| `token_age_minutes` | Age of the token in minutes (refresh runs every ~30 min). |
| `last_refresh` | Time of the last successful refresh (`never`, if none yet). |

Add the sensor to a dashboard as an **Entity** or
**Glance** card. If it stays on *Disconnected* permanently or
`token_age_minutes` rises above ~60, the refresh is not running – see troubleshooting.

> Note: `sensor.presence_token` exists thanks to the robust `command_line`
> command even **before** the first token refresh (then without attributes, the
> status sensor is on *Disconnected*). So it does not become "unavailable".

---

## Configuration via UI (blueprint)

Instead of the hard-wired automations in `automations_presenceguard.yaml`,
you can conveniently set the times and the status via the HA interface –
with a **schedule helper** (from/to, any number of windows)
and a **status dropdown**.

### a) Provide the parameterizable REST command
Make sure `rest_commands.yaml` (incl. `set_teams_presence`) is included as in
step 5.

### b) Create the schedule helper
Here you define **multiple times via a helper variable** (from/to per
weekday). Two ways:

- **UI (recommended):** Settings → Devices & Services → **Helpers** →
  *+ Helper* → **Schedule**. Drag blocks into place, multiple windows per
  day are possible.
- **YAML:** include [`schedule_helper_presenceguard.yaml`](schedule_helper_presenceguard.yaml):
  ```yaml
  schedule: !include presenceguard/schedule_helper_presenceguard.yaml
  ```

The helper is "on" as long as the current time falls within a window.

### c) Import the blueprint
Copy `blueprints/automation/presenceguard/presence_schedule.yaml` to
`/config/blueprints/automation/presenceguard/` (or import it via
Settings → Automations & Scenes → **Blueprints** → *Import blueprint*).

### d) Create an automation from the blueprint
Settings → Automations & Scenes → **+ Automation** → *From blueprint*.
Then configure:

| Input | Meaning |
| --- | --- |
| **Schedule (helper)** | The schedule helper created in b) – defines the *from/to* |
| **Status during the schedule** | Dropdown: Offline / Away / Be right back / Busy / Do not disturb |
| **Action at schedule end** | Clear the status (real status) or set a fixed status |
| **Token sensor** | Default `sensor.presence_token` |
| **Token refresh shell command** | Default `refresh_presence_token` |
| **Token status sensor (for warning)** | Default `binary_sensor.presenceguard_token` |
| **Warn above token age (minutes)** | Above this age the refresh is considered stuck (default 90) |
| **Warn on Disconnected status after (minutes)** | "Disconnected" duration before the warning (default 15) |
| **Link to renew** | URL linked as *Renew now* in the warning message |
| **Additional notification (optional)** | e.g. push via `notify.mobile_app_…`; empty = UI message only |

The blueprint automation refreshes the token before every Graph call, sets
the chosen status at window start and performs the chosen end action at
window end.

> **Optional token warning:** If the token becomes too old (refresh stuck) or the
> token data is missing, the automation posts a UI notification with a
> **renew link** (and optionally a push). That way you don't miss the necessary
> re-sign-in – especially with Conditional Access "Sign-in frequency".
> Prerequisite: `template_presenceguard.yaml` is included.

> **Classic or blueprint?** Use **either** the fixed automations from
> `automations_presenceguard.yaml` **or** the blueprint automation – not
> both in parallel, otherwise they overwrite each other. The token refresh
> automation (every 30 min) remains usefully active in both cases.

---

## Runtime files (created automatically)

| Path | Content |
| --- | --- |
| `/config/presence_token.json` | current `access_token` + `user_id` + timestamp |
| `/config/presence_refresh_token.txt` | rotated refresh token (takes precedence over secrets.yaml) |

Both contain secrets – do not commit them to Git (keep them in `.gitignore`).

---

## Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| `AADSTS7000218` (token_setup.sh) | Set "Allow public client flows" to **Yes** (entra_app_setup.md, section 2). |
| No `refresh_token` | Scope `offline_access` is missing or user consent was denied. |
| `token_refresh.sh` → "No refresh token found" | Fill `presence_refresh_token` in `secrets.yaml` (run `token_setup.sh` once). |
| REST command → `401` "Cannot set the presence of another user" | Avoided automatically – `token_refresh.sh` uses the /me user ID. If it still occurs: re-run `token_refresh.sh`. |
| REST command → `401` (otherwise) | Token expired → run `shell_command.refresh_presence_token`; check the `access_token` attribute on `sensor.presence_token`. |
| REST command → `403` | Delegated `Presence.ReadWrite` is missing or there is no consent. |
| Status does not change | The Teams client must be signed in so that a presence session exists. |
| `sensor.presence_token` has no attributes / `binary_sensor.presenceguard_token` = *Disconnected* | `/config/presence_token.json` is missing or empty → run token_refresh.sh manually. |

---

## Compatibility
Tested for **HA OS** and **HA Supervised**. `shell_command` runs in the
Home Assistant Core container; `bash` and `curl` are present there, `jq`
is only used if available (otherwise a portable fallback).
