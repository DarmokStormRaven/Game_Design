"""Build the approved Cozy Menu art as uncompressed RGBA WoW textures."""

import argparse
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "mockups/cozy-menu/art"
MEDIA = ROOT / "CozyCouchMode/Media"
EDGE = Path(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe")
CONVERSIONS = [
    ("Tex_Plank_12_bg.png", "sign.tga", (1024, 256)),
    ("Tex_Plank_12_1.png", "sign_socket.tga", (256, 256)),
    ("Tex_frame_c_01.png", "ring.tga", (256, 256)),
    ("Tex_circle_bg.png", "socket.tga", (256, 256)),
    ("Tex_frame.png", "frame.tga", (512, 512)),
    ("Tex_board.png", "board.tga", (512, 512)),
    ("mid_button_off.PNG", "tab_off.tga", (512, 256)),
    ("mid_button_on.PNG", "tab_on.tga", (512, 256)),
    ("Tex_bg_01_02.png", "parchment.tga", (512, 512)),
    ("Tex_title.png", "ribbon.tga", (512, 128)),
    ("tex_butn_plank.png", "chip.tga", (256, 128)),
    ("Tex_obj_06_01.png", "toast.tga", (512, 128)),
    ("Tex_Plank_07.png", "plank_tag.tga", (512, 128)),
    ("Cursor_Production.PNG", "icon_gather.tga", (64, 64)),
    ("Cursor_book.PNG", "icon_book.tga", (64, 64)),
    ("Cursor_Attack.PNG", "icon_sword.tga", (64, 64)),
    ("Cursor_Move1.PNG", "icon_move.tga", (64, 64)),
    ("Cursor_Settings.PNG", "icon_gear.tga", (64, 64)),
    ("Cursor_Hand.PNG", "icon_hand.tga", (64, 64)),
    ("Cursor_Hand2.PNG", "icon_fist.tga", (64, 64)),
    ("Cursor_loot.PNG", "icon_loot.tga", (64, 64)),
    ("Cursor_Flask.PNG", "icon_flask.tga", (64, 64)),
    ("Cursor_Deff.PNG", "icon_shield.tga", (64, 64)),
    ("option_button.PNG", "icon_gem.tga", (128, 128)),
]


def resize(image, size):
    return image.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")


def save(image, name, outputs):
    image.save(MEDIA / name, format="TGA")
    outputs[name] = image.size


def build_hearth_art(outputs):
    scale = 4

    def canvas(size):
        return Image.new("RGBA", (size * scale, size * scale))

    def finish(image, name, size):
        save(resize(image, (size, size)), name, outputs)

    circle = canvas(64)
    ImageDraw.Draw(circle).ellipse((4, 4, 251, 251), fill="white")
    finish(circle, "circle_white.tga", 64)

    gradient = Image.radial_gradient("L").resize((512, 512), Image.LANCZOS)
    # Pillow's gradient reaches white at the corners; normalize to the radius.
    alpha = gradient.point(lambda value: round(255 * max(0, 1 - math.sqrt(2) * value / 255) ** 1.6))
    glow = Image.new("RGBA", (512, 512), "white")
    glow.putalpha(alpha)
    finish(glow, "glow_round.tga", 128)

    ring = canvas(128)
    draw = ImageDraw.Draw(ring)
    draw.ellipse((8, 8, 503, 503), fill="white")
    draw.ellipse((28, 28, 483, 483), fill=(0, 0, 0, 0))
    finish(ring, "ring_thin.tga", 128)

    # A blurred elliptical highlight and lower inner crescent give icons depth.
    mask = Image.new("L", (512, 512))
    ImageDraw.Draw(mask).ellipse((8, 8, 503, 503), fill=255)
    highlight = Image.new("L", (512, 512))
    ImageDraw.Draw(highlight).ellipse(
        (256 - 248 * 0.70, 8 + 496 * 0.12,
         256 + 248 * 0.70, 8 + 496 * 0.57), fill=round(255 * 0.22)
    )
    highlight = highlight.filter(ImageFilter.GaussianBlur(6 * scale))
    shadow = Image.new("L", (512, 512))
    shadow.putdata([
        round(255 * 0.35 * math.exp(-((math.hypot(x + 0.5 - 256, y + 0.5 - 256) - 232) / 24) ** 2)
              * max(0, (y + 0.5 - 256) / 248) ** 1.6)
        for y in range(512) for x in range(512)
    ])
    shade = Image.new("RGBA", (512, 512), "black")
    shade.putalpha(shadow)
    light = Image.new("RGBA", (512, 512), "white")
    light.putalpha(highlight)
    shade = Image.alpha_composite(shade, light)
    clipped = canvas(128)
    clipped.paste(shade, (0, 0), mask)
    finish(clipped, "socket_shade.tga", 128)

    disc = Image.new("RGBA", (1024, 1024), (40, 26, 14, 0))
    alpha = Image.new("L", disc.size)
    alpha.putdata([
        round(255 * 0.55 * (lambda t: t * t * (3 - 2 * t))(
            max(0, min(1, (0.70 - math.hypot(x + 0.5 - 512, y + 0.5 - 512) / 512) / 0.25))))
        for y in range(1024) for x in range(1024)
    ])
    disc.putalpha(alpha)
    radius = 512 * 0.98
    ImageDraw.Draw(disc).ellipse(
        (512 - radius, 512 - radius, 511 + radius, 511 + radius),
        outline=(185, 139, 78, round(255 * 0.18)), width=2 * scale,
    )
    finish(disc, "base_disc.tga", 256)

    arrow = canvas(32)
    ImageDraw.Draw(arrow).polygon(((64, 26), (102, 102), (26, 102)), fill="white")
    for direction, angle in (("up", 0), ("down", 180), ("left", 90), ("right", 270)):
        finish(arrow.rotate(angle), f"glyph_{direction}.tga", 32)


def build_glyphs(outputs):
    markup = (ROOT / "mockups/cozy-menu/index.html").read_text(encoding="utf-8")
    match = re.search(r'<div class="medal-lg">\s*(<svg\b.*?</svg>)', markup, re.DOTALL)
    if match is None:
        raise ValueError("Controller SVG missing from .medal-lg in mockup")
    controller = match.group(1).replace('<svg ', '<svg width="480" height="315" ', 1)
    glyphs = [
        ("glyph_controller.tga", 512, controller, (128, 128)),
        ("glyph_dpad.tga", 256, '<svg width="240" height="240" viewBox="0 0 20 20"><path d="M8 2h4v6h6v4h-6v6H8v-6H2V8h6z" fill="#f5e8c8"/></svg>', (64, 64)),
        ("glyph_view.tga", 256, '<svg width="240" height="240" viewBox="0 0 20 20"><rect x="3" y="3" width="10" height="9" rx="2" fill="none" stroke="#f5e8c8" stroke-width="1.8"/><rect x="7" y="8" width="10" height="9" rx="2" fill="#2a160c" stroke="#f5e8c8" stroke-width="1.8"/></svg>', (64, 64)),
        ("gem.tga", 256, '<div style="width:200px;height:200px;border-radius:50%;background:radial-gradient(circle at 38% 32%,#5a3d27,#1c1008 70%);box-shadow:0 0 0 12px #24150a,0 0 0 24px #b98b4e"></div>', (64, 64)),
    ]
    temp_dirs = []
    try:
        for name, window, content, size in glyphs:
            folder = Path(tempfile.mkdtemp(prefix="cozy-art-"))
            temp_dirs.append(folder)
            profile = Path(tempfile.mkdtemp(prefix="cozy-edge-"))
            temp_dirs.append(profile)
            html = folder / "glyph.html"
            png = folder / "glyph.png"
            html.write_text(
                f'<html><body style="margin:0;background:transparent;width:{window}px;'
                f'height:{window}px;display:flex;align-items:center;justify-content:center">'
                f'{content}</body></html>', encoding="utf-8"
            )
            subprocess.run([
                str(EDGE), "--headless=new", "--disable-gpu", "--hide-scrollbars",
                "--default-background-color=00000000", f"--user-data-dir={profile}",
                f"--window-size={window},{window}", f"--screenshot={png}", html.as_uri(),
            ], check=True, timeout=60)
            with Image.open(png) as image:
                save(resize(image.convert("RGBA"), size), name, outputs)
    finally:
        for folder in reversed(temp_dirs):
            try:
                shutil.rmtree(folder)
            except OSError as error:
                print(f"WARNING: Could not remove temporary folder {folder}: {error}")


def copy_font():
    source = Path(os.environ["LOCALAPPDATA"]) / "Microsoft/Windows/Fonts/MelonHoneyRegular-Rp1Y6.ttf"
    if not source.exists():
        print(f"WARNING: Font missing: {source}; the game will use its fallback font.")
        return
    target = MEDIA / "Fonts/MelonHoney.ttf"
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)
    print(f"Font: {target.relative_to(ROOT)}  {target.stat().st_size / 1024:.2f} KB")


