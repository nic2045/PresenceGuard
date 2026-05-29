"""Constants for the PresenceGuard integration."""

DOMAIN = "presenceguard"

# Microsoft Entra OAuth2 (delegated, only your own account -> least privilege).
# "organizations" allows any work/school account without a fixed tenant.
OAUTH2_AUTHORIZE = "https://login.microsoftonline.com/organizations/oauth2/v2.0/authorize"
OAUTH2_TOKEN = "https://login.microsoftonline.com/organizations/oauth2/v2.0/token"

# offline_access -> refresh token; Presence.ReadWrite -> set the preferred status.
SCOPES = ["offline_access", "openid", "profile", "Presence.ReadWrite"]

GRAPH_BASE = "https://graph.microsoft.com/v1.0"

# Poll interval for /me/presence (minutes), configurable via the options flow.
CONF_SCAN_INTERVAL = "scan_interval"
DEFAULT_SCAN_INTERVAL = 3
MIN_SCAN_INTERVAL = 1
MAX_SCAN_INTERVAL = 60

# Valid combinations for setUserPreferredPresence.
PRESENCE_OPTIONS = {
    "Offline": "OffWork",
    "Available": "Available",
    "Busy": "Busy",
    "DoNotDisturb": "DoNotDisturb",
    "BeRightBack": "BeRightBack",
    "Away": "Away",
}
