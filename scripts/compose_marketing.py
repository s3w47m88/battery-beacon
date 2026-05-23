#!/usr/bin/env python3
"""Compose polished Mac App Store marketing screenshots from real app renders.

Canvas: 2880x1800 (valid Mac size; uniform across the set).
Dark vertical gradient + per-screen radial glow, bold headline + gray subtitle,
real popover art with rounded corners and a soft drop shadow.
"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 2880, 1800
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(REPO, "appstore-screenshots")
OUT = os.path.join(REPO, "appstore-screenshots", "en-US")
os.makedirs(OUT, exist_ok=True)

FONT_PATH = "/System/Library/Fonts/SFNS.ttf"


def font(size, weight="Bold"):
    f = ImageFont.truetype(FONT_PATH, size)
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f


def gradient():
    img = Image.new("RGB", (W, H))
    px = img.load()
    top = (0x0E, 0x0F, 0x16)
    bot = (0x1E, 0x1C, 0x2E)
    for y in range(H):
        t = y / (H - 1)
        row = (
            int(top[0] * (1 - t) + bot[0] * t),
            int(top[1] * (1 - t) + bot[1] * t),
            int(top[2] * (1 - t) + bot[2] * t),
        )
        for x in range(W):
            px[x, y] = row
    return img


def glow(canvas, color, center):
    overlay = Image.new("RGB", (W, H), (0, 0, 0))
    od = ImageDraw.Draw(overlay)
    cx, cy = center
    r = 1100
    od.ellipse((cx - r, cy - r, cx + r, cy + r), fill=color)
    overlay = overlay.filter(ImageFilter.GaussianBlur(360))
    return Image.blend(canvas, overlay, 0.18)


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, img.size[0], img.size[1]), radius=radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


PAD = 180  # shadow padding around art inside the framed layer


def with_shadow(art, blur=60, offset=(0, 30), alpha=160):
    pad = PAD
    layer = Image.new("RGBA", (art.width + pad * 2, art.height + pad * 2), (0, 0, 0, 0))
    shadow = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle(
        (pad + offset[0], pad + offset[1], pad + art.width + offset[0], pad + art.height + offset[1]),
        radius=28, fill=(0, 0, 0, alpha),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    layer = Image.alpha_composite(layer, shadow)
    layer.alpha_composite(art, (pad, pad))
    return layer


def centered_text(draw, y, text, fnt, fill):
    w = draw.textbbox((0, 0), text, font=fnt)[2]
    draw.text(((W - w) / 2, y), text, font=fnt, fill=fill)


def compose(art_path, headline, sub, out_name, target_w=None, target_h=None, glow_color=(90, 80, 160), glow_center=None):
    canvas = gradient()
    canvas = glow(canvas, glow_color, glow_center or (W // 2, 520))
    draw = ImageDraw.Draw(canvas)

    centered_text(draw, 120, headline, font(104, "Bold"), (245, 246, 250))
    centered_text(draw, 250, sub, font(46, "Regular"), (150, 152, 165))

    art = Image.open(art_path).convert("RGBA")
    if target_w:
        ratio = target_w / art.width
    else:
        ratio = target_h / art.height
    # Keep art inside the canvas with room for the headline: art top sits at
    # ART_TOP and must end above the bottom margin.
    ART_TOP, BOTTOM_MARGIN = 380, 80
    max_h = H - ART_TOP - BOTTOM_MARGIN
    max_w = W - 240
    ratio = min(ratio, max_h / art.height, max_w / art.width)
    art = art.resize((int(art.width * ratio), int(art.height * ratio)), Image.LANCZOS)
    art = rounded(art, 28)
    framed = with_shadow(art)

    # Position by the art (not the padded frame): art top-left at (ax, ART_TOP),
    # so the framed layer is offset back by PAD.
    ax = (W - art.width) // 2
    canvas = canvas.convert("RGBA")
    canvas.alpha_composite(framed, (ax - PAD, ART_TOP - PAD))

    out_path = os.path.join(OUT, out_name)
    canvas.convert("RGB").save(out_path, "PNG", optimize=True)
    print(f"wrote {out_name} ({W}x{H})")
    return out_path


if __name__ == "__main__":
    expanded = os.path.join(RAW, "raw-expanded.png")
    collapsed = os.path.join(RAW, "raw-collapsed.png")

    # 1 — collapsed: at-a-glance story
    compose(
        collapsed,
        "Your battery, at a glance",
        "A tidy menu bar popover that expands only when you want the detail.",
        "01-glance-store.png",
        target_w=1600,
        glow_color=(70, 120, 200),
    )

    # 2 — expanded, cropped to the detailed-stats band (health → capacity) so
    # the numbers stay readable instead of shrinking the full 2000px popover.
    src_full = Image.open(expanded).convert("RGB")
    stats_crop = os.path.join(RAW, "raw-stats.png")
    src_full.crop((0, 540, src_full.width, 1095)).save(stats_crop)
    compose(
        stats_crop,
        "Every battery stat, live",
        "Health, temperature, capacity, charge cycles, and power draw — in one place.",
        "02-stats-store.png",
        target_w=1840,
        glow_color=(120, 90, 190),
    )

    # 3 — alerts (crop top of expanded: Battery header + General + Alerts)
    src = Image.open(expanded).convert("RGB")
    alerts_crop = os.path.join(RAW, "raw-alerts.png")
    src.crop((0, 0, src.width, 560)).save(alerts_crop)
    compose(
        alerts_crop,
        "Never overcharge again",
        "Get notified the instant your Mac hits the charge threshold you set.",
        "03-alerts-store.png",
        target_w=1840,
        glow_color=(80, 170, 130),
    )
