# Entra ID App Registration – PresenceGuard

Diese Anleitung richtet eine **App Registration** in Microsoft Entra ID
(früher Azure AD) ein, damit Home Assistant per Microsoft Graph deinen
Teams-Präsenzstatus setzen darf.

> **Zwei Auth-Wege – wähle einen:**
>
> | | **A) Delegiert** (Authorization Code + PKCE) | **B) App-only** (Client Credentials) |
> | --- | --- | --- |
> | Berechtigung | `Presence.ReadWrite` (delegated) | `Presence.ReadWrite.All` (application) |
> | Admin-Consent | nicht nötig (User-Consent reicht, falls Tenant erlaubt) | **Pflicht** (Global Admin) |
> | Reichweite | nur **dein** Konto | tenant-weit (jeder Nutzer) |
> | Einmaliger Login | ja (`token_setup.sh`, Browser) | nein |
> | Client Secret | optional (mit PKCE nicht nötig) | **Pflicht** |
>
> `token_refresh.sh` erkennt anhand von `secrets.yaml` automatisch, welcher Weg
> aktiv ist. Es wird **kein** Premium-Plan und kein Power Automate benötigt.

---

## 1. App registrieren (für beide Wege)

1. Öffne das [Entra Admin Center](https://entra.microsoft.com) →
   **Identity → Applications → App registrations → New registration**.
2. **Name:** `PresenceGuard`
3. **Supported account types:**
   *Accounts in this organizational directory only (Single tenant)*
4. **Redirect URI:** Für Weg A: Platform **Public client/native (mobile &
   desktop)** → `http://localhost`. Für Weg B nicht nötig (leer lassen).
5. **Register** klicken.

Nach dem Anlegen notierst du dir auf der Übersichtsseite:

| Wert | Wo zu finden | secrets.yaml-Key |
| --- | --- | --- |
| **Application (client) ID** | Overview | `presence_client_id` |
| **Directory (tenant) ID** | Overview | `presence_tenant_id` |

---

## 2A. Weg A: Delegiert (Authorization Code + PKCE)

### 2A.1 Public Client Flow erlauben
1. **Authentication** öffnen.
2. **Advanced settings → Allow public client flows** auf **Yes** stellen.
3. **Save**.

> Genau die Loopback-Adresse `http://localhost` muss als Redirect URI vom Typ
> *Mobile & desktop* registriert sein (Schritt 1.4). Entra ignoriert dabei den
> Port, daher passt der von `token_setup.sh` genutzte Port (Standard 8400).
> Ohne „Allow public client flows = Yes" schlägt der Token-Tausch mit
> `AADSTS7000218` fehl.

### 2A.2 Delegierte Berechtigung
1. **API permissions → Add a permission → Microsoft Graph →
   Delegated permissions**.
2. `Presence.ReadWrite` anhaken → **Add permissions**.
3. Optional: **Grant admin consent**. Ohne Admin-Consent stimmst du beim ersten
   Login im Browser selbst zu (sofern dein Tenant User-Consent erlaubt).

`offline_access`, `openid`, `profile` musst du **nicht** explizit hinzufügen –
die fordert `token_setup.sh` als Scope an. `offline_access` ist nötig für den
Refresh Token.

### 2A.3 Refresh Token holen
Einmalig `token_setup.sh` ausführen (siehe [README.md](README.md), Schritt 2A)
und den ausgegebenen Wert als `presence_refresh_token` in `secrets.yaml`
eintragen. `presence_client_secret` bleibt leer.

---

## 2B. Weg B: App-only (Client Credentials)

### 2B.1 Client Secret erstellen (Pflicht)
1. **Certificates & secrets → Client secrets → New client secret**.
2. Beschreibung + Ablauf wählen (max. 24 Monate), **Add**.
3. Den **Value** (nicht die Secret ID!) sofort kopieren – er wird nur einmal
   angezeigt – und als `presence_client_secret` in `secrets.yaml` eintragen.

> Plane das Ablaufdatum ein: Läuft das Secret ab, schlägt `token_refresh.sh`
> mit `invalid_client`/`AADSTS7000215` fehl. Dann neues Secret erstellen und
> in `secrets.yaml` aktualisieren.

### 2B.2 Application-Berechtigung + Admin-Consent (Pflicht)
1. **API permissions → Add a permission → Microsoft Graph →
   Application permissions**.
2. `Presence.ReadWrite.All` anhaken → **Add permissions**.
3. **Grant admin consent for &lt;Tenant&gt;** (erfordert Global Admin). Status
   muss auf **„Granted"** stehen.

> Bei App-only-Tokens zählen nur **Application** permissions. Eine delegierte
> `Presence.ReadWrite` reicht hier nicht – sonst liefert Graph `403`.
> `presence_refresh_token` bleibt bei diesem Weg leer.

---

## 3. Deine User-ID (Object ID) ermitteln (für beide Wege)

Graph braucht im Pfad die User-ID (GUID), nicht zwingend den UPN.

- **Entra Admin Center → Users → &lt;dein Account&gt; → Object ID kopieren**,
  oder
- im [Graph Explorer](https://developer.microsoft.com/graph/graph-explorer)
  `GET https://graph.microsoft.com/v1.0/me` aufrufen und das Feld `id` nehmen.

Trage den Wert als `presence_user_id` in `secrets.yaml` ein.
(Der UPN, z. B. `du@firma.de`, funktioniert im Graph-Pfad ebenfalls, GUID ist
aber stabiler.)

---

## 4. Weiter geht's

Jetzt hast du `client_id`, `tenant_id`, `user_id` und – je nach Weg – einen
`refresh_token` (A) oder ein `client_secret` (B). Trage sie in
`/config/secrets.yaml` ein (siehe [`secrets.yaml`](secrets.yaml)) und folge der
[README.md](README.md).
