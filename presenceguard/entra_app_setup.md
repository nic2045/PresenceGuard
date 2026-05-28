# Entra ID App Registration – PresenceGuard

This guide sets up an **App Registration** in Microsoft Entra ID
(formerly Azure AD) so that Home Assistant may set your Teams presence status
via Microsoft Graph.

> **Auth model:** Delegated permission (`Presence.ReadWrite`) +
> OAuth2 **authorization code flow with PKCE** for the one-time sign-in,
> then the refresh-token flow for continuous operation. This flow is bound to
> the browser session of your device (redirect to `http://localhost`) and is
> therefore more phishing-resistant than the device code flow. **No**
> Premium plan, no Power Automate and no application permission /
> admin consent for app-only is required – you control only **your own** account.

> **Are you using the custom integration** (UI login instead of `token_setup.sh`)? Then in
> step 1, instead of the loopback address, create a redirect URI of type **Web** with
> `https://my.home-assistant.io/redirect/oauth` **and** create a **client
> secret** (confidential client). The permission remains delegated
> `Presence.ReadWrite`. Details:
> [`../custom_components/presenceguard/README.md`](../custom_components/presenceguard/README.md).

---

## 1. Register the app

1. Open the [Entra Admin Center](https://entra.microsoft.com) →
   **Identity → Applications → App registrations → New registration**.
2. **Name:** `PresenceGuard`
3. **Supported account types:**
   *Accounts in this organizational directory only (Single tenant)*
4. **Redirect URI:** Platform **Public client/native (mobile & desktop)** →
   `http://localhost`
   > Exactly this loopback address must be registered. For
   > `http://localhost` Entra ignores the port, so the port used by
   > `token_setup.sh` (default 8400) works without further entries.
5. Click **Register**.

After creating it, note the following on the overview page:

| Value | Where to find | secrets.yaml key |
| --- | --- | --- |
| **Application (client) ID** | Overview | `presence_client_id` |
| **Directory (tenant) ID** | Overview | `presence_tenant_id` |

---

## 2. Allow public client flow

1. Open **Authentication**.
2. Under **Advanced settings → Allow public client flows** set it to **Yes**.
3. **Save**.

> The public-client token exchange (authorization code + PKCE **without**
> a client secret) requires this setting. Without it the
> token endpoint fails with `AADSTS7000218`. If you instead run the app as a
> confidential client (with a secret), you can leave it on **No** – then
> you enter the secret as `presence_client_secret` (section 4).

---

## 3. Add the API permission

1. **API permissions → Add a permission → Microsoft Graph →
   Delegated permissions**.
2. Search for `Presence.ReadWrite` and tick the box.
3. **Add permissions**.
4. Optional, but recommended: **Grant admin consent for &lt;Tenant&gt;**.
   Without admin consent you have to consent to the app yourself once
   at the first login in the browser – this also works without admin rights,
   as long as your tenant allows user consent.

You do **not** have to add `offline_access`, `openid` and `profile`
explicitly – `token_setup.sh` requests these as a scope and they are
allowed by default. `offline_access` is needed so that you get a
refresh token at all.

---

## 4. Client secret – when is it needed?

**For the recommended public-client approach (PKCE): NOT needed.** Simply leave
`presence_client_secret` in `secrets.yaml` empty. Both `token_setup.sh`
and `token_refresh.sh` work without a secret once "Allow public client
flows = Yes" is set. PKCE handles the protection.

Only if you want to run the app as a **confidential client**
(public client flows = No):

1. **Certificates & secrets → Client secrets → New client secret**.
2. Choose a description + expiry (max. 24 months), **Add**.
3. Copy the **Value** (not the Secret ID!) immediately – it is only shown
   once – and enter it as `presence_client_secret` in `secrets.yaml`.

`token_setup.sh` and `token_refresh.sh` append the secret automatically once
`presence_client_secret` is filled in.

---

## 5. User ID – automatic

Normally you do **not** have to look up the user ID: `token_refresh.sh`
determines the object ID of the signed-in account automatically via
`GET /me` and writes it to the token file. This guarantees that the
status is set for exactly the signed-in user (no 401
"Cannot set the presence of another user").

`presence_user_id` in `secrets.yaml` can therefore stay empty. If you still
want to set it, use the **Object ID (GUID)** – not the UPN, since a UPN can
resolve to a different object.

---

## 6. What's next

Now you have `client_id` and `tenant_id` (and optionally a `client_secret`).
You get the refresh token in the next step with `token_setup.sh` –
see [README.md](README.md).
