#!/usr/bin/env python3
"""Generates high-DPI anti-aliased launcher icons for Accounting App."""

from pathlib import Path
from PIL import Image, ImageDraw

REPO_ROOT = Path(__file__).resolve().parent.parent
RES_DIR = REPO_ROOT / "android" / "app" / "src" / "main" / "res"
ASSETS_ICON_DIR = REPO_ROOT / "assets" / "icon"
WINDOWS_ICO_PATH = REPO_ROOT / "windows" / "runner" / "resources" / "app_icon.ico"


def _lerp_color(c1, c2, t: float):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(4))


def render_background(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), (6, 40, 34, 255))
    px = img.load()
    c_top = (6, 40, 34, 255)       # Deep Emerald 950
    c_mid = (6, 78, 59, 255)       # Emerald 900
    c_bot = (15, 118, 110, 255)    # Teal 700
    for y in range(size):
        for x in range(size):
            t = (x + y) / max(1, (2 * size - 2))
            if t < 0.55:
                col = _lerp_color(c_top, c_mid, t / 0.55)
            else:
                col = _lerp_color(c_mid, c_bot, (t - 0.55) / 0.45)
            px[x, y] = col

    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    pad = int(size * 0.14)
    gdraw.ellipse(
        [pad, pad, size - pad, size - pad],
        fill=(16, 185, 129, 34),
    )
    return Image.alpha_composite(img, glow)


def render_foreground(size: int, full_bleed: bool = False) -> Image.Image:
    ss = 4
    canvas_sz = size * ss
    img = Image.new("RGBA", (canvas_sz, canvas_sz), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    scale = 1.24 if full_bleed else 1.0

    def pt(v: float) -> float:
        centered = (v - 54.0) * scale + 54.0
        return centered * (canvas_sz / 108.0)

    x0, y0, x1, y1 = pt(25), pt(22), pt(83), pt(86)
    radius = int(6.5 * scale * (canvas_sz / 108.0))
    stroke_w = max(2, int(2.0 * scale * (canvas_sz / 108.0)))

    # Ledger card background
    draw.rounded_rectangle(
        [x0, y0, x1, y1],
        radius=radius,
        fill=(248, 250, 252, 255),
        outline=(52, 211, 153, 255),
        width=stroke_w,
    )

    # Top header bar
    hy = pt(35)
    draw.rounded_rectangle(
        [x0 + stroke_w, y0 + stroke_w, x1 - stroke_w, hy],
        radius=max(2, radius // 2),
        fill=(16, 185, 129, 255),
    )

    # Center vertical ledger column divider (Debit | Credit)
    cx = pt(54)
    div_w = max(2, int(1.6 * scale * (canvas_sz / 108.0)))
    draw.line([(cx, hy), (cx, y1 - pt(6))], fill=(203, 213, 225, 255), width=div_w)

    # Ledger rows
    lw = max(3, int(3.0 * scale * (canvas_sz / 108.0)))
    for row_y, l_col, r_col in [
        (45.0, (15, 23, 42, 255), (16, 185, 129, 255)),
        (56.0, (100, 116, 139, 255), (16, 185, 129, 255)),
        (67.0, (100, 116, 139, 255), (245, 158, 11, 255)),
        (77.0, (15, 23, 42, 255), (15, 23, 42, 255)),
    ]:
        draw.line([(pt(31), pt(row_y)), (pt(49), pt(row_y))], fill=l_col, width=lw)
        draw.line([(pt(59), pt(row_y)), (pt(77), pt(row_y))], fill=r_col, width=lw)

    return img.resize((size, size), Image.Resampling.LANCZOS)


def render_combined_icon(size: int, circular: bool = False) -> Image.Image:
    bg = render_background(size)
    fg = render_foreground(size, full_bleed=True)
    merged = Image.alpha_composite(bg, fg)

    mask = Image.new("L", (size * 4, size * 4), 0)
    mdraw = ImageDraw.Draw(mask)
    if circular:
        pad = int(size * 4 * 0.02)
        mdraw.ellipse([pad, pad, size * 4 - pad, size * 4 - pad], fill=255)
    else:
        pad = int(size * 4 * 0.04)
        rad = int(size * 4 * 0.22)
        mdraw.rounded_rectangle(
            [pad, pad, size * 4 - pad, size * 4 - pad],
            radius=rad,
            fill=255,
        )
    mask = mask.resize((size, size), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(merged, (0, 0), mask)
    return out


def main():
    ASSETS_ICON_DIR.mkdir(parents=True, exist_ok=True)
    master = render_combined_icon(1024, circular=False)
    master.save(ASSETS_ICON_DIR / "app_icon.png", "PNG")

    WINDOWS_ICO_PATH.parent.mkdir(parents=True, exist_ok=True)
    ico_sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    master.save(WINDOWS_ICO_PATH, format="ICO", sizes=ico_sizes)

    densities = {
        "mipmap-mdpi": (48, 108),
        "mipmap-hdpi": (72, 162),
        "mipmap-xhdpi": (96, 216),
        "mipmap-xxhdpi": (144, 324),
        "mipmap-xxxhdpi": (192, 432),
    }

    for folder, (legacy_sz, fg_sz) in densities.items():
        target = RES_DIR / folder
        target.mkdir(parents=True, exist_ok=True)
        render_combined_icon(legacy_sz, circular=False).save(target / "ic_launcher.png", "PNG")
        render_combined_icon(legacy_sz, circular=True).save(target / "ic_launcher_round.png", "PNG")
        render_foreground(fg_sz, full_bleed=False).save(target / "ic_launcher_foreground.png", "PNG")

    print("Generated Accounting App launcher icons.")


if __name__ == "__main__":
    main()
