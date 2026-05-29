"""Sensor: current Microsoft Teams presence of the signed-in user."""

from __future__ import annotations

from homeassistant.components.sensor import SensorEntity
from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant, callback
from homeassistant.helpers.entity_platform import AddEntitiesCallback
from homeassistant.helpers.update_coordinator import CoordinatorEntity

from .const import DOMAIN
from .coordinator import PresenceCoordinator

# Status-dependent icon per Graph availability.
PRESENCE_ICONS = {
    "Available": "mdi:check-circle",
    "AvailableIdle": "mdi:check-circle-outline",
    "Busy": "mdi:minus-circle",
    "BusyIdle": "mdi:minus-circle-outline",
    "DoNotDisturb": "mdi:cancel",
    "Away": "mdi:clock-outline",
    "BeRightBack": "mdi:clock-outline",
    "Offline": "mdi:circle-outline",
    "PresenceUnknown": "mdi:help-circle-outline",
}


def _is_valid(availability: str | None) -> bool:
    """A usable presence value (ignore empty / PresenceUnknown)."""
    return bool(availability) and availability != "PresenceUnknown"


async def async_setup_entry(
    hass: HomeAssistant,
    entry: ConfigEntry,
    async_add_entities: AddEntitiesCallback,
) -> None:
    coordinator: PresenceCoordinator = hass.data[DOMAIN][entry.entry_id]
    async_add_entities([PresenceGuardPresenceSensor(coordinator, entry)])


class PresenceGuardPresenceSensor(
    CoordinatorEntity[PresenceCoordinator], SensorEntity
):
    """Current Teams availability; keeps the last valid value across hiccups."""

    _attr_has_entity_name = True
    _attr_name = "Presence"

    def __init__(self, coordinator: PresenceCoordinator, entry: ConfigEntry) -> None:
        super().__init__(coordinator)
        self._attr_unique_id = f"{entry.entry_id}_presence"
        self._attr_device_info = {
            "identifiers": {(DOMAIN, entry.entry_id)},
            "name": "PresenceGuard",
            "manufacturer": "PresenceGuard",
        }
        # Seed from the first poll; updated only with valid values afterwards.
        data = coordinator.data or {}
        self._last_availability: str | None = data.get("availability")
        self._last_activity: str | None = data.get("activity")

    @callback
    def _handle_coordinator_update(self) -> None:
        data = self.coordinator.data or {}
        availability = data.get("availability")
        # Ignore failed polls / PresenceUnknown -> keep the last known status.
        if _is_valid(availability):
            self._last_availability = availability
            self._last_activity = data.get("activity")
        super()._handle_coordinator_update()

    @property
    def available(self) -> bool:
        # Stay available once we have any value; don't drop on transient errors.
        return self._last_availability is not None

    @property
    def native_value(self) -> str | None:
        return self._last_availability

    @property
    def icon(self) -> str:
        return PRESENCE_ICONS.get(self._last_availability, "mdi:microsoft-teams")

    @property
    def extra_state_attributes(self) -> dict[str, str | None]:
        return {"activity": self._last_activity}
