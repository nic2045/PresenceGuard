"""Microsoft Graph client for PresenceGuard (delegated, /me)."""

from __future__ import annotations

import asyncio
from collections.abc import Mapping

from aiohttp import (
    ClientConnectionError,
    ClientResponseError,
    ClientSession,
    ClientTimeout,
)

from homeassistant.helpers.config_entry_oauth2_flow import OAuth2Session

from .const import GRAPH_BASE

# Robustness tunables for Graph calls.
REQUEST_TIMEOUT = ClientTimeout(total=30)
MAX_RETRIES = 2  # additional attempts after the first try
RETRYABLE_STATUS = {429, 503, 504}  # throttling / transient backend errors
DEFAULT_RETRY_AFTER = 5.0  # seconds, when no usable Retry-After header is given
MAX_RETRY_AFTER = 60.0  # never back off longer than this


def _retry_after(headers: Mapping[str, str]) -> float:
    """Seconds to wait before retrying, honoring the Retry-After header."""
    value = headers.get("Retry-After")
    if value:
        try:
            return min(float(value), MAX_RETRY_AFTER)
        except ValueError:
            # Retry-After may be an HTTP date; fall back to a fixed delay.
            return DEFAULT_RETRY_AFTER
    return DEFAULT_RETRY_AFTER


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

    async def _async_force_token_refresh(self) -> None:
        """Refresh the access token even if HA still considers it valid.

        Graph can reject a token that HA's expiry heuristic still treats as
        valid – e.g. clock skew or an early revocation right at the (roughly
        hourly) token boundary. In that case ``async_ensure_token_valid()`` is a
        no-op and we would keep sending the stale token. Refreshing explicitly
        lets a single 401 self-heal within the same poll instead of failing
        every entity and triggering a spurious reauth.

        Raises ``AuthError`` if the refresh token itself is rejected (genuine
        reauth) and re-raises other errors so the caller's retry/backoff and
        network handling still apply.
        """
        oauth = self._oauth
        try:
            new_token = await oauth.implementation.async_refresh_token(oauth.token)
        except ClientResponseError as err:
            # 400/401 here means the refresh token is dead -> real reauth.
            if err.status in (400, 401):
                raise AuthError from err
            raise
        oauth.hass.config_entries.async_update_entry(
            oauth.config_entry,
            data={**oauth.config_entry.data, "token": new_token},
        )

    async def _request(self, method: str, path: str, json: dict | None = None) -> dict | None:
        # Retry transient failures (throttling/backend/network) with a bounded
        # backoff; auth and other client errors surface immediately. This covers
        # the token refresh in _headers() as well as the Graph call itself, so a
        # brief hiccup during the (roughly hourly) token renewal doesn't fail the
        # poll and flip every entity to "unavailable".
        #
        # `attempt` counts only transient retries against MAX_RETRIES. A one-off
        # forced token refresh (on a 401) is deliberately not counted, so it
        # always gets its own retry even if the transient budget is exhausted.
        attempt = 0
        forced_refresh = False
        while True:
            try:
                headers = await self._headers()
            except ClientResponseError as err:
                if err.status in (400, 401):
                    raise AuthError from err
                if err.status in RETRYABLE_STATUS and attempt < MAX_RETRIES:
                    attempt += 1
                    await asyncio.sleep(_retry_after(err.headers or {}))
                    continue
                raise
            except (asyncio.TimeoutError, ClientConnectionError):
                # Network-level hiccup while refreshing the token -> retry a few
                # times, then surface it.
                if attempt < MAX_RETRIES:
                    attempt += 1
                    await asyncio.sleep(DEFAULT_RETRY_AFTER)
                    continue
                raise

            try:
                async with self._web.request(
                    method,
                    f"{GRAPH_BASE}{path}",
                    json=json,
                    headers=headers,
                    timeout=REQUEST_TIMEOUT,
                ) as resp:
                    if resp.status == 401 and not forced_refresh:
                        # Access token rejected: force a fresh token once and
                        # retry within the same poll. Only a second 401 means
                        # the token is genuinely dead (handled below).
                        forced_refresh = True
                        await self._async_force_token_refresh()
                        continue
                    if resp.status in (401, 403):
                        raise AuthError(f"Graph {resp.status}")
                    if resp.status in RETRYABLE_STATUS and attempt < MAX_RETRIES:
                        attempt += 1
                        await asyncio.sleep(_retry_after(resp.headers))
                        continue
                    resp.raise_for_status()
                    if resp.content_type == "application/json":
                        return await resp.json()
                    return None
            except (asyncio.TimeoutError, ClientConnectionError):
                # Network-level hiccup -> retry a few times, then surface it.
                if attempt < MAX_RETRIES:
                    attempt += 1
                    await asyncio.sleep(DEFAULT_RETRY_AFTER)
                    continue
                raise

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

    async def async_set_status_message(
        self, content: str, expiry_iso: str | None = None
    ) -> None:
        """Set the Teams status message (note). Empty content clears it."""
        message: dict = {"message": {"content": content, "contentType": "text"}}
        if expiry_iso:
            message["expiryDateTime"] = {"dateTime": expiry_iso, "timeZone": "UTC"}
        await self._request(
            "POST", "/me/presence/setStatusMessage", {"statusMessage": message}
        )
