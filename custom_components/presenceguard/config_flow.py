"""Config- und Reauth-Flow (OAuth2) für PresenceGuard."""

from __future__ import annotations

import logging
from typing import Any

from homeassistant.config_entries import SOURCE_REAUTH, ConfigFlowResult
from homeassistant.helpers import config_entry_oauth2_flow

from .const import DOMAIN, SCOPES

_LOGGER = logging.getLogger(__name__)


class PresenceGuardOAuth2FlowHandler(
    config_entry_oauth2_flow.AbstractOAuth2FlowHandler, domain=DOMAIN
):
    """OAuth2-Anmeldung in der HA-UI inkl. Reauth (Reparaturen)."""

    DOMAIN = DOMAIN

    @property
    def logger(self) -> logging.Logger:
        return _LOGGER

    @property
    def extra_authorize_data(self) -> dict[str, Any]:
        # Scope + erzwungene Kontoauswahl bei Reauth.
        data = {"scope": " ".join(SCOPES)}
        if self.source == SOURCE_REAUTH:
            data["prompt"] = "login"
        return data

    async def async_step_reauth(self, entry_data: dict[str, Any]) -> ConfigFlowResult:
        """Start des Reauth (von HA bei ConfigEntryAuthFailed aufgerufen)."""
        return await self.async_step_reauth_confirm()

    async def async_step_reauth_confirm(
        self, user_input: dict[str, Any] | None = None
    ) -> ConfigFlowResult:
        if user_input is None:
            return self.async_show_form(step_id="reauth_confirm")
        return await self.async_step_user()

    async def async_oauth_create_entry(self, data: dict[str, Any]) -> ConfigFlowResult:
        """Eintrag erstellen bzw. bei Reauth aktualisieren."""
        existing_entry = await self.async_set_unique_id(DOMAIN)
        if existing_entry:
            self.hass.config_entries.async_update_entry(existing_entry, data=data)
            await self.hass.config_entries.async_reload(existing_entry.entry_id)
            return self.async_abort(reason="reauth_successful")
        return self.async_create_entry(title="PresenceGuard (Teams)", data=data)
