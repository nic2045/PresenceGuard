# Entra ID App Registration – PresenceGuard

Diese Anleitung richtet eine **App Registration** in Microsoft Entra ID
(früher Azure AD) ein, damit Home Assistant per Microsoft Graph deinen
Teams-Präsenzstatus setzen darf.

> **Auth-Modell:** Delegated Permission (`Presence.ReadWrite`) +
> OAuth2 Device Code Flow für die einmalige Anmeldung, danach
> Refresh-Token-Flow für den Dauerbetrieb. Es wird **kein** Premium-Plan,
> kein Power Automate und kein Application Permission / Admin-Consent für
> App-only benötigt.

---

## 1. App registrieren

1. Öffne das [Entra Admin Center](https://entra.microsoft.com) →
   **Identity → Applications → App registrations → New registration**.
2. **Name:** `PresenceGuard`
3. **Supported account types:**
   *Accounts in this organizational directory only (Single tenant)*
4. **Redirect URI:** Platform **Public client/native (mobile & desktop)** →
   `http://localhost`
5. **Register** klicken.

Nach dem Anlegen notierst du dir auf der Übersichtsseite:

| Wert | Wo zu finden | secrets.yaml-Key |
| --- | --- | --- |
| **Application (client) ID** | Overview | `presence_client_id` |
| **Directory (tenant) ID** | Overview | `presence_tenant_id` |

---

## 2. Public Client Flow erlauben (für Device Code Flow)

1. **Authentication** öffnen.
2. Unter **Advanced settings → Allow public client flows** auf **Yes** stellen.
3. **Save**.

> Der Device Code Flow ist ausschließlich für *public client applications*
> verfügbar (siehe Microsoft Learn). Ohne diese Einstellung schlägt
> `token_setup.sh` mit `AADSTS7000218` fehl.

---

## 3. API-Berechtigung hinzufügen

1. **API permissions → Add a permission → Microsoft Graph →
   Delegated permissions**.
2. Suche nach `Presence.ReadWrite` und setze den Haken.
3. **Add permissions**.
4. Optional, aber empfohlen: **Grant admin consent for &lt;Tenant&gt;**.
   Ohne Admin-Consent musst du der App beim ersten Login im Browser
   einmalig selbst zustimmen – das funktioniert auch ohne Admin-Rechte,
   solange dein Tenant das User-Consent erlaubt.

`offline_access`, `openid` und `profile` musst du **nicht** explizit
hinzufügen – diese fordert `token_setup.sh` als Scope an und sie sind
standardmäßig erlaubt. `offline_access` ist nötig, damit du überhaupt einen
Refresh Token bekommst.

---

## 4. Client Secret – wann nötig?

**Für den empfohlenen Public-Client-Weg (Device Code Flow): NICHT nötig.**
Lass `presence_client_secret` in `secrets.yaml` einfach leer. Sowohl
`token_setup.sh` als auch `token_refresh.sh` arbeiten ohne Secret, sobald
„Allow public client flows = Yes" gesetzt ist.

Nur falls du die App stattdessen als **Confidential Client** betreiben willst
(public client flows = No):

1. **Certificates & secrets → Client secrets → New client secret**.
2. Beschreibung + Ablauf wählen (max. 24 Monate), **Add**.
3. Den **Value** (nicht die Secret ID!) sofort kopieren – er wird nur einmal
   angezeigt – und als `presence_client_secret` in `secrets.yaml` eintragen.

`token_refresh.sh` hängt das Secret automatisch an die Anfrage an, sobald
`presence_client_secret` befüllt ist.

---

## 5. Deine User-ID (Object ID) ermitteln

Graph braucht im Pfad die User-ID (GUID), nicht den UPN.

- **Entra Admin Center → Users → &lt;dein Account&gt; → Object ID kopieren**,
  oder
- im [Graph Explorer](https://developer.microsoft.com/graph/graph-explorer)
  `GET https://graph.microsoft.com/v1.0/me` aufrufen und das Feld `id` nehmen.

Trage den Wert als `presence_user_id` in `secrets.yaml` ein.
(Der UPN, z. B. `du@firma.de`, funktioniert im Graph-Pfad ebenfalls, GUID ist
aber stabiler.)

---

## 6. Weiter geht's

Jetzt hast du `client_id`, `tenant_id`, `user_id` (und optional `client_secret`).
Den Refresh Token holst du im nächsten Schritt mit `token_setup.sh` –
siehe [README.md](README.md).
