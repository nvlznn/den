#!/usr/bin/env python3
"""把 Den/Pet/PetSprites.swift 裡所有角色的所有影格畫成一張預覽圖。

用法（在 repo 根目錄）：
    python3 tools/render_sprites.py
會產生 tools/sprites-preview.png。需要 Pillow（pip install pillow）。

每一列是一隻角色，每一欄是一個影格，配色和 app 裡的 LCD 一樣。
"""
import pathlib
import re

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Den/Pet/PetSprites.swift"
OUTPUT = pathlib.Path(__file__).resolve().parent / "sprites-preview.png"

FRAMES = [("idle", "Idle"), ("blink", "Blink"), ("study1", "Reading 1"), ("study2", "Reading 2"), ("sleep", "Sleep"), ("happy", "Happy")]
BACKGROUND, LIT, UNLIT = (0x9D, 0xAD, 0x86), (0x2A, 0x32, 0x25), (0x94, 0xA4, 0x7E)
CELL, PAD, LABEL_W, HEADER_H = 12, 18, 120, 40


def load_characters():
    source = SOURCE.read_text()
    characters = []
    pattern = r'static let \w+ = PetCharacter\(\s*id: "(\w+)",\s*name: "([^"]+)",(.*?)\n    \)'
    for match in re.finditer(pattern, source, re.S):
        _, name, body = match.groups()
        frames = {
            key: re.findall(r'"([.#]+)"', rows)
            for key, rows in re.findall(r"(\w+): \[(.*?)\]", body, re.S)
        }
        characters.append((name, frames))
    return characters


def font(size):
    for path in ["/System/Library/Fonts/SFNS.ttf", "/System/Library/Fonts/Helvetica.ttc"]:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def main():
    characters = load_characters()
    # 看書的影格比 16 列高，格子高度取最高的那一格。
    max_rows = max(len(rows) for _, frames in characters for rows in frames.values())
    tile = 18 * CELL
    tile_h = (max_rows + 2) * CELL
    width = PAD + LABEL_W + len(FRAMES) * (tile + PAD)
    height = PAD + HEADER_H + len(characters) * (tile_h + PAD)
    image = Image.new("RGB", (width, height), (250, 250, 248))
    draw = ImageDraw.Draw(image)
    label_font, header_font = font(22), font(18)

    for column, (_, title) in enumerate(FRAMES):
        draw.text((PAD + LABEL_W + column * (tile + PAD), PAD), title, fill=(90, 90, 90), font=header_font)

    for row, (name, frames) in enumerate(characters):
        y0 = PAD + HEADER_H + row * (tile_h + PAD)
        draw.text((PAD, y0 + tile_h // 2 - 12), name, fill=(30, 30, 30), font=label_font)
        for column, (key, _) in enumerate(FRAMES):
            x0 = PAD + LABEL_W + column * (tile + PAD)
            draw.rectangle([x0, y0, x0 + tile, y0 + tile_h], fill=BACKGROUND)
            for y, line in enumerate(frames.get(key, [])):
                for x, pixel in enumerate(line):
                    px, py = x0 + (x + 1) * CELL, y0 + (y + 1) * CELL
                    draw.rectangle([px, py, px + CELL - 2, py + CELL - 2], fill=LIT if pixel == "#" else UNLIT)

    image.save(OUTPUT)
    print(f"Wrote {OUTPUT.relative_to(ROOT)} ({len(characters)} characters × {len(FRAMES)} frames)")


if __name__ == "__main__":
    main()
