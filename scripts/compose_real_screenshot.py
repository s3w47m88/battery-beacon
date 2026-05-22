#!/usr/bin/env python3
"""Compose a realistic App Store screenshot: real popover render anchored under
a faux macOS menu bar, on a clean dark gradient wallpaper. 2880x1800."""
import sys, math
from PIL import Image, ImageDraw, ImageFilter, ImageFont

POPOVER = sys.argv[1]
OUT = sys.argv[2]

W, H = 2880, 1800

# Gradient wallpaper — deep navy → indigo (Sequoia-ish).
def gradient():
    img = Image.new("RGB", (W, H))
    px = img.load()
    top = (16, 20, 44)
    bot = (40, 24, 70)
    for y in range(H):
        t = y / (H - 1)
        r = int(top[0] * (1 - t) + bot[0] * t)
        g = int(top[1] * (1 - t) + bot[1] * t)
        b = int(top[2] * (1 - t) + bot[2] * t)
        for x in range(W):
            px[x, y] = (r, g, b)
    # Soft radial highlight near top-left.
    overlay = Image.new("RGB", (W, H), (0, 0, 0))
    od = ImageDraw.Draw(overlay)
    od.ellipse((-600, -800, 1800, 1200), fill=(80, 70, 140))
    overlay = overlay.filter(ImageFilter.GaussianBlur(220))
    return Image.blend(img, overlay, 0.35)

canvas = gradient()

# Menu bar — translucent dark strip at top.
MBAR_H = 48
bar = Image.new("RGBA", (W, MBAR_H), (10, 10, 14, 200))
canvas.paste(bar, (0, 0), bar)

def load_font(size, weight="Regular"):
    for p in [
        f"/System/Library/Fonts/SF-Pro-Display-{weight}.otf",
        f"/System/Library/Fonts/SF-Pro-Text-{weight}.otf",
        "/System/Library/Fonts/HelveticaNeue.ttc",
    ]:
        try:
            return ImageFont.truetype(p, size)
        except OSError:
            continue
    return ImageFont.load_default()

draw = ImageDraw.Draw(canvas)

# Left: faux Apple-logo dot + app menu name.
draw.ellipse((22, 14, 42, 34), fill=(230, 230, 235))
fnt_menu = load_font(20, "Semibold")
draw.text((58, 11), "Finder", font=fnt_menu, fill=(235, 235, 240))
for i, label in enumerate(["File", "Edit", "View", "Go", "Window", "Help"]):
    fnt = load_font(20, "Regular")
    draw.text((148 + i * 84, 11), label, font=fnt, fill=(220, 220, 225))

# Right menu bar items: battery%, charging bolt, clock.
clock_text = "Thu May 21  6:24 PM"
ctl_fnt = load_font(20, "Regular")
ct_w = draw.textbbox((0, 0), clock_text, font=ctl_fnt)[2]
clock_x = W - ct_w - 32
draw.text((clock_x, 11), clock_text, font=ctl_fnt, fill=(235, 235, 240))

batt_text = "100%"
bt_w = draw.textbbox((0, 0), batt_text, font=ctl_fnt)[2]
# Battery glyph: rounded rect + nub + fill, with charging bolt.
glyph_x = clock_x - 24 - 56 - 12 - bt_w
draw.text((glyph_x + 56 + 12, 11), batt_text, font=ctl_fnt, fill=(235, 235, 240))
# Battery outline.
bx, by, bw, bh = glyph_x, 16, 46, 20
draw.rounded_rectangle((bx, by, bx + bw, by + bh), radius=5, outline=(230, 230, 235), width=2)
draw.rectangle((bx + bw + 1, by + 6, bx + bw + 4, by + bh - 6), fill=(230, 230, 235))
# Fill.
draw.rounded_rectangle((bx + 3, by + 3, bx + bw - 3, by + bh - 3), radius=2, fill=(80, 220, 130))
# Charging bolt overlay.
bolt = [(bx + 22, by + 4), (bx + 16, by + 12), (bx + 22, by + 12),
        (bx + 18, by + 18), (bx + 28, by + 9), (bx + 22, by + 9)]
draw.polygon(bolt, fill=(255, 255, 255))

# Popover — scale to a sensible size, anchor under battery glyph (top-right).
pop = Image.open(POPOVER).convert("RGBA")
# Target height: leave breathing room top & bottom.
max_h = H - MBAR_H - 220
ratio = min(max_h / pop.height, 880 / pop.width)
new_w = int(pop.width * ratio)
new_h = int(pop.height * ratio)
pop = pop.resize((new_w, new_h), Image.LANCZOS)

# Position: right side, just below menu bar, aligned roughly under battery glyph.
px = W - new_w - 96
py = MBAR_H + 18

# Drop shadow.
shadow = Image.new("RGBA", (new_w + 80, new_h + 80), (0, 0, 0, 0))
sd = ImageDraw.Draw(shadow)
sd.rounded_rectangle((40, 40, new_w + 40, new_h + 40), radius=24, fill=(0, 0, 0, 180))
shadow = shadow.filter(ImageFilter.GaussianBlur(28))
canvas.paste(shadow, (px - 40, py - 30), shadow)

# Rounded-corner mask for popover.
mask = Image.new("L", (new_w, new_h), 0)
md = ImageDraw.Draw(mask)
md.rounded_rectangle((0, 0, new_w, new_h), radius=22, fill=255)
canvas.paste(pop, (px, py), mask)

# Caller note: no marketing text. The screenshot stands on its own.
canvas.save(OUT, "PNG", optimize=True)
print(f"wrote {OUT} ({W}x{H})")
