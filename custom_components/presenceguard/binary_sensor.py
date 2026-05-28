"""Binary Sensor: Verbindungs-/Token-Status der PresenceGuard-Integration."""

from __future__ import annotations

from homeassistant.components.binary_sensor import (
    BinarySensorDeviceClass,
    BinarySensorEntity,
)
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
    async_add_entities([PresenceGuardTokenSensor(coordinator, entry)])


class PresenceGuardTokenSensor(
    CoordinatorEntity[PresenceCoordinator], BinarySensorEntity
):
    """An, solange Token gültig ist und Graph antwortet."""

    _attr_has_entity_name = True
    _attr_name = "Token"
    _attr_device_class = BinarySensorDeviceClass.CONNECTIVITY

    def __init__(self, coordinator: PresenceCoordinator, entry: ConfigEntry) -> None:
        super().__init__(coordinator)
        self._attr_unique_id = f"{entry.entry_id}_token"
        self._attr_device_info = {
            "identifiers": {(DOMAIN, entry.entry_id)},
            "name": "PresenceGuard",
            "manufacturer": "PresenceGuard",
        }

    @property
    def is_on(self) -> bool:
        return self.coordinator.last_update_success

    @property
    def extra_state_attributes(self) -> dict[str, str | None]:
        data = self.coordinator.data or {}
        return {
            "availability": data.get("availability"),
            "activity": data.get("activity"),
        }