def self_check(outputs):
    total = 0
    for name, size in outputs.items():
        path = MEDIA / name
        with Image.open(path) as image:
            image.load()
            assert image.mode == "RGBA", f"{name}: expected RGBA"
            assert image.size == size, f"{name}: expected {size}, got {image.size}"
            assert all(n > 0 and n & (n - 1) == 0 for n in image.size), f"{name}: not power-of-two"
        with path.open("rb") as stream:
            header = stream.read(18)
        assert header[2] == 2, f"{name}: not uncompressed true-color"
        assert header[16] == 32, f"{name}: not 32-bit"
        length = path.stat().st_size
        total += length
        print(f"{name}  {size[0]}x{size[1]}  {length / 1024:.2f} KB")
    print(f"Total: {len(outputs)} TGA files  {total / 1024:.2f} KB ({total:,} bytes)")


def preview(path, outputs):
    columns, cell_width, cell_height = 5, 180, 150
    sheet = Image.new("RGBA", (columns * cell_width, ((len(outputs) + columns - 1) // columns) * cell_height), (128, 128, 128, 255))
    draw = ImageDraw.Draw(sheet)
    for index, name in enumerate(outputs):
        x, y = (index % columns) * cell_width, (index // columns) * cell_height
        with Image.open(MEDIA / name) as image:
            scale = min(160 / image.width, 120 / image.height)
            thumb = resize(image, (max(1, round(image.width * scale)), max(1, round(image.height * scale))))
        sheet.alpha_composite(thumb, (x + (cell_width - thumb.width) // 2, y + (120 - thumb.height) // 2))
        draw.text((x + cell_width // 2, y + 125), name, fill="white", anchor="mt")
    path = ROOT / path
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path, format="PNG")
    print(f"Preview: {path}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preview", type=Path, help="Optional PNG contact sheet (relative to repo root)")
    args = parser.parse_args()
    MEDIA.mkdir(parents=True, exist_ok=True)
    outputs = {}
    try:
        build_hearth_art(outputs)
        for source, name, size in CONVERSIONS:
            with Image.open(ART / source) as image:
                save(resize(image.convert("RGBA"), size), name, outputs)
        with Image.open(ART / "Tex_bg_01_02.png") as image:
            parchment = resize(image.convert("RGBA"), (400, 400))
        canvas = Image.new("RGBA", (512, 512))
        canvas.paste(parchment, (56, 56))
        alpha = canvas.getchannel("A").filter(ImageFilter.GaussianBlur(14))
        alpha = alpha.point(lambda value: min(255, round(value * 1.4)))
        glow = Image.new("RGBA", (512, 512), (255, 196, 90, 0))
        glow.putalpha(alpha)
        # Game contract: centered on the card at 1.28 times its size.
        save(glow, "parchment_glow.tga", outputs)
        build_glyphs(outputs)
        copy_font()
    finally:
        self_check(outputs)
    assert len(outputs) == 38, "Expected all 38 TGA outputs"
    if args.preview:
        preview(args.preview, outputs)


if __name__ == "__main__":
    main()
