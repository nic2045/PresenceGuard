"""Select: change the Microsoft Teams presence directly from the device."""

from __future__ import annotations

from homeassistant.components.select import SelectEntity
from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant, callback
from homeassistant.exceptions import HomeAssistantError
from homeassistant.helpers.entity_platform import AddEntitiesCallback
from homeassistant.helpers.restore_state import RestoreEntity
from homeassistant.helpers.update_coordinator import CoordinatorEntity

from .api import AuthError
from .const import (
    DOMAIN,
    PRESENCE_ALIASES,
    PRESENCE_OPTIONS,
    SELECT_CLEAR_OPTION,
    build_device_info,
)
from .coordinator import PresenceCoordinator

# "Auto" (clear preferred presence) first, then the selectable states.
SELECT_OPTIONS = [SELECT_CLEAR_OPTION, *PRESENCE_OPTIONS]


def _to_option(availability: str | None) -> str | None:
    """Map a Graph availability to a selectable option (or None)."""
    if not availability or availability == "PresenceUnknown":
        return None
    mapped = PRESENCE_ALIASES.get(availability, availability)
    return mapped if mapped in PRESENCE_OPTIONS else None


async def async_setup_entry(
    hass: HomeAssistant,
    entry: ConfigEntry,
    async_add_entities: AddEntitiesCallback,
) -> None:
    coordinator: PresenceCoordinator = hass.data[DOMAIN][entry.entry_id]
    async_add_entities([PresenceGuardPresenceSelect(coordinator, entry)])


class PresenceGuardPresenceSelect(
    CoordinatorEntity[PresenceCoordinator], RestoreEntity, SelectEntity
):
    """Lets the user set the preferred Teams presence from the device page.

    Reflects the current availability reported by Graph and keeps the last
    known value across transient hiccups and Home Assistant restarts.
    """

    _attr_has_entity_name = True
    _attr_name = "Set presence"
    _attr_icon = "mdi:account-clock"
    _attr_options = SELECT_OPTIONS

    def __init__(self, coordinator: PresenceCoordinator, entry: ConfigEntry) -> None:
        super().__init__(coordinator)
        self._attr_unique_id = f"{entry.entry_id}_set_presence"
        self._attr_device_info = build_device_info(entry.entry_id)
        data = coordinator.data or {}
        self._current: str | None = _to_option(data.get("availability"))

    async def async_added_to_hass(self) -> None:
        await super().async_added_to_hass()
        # Restore the last selected option across restarts if the first poll
        # didn't yield a valid one yet.
        if self._current is None:
            last = await self.async_get_last_state()
            if last and last.state in PRESENCE_OPTIONS:
                self._current = last.state

    @callback
    def _handle_coordinator_update(self) -> None:
        # Only adopt values from a poll that actually succeeded; ignore
        # transient PresenceUnknown/empty so we keep the last known status.
        if self.coordinator.last_update_success:
            data = self.coordinator.data or {}
            option = _to_option(data.get("availability"))
            if option is not None:
                self._current = option
        super()._handle_coordinator_update()

    @property
    def available(self) -> bool:
        return self.coordinator.last_update_success

    @property
    def current_option(self) -> str | None:
        return self._current

    async def async_select_option(self, option: str) -> None:
        """Set (or clear) the preferred Teams presence."""
        try:
            if option == SELECT_CLEAR_OPTION:
                await self.coordinator.api.async_clear_preferred_presence()
            else:
                activity = PRESENCE_OPTIONS[option]
                await self.coordinator.api.async_set_preferred_presence(option, activity)
        except AuthError as err:
            self.coordinator.config_entry.async_start_reauth(self.hass)
            raise HomeAssistantError(
                "PresenceGuard: sign-in expired – please sign in again in Repairs."
            ) from err
        # Reflect the change immediately, then refresh from Graph to confirm.
        if option != SELECT_CLEAR_OPTION:
            self._current = option
            self.async_write_ha_state()
        await self.coordinator.async_request_refresh()
