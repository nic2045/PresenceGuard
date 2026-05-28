"""Application Credentials für PresenceGuard (Microsoft Entra OAuth2)."""

from homeassistant.components.application_credentials import AuthorizationServer
from homeassistant.core import HomeAssistant

from .const import OAUTH2_AUTHORIZE, OAUTH2_TOKEN


async def async_get_authorization_server(hass: HomeAssistant) -> AuthorizationServer:
    """OAuth2-Endpunkte für Microsoft Graph."""
    return AuthorizationServer(
        authorize_url=OAUTH2_AUTHORIZE,
        token_url=OAUTH2_TOKEN,
    )


async def async_get_description_placeholders(hass: HomeAssistant) -> dict[str, str]:
    """Hinweise im Application-Credentials-Dialog."""
    return {
        "more_info_url": "https://github.com/nic2045/PresenceGuard",
        "redirect_url": "https://my.home-assistant.io/redirect/oauth",
    }
