#!/usr/bin/env python3
"""Render ClickLight icon concept previews.

Draws white glyph variants (4x supersampled, anti-aliased) and composites
each on the brand blue-cyan gradient rounded-rect, mirroring
scripts/render-icon.swift. Outputs a contact sheet + individual PNGs.
"""

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
SS = 4  # supersample factor
S = SIZE * SS
OUT = Path(__file__).parent

GRAD_TOP = (99, 198, 247)      # display-p3-ish 0.38860,0.77688,0.96841
GRAD_BOTTOM = (59, 105, 205)   # 0.23193,0.41350,0.80588
CORNER = 224


def vertical_gradient(size, top, bottom):
    grad = Image.new("RGB", (1, size))
    for y in range(size):
        t = y / (size - 1)
        grad.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return grad.resize((size, size))


def rounded_mask(size, radius):
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return mask


def cursor_polygon(cx, cy, scale, rot_deg=-8):
    """Classic arrow cursor pointing up-left. (cx,cy) = tip point."""
    pts = [
        (0.00, 0.00),
        (0.66, 0.42),
        (0.42, 0.46),
        (0.58, 0.76),
        (0.45, 0.82),
        (0.29, 0.54),
        (0.00, 0.66),
    ]
    rot = math.radians(rot_deg)
    out = []
    for x, y in pts:
        x, y = x * scale, y * scale
        xr = x * math.cos(rot) - y * math.sin(rot)
        yr = x * math.sin(rot) + y * math.cos(rot)
        out.append((cx + xr, cy + yr))
    return out


def draw_ring(d, center, radius, width, fill):
    x, y = center
    d.ellipse([x - radius, y - radius, x + radius, y + radius],
              outline=fill, width=int(width))


def arc_ring(im, center, radius, width, start_deg, end_deg, fill):
    """Anti-aliased thick arc drawn as pieslice ring via arcs on overlay."""
    d = ImageDraw.Draw(im)
    x, y = center
    bbox = [x - radius, y - radius, x + radius, y + radius]
    steps = max(8, int((end_deg - start_deg) * radius / 900))
    for i in range(steps + 1):
        a = math.radians(start_deg + (end_deg - start_deg) * i / steps)
        px, py = x + radius * math.cos(a), y + radius * math.sin(a)
        r = width / 2
        d.ellipse([px - r, py - r, px + r, py + r], fill=fill)


def star(d, cx, cy, r_long, r_short, rot_deg, fill, arms=4):
    pts = []
    for i in range(arms * 2):
        r = r_long if i % 2 == 0 else r_short
        a = math.radians(rot_deg + i * 180.0 / arms)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    d.polygon(pts, fill=fill)


# ---------------- glyph concepts (white on transparent, S x S) ----------------

def glyph_ping():
    """A: cursor + two arcs radiating from tip + tip dot."""
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    tip = (S * 0.40, S * 0.36)
    d.polygon(cursor_polygon(*tip, S * 0.52), fill=(255, 255, 255, 255))
    white = (255, 255, 255, 255)
    soft = (255, 255, 255, 200)
    softer = (255, 255, 255, 150)
    d.ellipse([tip[0] - S*0.045, tip[1] - S*0.045, tip[0] + S*0.045, tip[1] + S*0.045], fill=white)
    arc_ring(im, tip, S * 0.185, S * 0.045, 135, 385, soft)
    arc_ring(im, tip, S * 0.305, S * 0.038, 150, 370, softer)
    return im


def glyph_sonar():
    """B: no cursor — bright core + 3 expanding rings (pulse itself)."""
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = (S * 0.5, S * 0.52)
    d.ellipse([c[0] - S*0.11, c[1] - S*0.11, c[0] + S*0.11, c[1] + S*0.11], fill=(255, 255, 255, 255))
    draw_ring(d, c, S * 0.225, S * 0.055, (255, 255, 255, 235))
    draw_ring(d, c, S * 0.345, S * 0.042, (255, 255, 255, 165))
    draw_ring(d, c, S * 0.455, S * 0.030, (255, 255, 255, 100))
    return im


