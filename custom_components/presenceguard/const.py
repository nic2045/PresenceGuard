"""Konstanten für die PresenceGuard-Integration."""

DOMAIN = "presenceguard"

# Microsoft Entra OAuth2 (delegiert, nur eigenes Konto -> least privilege).
# "organizations" erlaubt jedes Arbeits-/Schulkonto ohne festen Tenant.
OAUTH2_AUTHORIZE = "https://login.microsoftonline.com/organizations/oauth2/v2.0/authorize"
OAUTH2_TOKEN = "https://login.microsoftonline.com/organizations/oauth2/v2.0/token"

# offline_access -> Refresh Token; Presence.ReadWrite -> bevorzugten Status setzen.
SCOPES = ["offline_access", "openid", "profile", "Presence.ReadWrite"]

GRAPH_BASE = "https://graph.microsoft.com/v1.0"

# Gültige Kombinationen für setUserPreferredPresence.
PRESENCE_OPTIONS = {
    "Offline": "OffWork",
    "Available": "Available",
    "Busy": "Busy",
    "DoNotDisturb": "DoNotDisturb",
    "BeRightBack": "BeRightBack",
    "Away": "Away",
}
