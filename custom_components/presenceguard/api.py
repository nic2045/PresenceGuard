"""Microsoft Graph client for PresenceGuard (delegated, /me)."""

from __future__ import annotations

from aiohttp import ClientResponseError, ClientSession

from homeassistant.helpers.config_entry_oauth2_flow import OAuth2Session

from .const import GRAPH_BASE


class AuthError(Exception):
    """Token invalid/expired – reauth needed."""


class GraphApi:
    """Thin wrapper around the Graph presence endpoints of the signed-in user."""

    def __init__(self, websession: ClientSession, oauth_session: OAuth2Session) -> None:
        self._web = websession
        self._oauth = oauth_session

    async def _headers(self) -> dict[str, str]:
        await self._oauth.async_ensure_token_valid()
        token = self._oauth.token["access_token"]
        return {"Authorization": f"Bearer {token}"}

    async def _request(self, method: str, path: str, json: dict | None = None) -> dict | None:
        try:
            headers = await self._headers()
        except ClientResponseError as err:
            if err.status in (400, 401):
                raise AuthError from err
            raise
        async with self._web.request(
            method, f"{GRAPH_BASE}{path}", json=json, headers=headers
        ) as resp:
            if resp.status in (401, 403):
                raise AuthError(f"Graph {resp.status}")
            resp.raise_for_status()
            if resp.content_type == "application/json":
                return await resp.json()
            return None

    async def async_get_me(self) -> dict:
        """Profile of the signed-in user (for title/unique ID)."""
        return await self._request("GET", "/me")

    async def async_get_presence(self) -> dict:
        return await self._request("GET", "/me/presence")

    async def async_set_preferred_presence(self, availability: str, activity: str) -> None:
        await self._request(
            "POST",
            "/me/presence/setUserPreferredPresence",
            {"availability": availability, "activity": activity},
        )

    async def async_clear_preferred_presence(self) -> None:
        await self._request("POST", "/me/presence/clearUserPreferredPresence", {})
