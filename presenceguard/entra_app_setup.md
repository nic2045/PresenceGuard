# Entra ID App Registration – PresenceGuard

This guide sets up an **App Registration** in Microsoft Entra ID
(formerly Azure AD) so the PresenceGuard integration can set your Teams
presence status via Microsoft Graph.

> **Auth model:** Delegated permission (`Presence.ReadWrite`) + OAuth2
> **authorization code flow** for the sign-in, then automatic refresh-token
> renewal handled by Home Assistant. **No** Premium plan, no Power Automate and
> no application permission / admin consent for app-only is required – you
> control only **your own** account.

You will end up with a **Client ID** and a **Client secret**, which you enter
once when adding the integration in Home Assistant (see
[`../custom_components/presenceguard/README.md`](../custom_components/presenceguard/README.md)).

---

## 1. Register the app

1. Open the [Entra Admin Center](https://entra.microsoft.com) →
   **Identity → Applications → App registrations → New registration**.
2. **Name:** `PresenceGuard`
3. **Supported account types:**
   *Accounts in this organizational directory only (Single tenant)*
4. **Redirect URI:** Platform **Web** →
   `https://my.home-assistant.io/redirect/oauth`
5. Click **Register**.

After creating it, note the **Application (client) ID** on the overview page –
you enter it in Home Assistant when adding the integration.

---

## 2. Add the API permission

1. **API permissions → Add a permission → Microsoft Graph →
   Delegated permissions**.
2. Search for `Presence.ReadWrite` and tick the box.
3. **Add permissions**.
4. Optional, but recommended: **Grant admin consent for &lt;Tenant&gt;**.
   Without admin consent you consent to the app yourself once at the first
   login in the browser – this also works without admin rights, as long as your
   tenant allows user consent.

You do **not** have to add `offline_access`, `openid` and `profile`
explicitly – the integration requests these as part of its scope.
`offline_access` is what lets Home Assistant refresh the token automatically.

---

## 3. Create a client secret

The integration signs in as a **confidential client**, so a secret is required.

1. **Certificates & secrets → Client secrets → New client secret**.
2. Choose a description + expiry (max. 24 months), **Add**.
3. Copy the **Value** (not the Secret ID!) immediately – it is only shown
   once. You enter it together with the Client ID in Home Assistant.

> When the secret expires you simply create a new one and update it via the
> integration's **reauth** card in *Settings → Repairs*.

---

## 4. What's next

You now have a **Client ID** and a **Client secret**. Add the integration in
Home Assistant (**Settings → Devices & Services → Add integration →
PresenceGuard**), enter both, and sign in with Microsoft. Home Assistant keeps
the token fresh from there. See
[`../custom_components/presenceguard/README.md`](../custom_components/presenceguard/README.md).
