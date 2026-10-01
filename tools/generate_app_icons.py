"""Generate Android mipmap + Windows ICO from a source logo image.

Usage:
  python tools/generate_app_icons.py <path-to-source-logo.png>
  python tools/generate_app_icons.py   # defaults to assets/images/app_icon.png
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SRC = ROOT / "assets" / "images" / "app_icon.png"


def trim_near_white(im: Image.Image, threshold: int = 250) -> Image.Image:
    """Crop near-white margins so the logo fills the icon canvas."""
    px = im.load()
    w, h = im.size
    min_x, min_y, max_x, max_y = w, h, 0, 0
    found = False
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 10:
                continue
            if r < threshold or g < threshold or b < threshold:
                found = True
                if x < min_x:
                    min_x = x
                if y < min_y:
                    min_y = y
                if x > max_x:
                    max_x = x
                if y > max_y:
                    max_y = y
    if not found:
        return im
    pad = 2
    min_x = max(0, min_x - pad)
    min_y = max(0, min_y - pad)
    max_x = min(w - 1, max_x + pad)
    max_y = min(h - 1, max_y + pad)
    return im.crop((min_x, min_y, max_x + 1, max_y + 1))


def make_icon(
    logo: Image.Image,
    size: int,
    content_ratio: float = 0.72,
    bg: tuple[int, int, int, int] = (255, 255, 255, 255),
) -> Image.Image:
    """Square icon with logo centered at [content_ratio] of the canvas."""
    canvas = Image.new("RGBA", (size, size), bg)
    target = max(1, int(size * content_ratio))
    lw, lh = logo.size
    scale = min(target / lw, target / lh)
    nw, nh = max(1, int(lw * scale)), max(1, int(lh * scale))
    resized = logo.resize((nw, nh), Image.Resampling.LANCZOS)
    x = (size - nw) // 2
    y = (size - nh) // 2
    canvas.paste(resized, (x, y), resized)
    return canvas


def resolve_src() -> Path:
    if len(sys.argv) >= 2:
        if sys.argv[1] in ("-h", "--help"):
            print(__doc__.strip())
            sys.exit(0)
        path = Path(sys.argv[1]).expanduser().resolve()
        if not path.is_file():
            print(f"error: source image not found: {path}", file=sys.stderr)
            sys.exit(1)
        return path
    if DEFAULT_SRC.is_file():
        return DEFAULT_SRC
    print(
        "error: no source image given and default missing:\n"
        f"  {DEFAULT_SRC}\n"
        "Usage: python tools/generate_app_icons.py <path-to-source-logo.png>",
        file=sys.stderr,
    )
    sys.exit(1)


def main() -> None:
    src_path = resolve_src()
    src = Image.open(src_path).convert("RGBA")
    print(f"Source: {src_path} ({src.size} mode={src.mode})")
    # Master icon is already framed; only trim loose source art.
    logo = src if src_path == DEFAULT_SRC.resolve() else trim_near_white(src)
    print(f"Logo canvas: {logo.size}")

    android_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }

    for folder, size in android_sizes.items():
        out = (
            ROOT
            / "android"
            / "app"
            / "src"
            / "main"
            / "res"
            / folder
            / "ic_launcher.png"
        )
        icon = make_icon(logo, size)
        icon.convert("RGB").save(out, "PNG", optimize=True)
        print(f"Wrote {out.relative_to(ROOT)} ({size}x{size}, {out.stat().st_size} B)")

    assets_dir = ROOT / "assets" / "images"
    assets_dir.mkdir(parents=True, exist_ok=True)
    master_path = assets_dir / "app_icon.png"
    # Avoid re-encoding the default master onto itself when regenerating mipmaps.
    if src_path != master_path.resolve():
        make_icon(logo, 1024).save(master_path, "PNG", optimize=True)
        print(
            f"Wrote {master_path.relative_to(ROOT)} "
            f"(1024x1024, {master_path.stat().st_size} B)"
        )
    else:
        print(f"Kept existing master {master_path.relative_to(ROOT)}")

    ico_sizes = [16, 32, 48, 64, 128, 256]
    ico_images = [make_icon(logo, s).convert("RGBA") for s in ico_sizes]
    ico_path = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    ico_images[-1].save(
        ico_path,
        format="ICO",
        sizes=[(s, s) for s in ico_sizes],
        append_images=ico_images[:-1],
    )
    print(f"Wrote {ico_path.relative_to(ROOT)} ({ico_path.stat().st_size} B)")
    print("Done.")


if __name__ == "__main__":
    main()
