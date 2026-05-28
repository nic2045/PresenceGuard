# Entra ID App Registration – PresenceGuard

Diese Anleitung richtet eine **App Registration** in Microsoft Entra ID
(früher Azure AD) ein, damit Home Assistant per Microsoft Graph deinen
Teams-Präsenzstatus setzen darf.

> **Auth-Modell:** Delegated Permission (`Presence.ReadWrite`) +
> OAuth2 **Authorization Code Flow mit PKCE** für die einmalige Anmeldung,
> danach Refresh-Token-Flow für den Dauerbetrieb. Dieser Flow ist an die
> Browser-Session deines Geräts gebunden (Redirect auf `http://localhost`) und
> damit phishing-resistenter als der Device Code Flow. Es wird **kein**
> Premium-Plan, kein Power Automate und kein Application Permission /
> Admin-Consent für App-only benötigt – du steuerst nur **dein eigenes** Konto.

---

## 1. App registrieren

1. Öffne das [Entra Admin Center](https://entra.microsoft.com) →
   **Identity → Applications → App registrations → New registration**.
2. **Name:** `PresenceGuard`
3. **Supported account types:**
   *Accounts in this organizational directory only (Single tenant)*
4. **Redirect URI:** Platform **Public client/native (mobile & desktop)** →
   `http://localhost`
   > Genau diese Loopback-Adresse muss registriert sein. Entra ignoriert bei
   > `http://localhost` den Port, daher funktioniert der von `token_setup.sh`
   > genutzte Port (Standard 8400) ohne weitere Einträge.
5. **Register** klicken.

Nach dem Anlegen notierst du dir auf der Übersichtsseite:

| Wert | Wo zu finden | secrets.yaml-Key |
| --- | --- | --- |
| **Application (client) ID** | Overview | `presence_client_id` |
| **Directory (tenant) ID** | Overview | `presence_tenant_id` |

---

## 2. Public Client Flow erlauben

1. **Authentication** öffnen.
2. Unter **Advanced settings → Allow public client flows** auf **Yes** stellen.
3. **Save**.

> Der Public-Client-Token-Tausch (Authorization Code + PKCE **ohne**
> Client Secret) setzt diese Einstellung voraus. Ohne sie schlägt der
> Token-Endpoint mit `AADSTS7000218` fehl. Betreibst du die App stattdessen als
> Confidential Client (mit Secret), kannst du sie auf **No** lassen – dann
> trägst du das Secret als `presence_client_secret` ein (Abschnitt 4).

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

**Für den empfohlenen Public-Client-Weg (PKCE): NICHT nötig.** Lass
`presence_client_secret` in `secrets.yaml` einfach leer. Sowohl `token_setup.sh`
als auch `token_refresh.sh` arbeiten ohne Secret, sobald „Allow public client
flows = Yes" gesetzt ist. PKCE übernimmt die Absicherung.

Nur falls du die App als **Confidential Client** betreiben willst
(public client flows = No):

1. **Certificates & secrets → Client secrets → New client secret**.
2. Beschreibung + Ablauf wählen (max. 24 Monate), **Add**.
3. Den **Value** (nicht die Secret ID!) sofort kopieren – er wird nur einmal
   angezeigt – und als `presence_client_secret` in `secrets.yaml` eintragen.

`token_setup.sh` und `token_refresh.sh` hängen das Secret automatisch an, sobald
`presence_client_secret` befüllt ist.

---

## 5. User-ID – automatisch

Die User-ID musst du normalerweise **nicht** heraussuchen: `token_refresh.sh`
ermittelt die Object ID des angemeldeten Kontos automatisch über
`GET /me` und schreibt sie in die Token-Datei. Damit ist garantiert, dass der
Status für genau den angemeldeten Nutzer gesetzt wird (kein 401
„Cannot set the presence of another user").

`presence_user_id` in `secrets.yaml` kann daher leer bleiben. Willst du es
trotzdem setzen, nimm die **Object ID (GUID)** – nicht den UPN, da eine UPN auf
ein anderes Objekt auflösen kann.

---

## 6. Weiter geht's

Jetzt hast du `client_id` und `tenant_id` (und optional ein `client_secret`).
Den Refresh Token holst du im nächsten Schritt mit `token_setup.sh` –
siehe [README.md](README.md).
