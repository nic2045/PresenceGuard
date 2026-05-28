"""DataUpdateCoordinator – hält Token gültig und erkennt Reauth-Bedarf."""

from __future__ import annotations

from datetime import timedelta
import logging

from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant
from homeassistant.exceptions import ConfigEntryAuthFailed
from homeassistant.helpers.update_coordinator import DataUpdateCoordinator, UpdateFailed

from .api import AuthError, GraphApi
from .const import DOMAIN

_LOGGER = logging.getLogger(__name__)


class PresenceCoordinator(DataUpdateCoordinator[dict]):
    """Pollt regelmäßig /me/presence; schlägt der Token fehl -> Reauth."""

    def __init__(self, hass: HomeAssistant, entry: ConfigEntry, api: GraphApi) -> None:
        super().__init__(
            hass,
            _LOGGER,
            name=DOMAIN,
            update_interval=timedelta(minutes=10),
            config_entry=entry,
        )
        self.api = api

    async def _async_update_data(self) -> dict:
        try:
            return await self.api.async_get_presence()
        except AuthError as err:
            # Löst automatisch den Reauth-Flow aus (erscheint in Reparaturen).
            raise ConfigEntryAuthFailed("Token abgelaufen – erneute Anmeldung nötig") from err
        except Exception as err:  # noqa: BLE001
            raise UpdateFailed(str(err)) from err
