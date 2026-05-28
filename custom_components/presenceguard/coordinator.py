"""DataUpdateCoordinator – keeps the token valid and detects when reauth is needed."""

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
    """Polls /me/presence regularly; if the token fails -> reauth."""

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
            # Automatically triggers the reauth flow (appears in Repairs).
            raise ConfigEntryAuthFailed("Token expired – sign-in required again") from err
        except Exception as err:  # noqa: BLE001
            raise UpdateFailed(str(err)) from err