def glyph_spark():
    """C: cursor with 4-point star flare at the tip (matches Spark effect)."""
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    tip = (S * 0.38, S * 0.40)
    d.polygon(cursor_polygon(*tip, S * 0.50), fill=(255, 255, 255, 255))
    star(d, S * 0.62, S * 0.30, S * 0.16, S * 0.045, 12, (255, 255, 255, 255))
    star(d, S * 0.62, S * 0.30, S * 0.09, S * 0.028, 57, (255, 255, 255, 190))
    d.ellipse([S*0.62 - S*0.035, S*0.30 - S*0.035, S*0.62 + S*0.035, S*0.30 + S*0.035],
              fill=(255, 255, 255, 255))
    return im


def glyph_orbit():
    """D: cursor orbited by a broken ring with a dot satellite."""
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    tip = (S * 0.44, S * 0.44)
    d.polygon(cursor_polygon(*tip, S * 0.46), fill=(255, 255, 255, 255))
    c = (S * 0.47, S * 0.50)
    arc_ring(im, c, S * 0.33, S * 0.048, -40, 200, (255, 255, 255, 220))
    sat_a = math.radians(200)
    sx, sy = c[0] + S * 0.33 * math.cos(sat_a), c[1] + S * 0.33 * math.sin(sat_a)
    d.ellipse([sx - S*0.065, sy - S*0.065, sx + S*0.065, sy + S*0.065], fill=(255, 255, 255, 255))
    return im


def composite(glyph):
    """Mirror render-icon.swift: gradient bg, rounded clip, glyph shadow, sheen."""
    bg = vertical_gradient(SIZE, GRAD_TOP, GRAD_BOTTOM).convert("RGBA")
    mask = rounded_mask(SIZE, CORNER)

    glyph_small = glyph.resize((SIZE, SIZE), Image.LANCZOS)

    # shadow: black silhouette of glyph, offset down, blurred
    alpha = glyph_small.split()[3]
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    black = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 128))
    shadow.paste(black, (0, 28), alpha)
    shadow = shadow.filter(ImageFilter.GaussianBlur(13))

    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    out.paste(bg, (0, 0), mask)
    out = Image.alpha_composite(out, shadow)

    g = glyph_small.copy()
    g.putalpha(g.split()[3].point(lambda a: int(a * 0.92)))
    out = Image.alpha_composite(out, g)

    sheen = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 40))
    sheen.putalpha(Image.composite(sheen.split()[3], Image.new("L", (SIZE, SIZE), 0), mask))
    out = Image.alpha_composite(out, sheen)
    out.putalpha(mask)
    return out


def main():
    concepts = [
        ("A-ping", glyph_ping, "光标 + 波纹扩散"),
        ("B-sonar", glyph_sonar, "纯脉冲：亮点 + 三圈涟漪"),
        ("C-spark", glyph_spark, "光标 + 星芒闪光"),
        ("D-orbit", glyph_orbit, "光标 + 轨道卫星"),
    ]
    tiles = []
    for name, fn, _label in concepts:
        icon = composite(fn())
        icon.save(OUT / f"icon-{name}.png")
        tiles.append((name, icon))
    print("done:", [n for n, _f, _l in concepts])

    pad = 24
    sheet = Image.new("RGBA", (SIZE * 2 + pad * 3, SIZE * 2 + pad * 3), (245, 245, 247, 255))
    for i, (_n, icon) in enumerate(tiles):
        x = pad + (i % 2) * (SIZE + pad)
        y = pad + (i // 2) * (SIZE + pad)
        sheet.paste(icon, (x, y), icon)
    sheet = sheet.resize((1100, 1100), Image.LANCZOS)
    sheet.save(OUT / "contact-sheet.png")

    # Export chosen glyph (white-on-transparent 1024) for AppIcon.icon/Assets
    glyph_spark().resize((SIZE, SIZE), Image.LANCZOS).save(OUT / "glyph-spark.png")


if __name__ == "__main__":
    main()
