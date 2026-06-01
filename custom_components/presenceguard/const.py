"""Constants for the PresenceGuard integration."""

from homeassistant.helpers.entity import DeviceInfo

DOMAIN = "presenceguard"

# Device registry metadata shown in the HA UI ("device info").
DEVICE_NAME = "PresenceGuard"
DEVICE_MANUFACTURER = "nic2045"
DEVICE_MODEL = "Teams Presence"


def build_device_info(entry_id: str) -> DeviceInfo:
    """Shared device info so all entities map to one correctly labeled device."""
    return DeviceInfo(
        identifiers={(DOMAIN, entry_id)},
        name=DEVICE_NAME,
        manufacturer=DEVICE_MANUFACTURER,
        model=DEVICE_MODEL,
        configuration_url="https://github.com/nic2045/PresenceGuard",
    )

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
