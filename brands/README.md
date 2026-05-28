# Brand assets (HACS / Home Assistant icon)

Home Assistant and HACS load an integration's tile icon/logo from the central
**[`home-assistant/brands`](https://github.com/home-assistant/brands)** repo
(served via `brands.home-assistant.io`), **not** from this repository. For a
**custom** integration the assets live under `custom_integrations/<domain>/`.

This folder contains ready-to-submit PNGs for the domain `presenceguard`:

| File | Size |
| --- | --- |
| `custom_integrations/presenceguard/icon.png` | 256×256 |
| `custom_integrations/presenceguard/icon@2x.png` | 512×512 |
| `custom_integrations/presenceguard/logo.png` | 256×256 |
| `custom_integrations/presenceguard/logo@2x.png` | 512×512 |

## How to make the icon show up in HACS/HA

1. Fork `home-assistant/brands`.
2. Copy `custom_integrations/presenceguard/` from here into the fork at the same
   path (`custom_integrations/presenceguard/`).
3. Open a PR against `home-assistant/brands`. Once merged, the icon appears
   automatically in HA and HACS (it is fetched from `brands.home-assistant.io`).

> Until the brands PR is merged, HA/HACS show a generic placeholder – this is
> expected and does not affect functionality.

Source/regeneration: the PNGs are produced by `scripts/generate_brand_icon.py`
(purple Teams-style tile with a white "T" and a green status badge + check).
