"""Sensor: current Microsoft Teams presence of the signed-in user."""

from __future__ import annotations

from homeassistant.components.sensor import SensorEntity
from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddEntitiesCallback
from homeassistant.helpers.update_coordinator import CoordinatorEntity

from .const import DOMAIN
from .coordinator import PresenceCoordinator


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
    """Shows the current Teams availability (state) and activity (attribute)."""

    _attr_has_entity_name = True
    _attr_name = "Presence"
    _attr_icon = "mdi:microsoft-teams"

    def __init__(self, coordinator: PresenceCoordinator, entry: ConfigEntry) -> None:
        super().__init__(coordinator)
        self._attr_unique_id = f"{entry.entry_id}_presence"
        self._attr_device_info = {
            "identifiers": {(DOMAIN, entry.entry_id)},
            "name": "PresenceGuard",
            "manufacturer": "PresenceGuard",
        }

    @property
    def available(self) -> bool:
        return self.coordinator.last_update_success

    @property
    def native_value(self) -> str | None:
        # Graph availability, e.g. Available / Busy / Away / DoNotDisturb / Offline.
        return (self.coordinator.data or {}).get("availability")

    @property
    def extra_state_attributes(self) -> dict[str, str | None]:
        return {"activity": (self.coordinator.data or {}).get("activity")}
