"""PresenceGuard – Microsoft Teams presence via Home Assistant."""

from __future__ import annotations

import voluptuous as vol

from homeassistant.config_entries import ConfigEntry
from homeassistant.const import Platform
from homeassistant.core import HomeAssistant, ServiceCall
from homeassistant.exceptions import ConfigEntryNotReady, HomeAssistantError
from homeassistant.helpers import aiohttp_client, config_entry_oauth2_flow
import homeassistant.helpers.config_validation as cv

from .api import AuthError, GraphApi
from .const import DOMAIN, PRESENCE_OPTIONS
from .coordinator import PresenceCoordinator

PLATFORMS: list[Platform] = [Platform.BINARY_SENSOR]

SERVICE_SET_OFFLINE = "set_offline"
SERVICE_CLEAR = "clear_presence"
SERVICE_SET_PRESENCE = "set_presence"

SET_PRESENCE_SCHEMA = vol.Schema(
    {
        vol.Required("availability"): vol.In(list(PRESENCE_OPTIONS)),
        vol.Optional("activity"): cv.string,
    }
)


async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    """Set up the entry: OAuth session, API, coordinator, services."""
    implementation = (
        await config_entry_oauth2_flow.async_get_config_entry_implementation(hass, entry)
    )
    session = config_entry_oauth2_flow.OAuth2Session(hass, entry, implementation)
    api = GraphApi(aiohttp_client.async_get_clientsession(hass), session)

    coordinator = PresenceCoordinator(hass, entry, api)
    await coordinator.async_config_entry_first_refresh()

    hass.data.setdefault(DOMAIN, {})[entry.entry_id] = coordinator
    await hass.config_entries.async_forward_entry_setups(entry, PLATFORMS)

    _async_register_services(hass)
    return True


async def async_unload_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    """Unload the entry."""
    unload_ok = await hass.config_entries.async_unload_platforms(entry, PLATFORMS)
    if unload_ok:
        hass.data[DOMAIN].pop(entry.entry_id, None)
        if not hass.data[DOMAIN]:
            for svc in (SERVICE_SET_OFFLINE, SERVICE_CLEAR, SERVICE_SET_PRESENCE):
                hass.services.async_remove(DOMAIN, svc)
    return unload_ok


def _async_register_services(hass: HomeAssistant) -> None:
    """Register services (once)."""
    if hass.services.has_service(DOMAIN, SERVICE_SET_OFFLINE):
        return

    def _first_api() -> GraphApi:
        coordinators = list(hass.data.get(DOMAIN, {}).values())
        if not coordinators:
            raise ConfigEntryNotReady("PresenceGuard not set up")
        return coordinators[0].api

    async def _handle(call: ServiceCall) -> None:
        api = _first_api()
        try:
            if call.service == SERVICE_SET_OFFLINE:
                await api.async_set_preferred_presence("Offline", "OffWork")
            elif call.service == SERVICE_CLEAR:
                await api.async_clear_preferred_presence()
            elif call.service == SERVICE_SET_PRESENCE:
                availability = call.data["availability"]
                activity = call.data.get("activity") or PRESENCE_OPTIONS[availability]
                await api.async_set_preferred_presence(availability, activity)
        except AuthError as err:
            # Trigger reauth (Repairs card) and report the error.
            for coordinator in hass.data.get(DOMAIN, {}).values():
                coordinator.config_entry.async_start_reauth(hass)
            raise HomeAssistantError(
                "PresenceGuard: sign-in expired – please sign in again in Repairs."
            ) from err

    hass.services.async_register(DOMAIN, SERVICE_SET_OFFLINE, _handle)
    hass.services.async_register(DOMAIN, SERVICE_CLEAR, _handle)
    hass.services.async_register(
        DOMAIN, SERVICE_SET_PRESENCE, _handle, schema=SET_PRESENCE_SCHEMA
    )
