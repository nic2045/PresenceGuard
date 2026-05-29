"""Generate PresenceGuard brand icons (Teams-style tile + green status check).

Renders supersampled with Pillow and downscales (LANCZOS).
Outputs icon.png/icon@2x.png/logo.png/logo@2x.png under
brands/custom_integrations/presenceguard/.
"""
from PIL import Image, ImageDraw, ImageChops

S = 1024
OUT = "custom_components/presenceguard/brand"


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def render(size):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    # --- Teams-style purple squircle with vertical gradient ---
    top, bot = (0x6E, 0x72, 0xD6), (0x44, 0x49, 0xA8)
    grad = Image.new("RGBA", (S, S))
    gp = grad.load()
    for y in range(S):
        c = lerp(top, bot, y / (S - 1))
        for x in range(S):
            gp[x, y] = (c[0], c[1], c[2], 255)
    tile = Image.new("L", (S, S), 0)
    m = 0.0  # full-bleed (brands requires trimmed icons)
    ImageDraw.Draw(tile).rounded_rectangle(
        [m, m, S - m, S - m], radius=0.23 * S, fill=255
    )
    img.paste(grad, (0, 0), tile)

    d = ImageDraw.Draw(img)

    # --- white "T" (classic Teams glyph), nudged up-left for the badge ---
    white = (255, 255, 255, 255)
    # top bar
    d.rounded_rectangle([0.255 * S, 0.265 * S, 0.675 * S, 0.375 * S],
                        radius=0.03 * S, fill=white)
    # stem
    d.rounded_rectangle([0.408 * S, 0.265 * S, 0.522 * S, 0.70 * S],
                        radius=0.03 * S, fill=white)

    # --- green status badge with a transparent ring cut-out, bottom-right ---
    bx, by = 0.735 * S, 0.735 * S
    br = 0.205 * S
    ring = 0.045 * S
    # punch a transparent gap so the badge stands off the tile
    hole = Image.new("L", (S, S), 0)
    ImageDraw.Draw(hole).ellipse(
        [bx - br - ring, by - br - ring, bx + br + ring, by + br + ring], fill=255
    )
    img.putalpha(ImageChops.subtract(img.getchannel("A"), hole))

    d = ImageDraw.Draw(img)
    green = (0x4C, 0xA3, 0x2B, 255)  # presence "available" green
    d.ellipse([bx - br, by - br, bx + br, by + br], fill=green)
    # white check inside the badge (rounded)
    w = int(0.052 * S)
    a = (bx - 0.085 * S, by + 0.005 * S)
    b = (bx - 0.015 * S, by + 0.075 * S)
    c = (bx + 0.105 * S, by - 0.075 * S)
    d.line([a, b, c], fill=white, width=w, joint="curve")
    for p in (a, b, c):
        d.ellipse([p[0] - w / 2, p[1] - w / 2, p[0] + w / 2, p[1] + w / 2], fill=white)

    return img.resize((size, size), Image.LANCZOS)


for name, size in [("icon.png", 256), ("icon@2x.png", 512),
                   ("logo.png", 256), ("logo@2x.png", 512)]:
    render(size).save(f"{OUT}/{name}")
print("written")
