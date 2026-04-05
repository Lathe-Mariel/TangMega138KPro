#!/usr/bin/env python3
"""
==============================================================================
gen_font_rom.py
Project  : DVI Frame Buffer with Image Composer
Board    : Tang Mega 138K Pro Dock (GW5AST-LV138FPG676A)
Updated  : 2026-04-04

Function:
  Renders the string "Lathe" into a 320x100 bitmap using a TrueType font,
  then exports it in three formats:
    1. lathe_font.hex   – $readmemh-compatible hex for Verilog font_rom
    2. lathe_font.png   – Visual verification image (white on black)
    3. lathe_font_inv.png – Inverted image for readability check

Usage:
  python3 gen_font_rom.py [options]

Options:
  --font    PATH   TrueType font file (default: DejaVuSans-Bold.ttf)
  --size    INT    Font point size    (default: 90)
  --text    STR    String to render   (default: "Lathe")
  --out     DIR    Output directory   (default: current directory)
  --preview        Print ASCII preview to terminal

ROM format (lathe_font.hex):
  - 100 lines, one per row of the bitmap
  - Each line is a 320-bit value encoded as 80 hex digits (MSB = leftmost pixel)
  - Bit[319] = pixel at x=0, Bit[0] = pixel at x=319
  - Compatible with: reg [319:0] font_rom [0:99];
                     $readmemh("lathe_font.hex", font_rom);

Verilog read access:
  pixel_on = font_rom[ly][319 - lx];
==============================================================================
"""

import argparse
import os
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("ERROR: Pillow not installed. Run: pip install Pillow")
    sys.exit(1)


# ---------------------------------------------------------------------------
# Default parameters (must match image_composer.v constants)
# ---------------------------------------------------------------------------
TXT_W       = 320       # Text area width  (TXT_X1 - TXT_X0 = 1870 - 1550)
TXT_H       = 100       # Text area height (TXT_Y1 - TXT_Y0 = 1030 - 930)
DEFAULT_TEXT = "Lathe"
DEFAULT_FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
DEFAULT_SIZE = 90


# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
def parse_args():
    p = argparse.ArgumentParser(description="Generate Verilog font ROM for 'Lathe' overlay")
    p.add_argument("--font",    default=DEFAULT_FONT, help="TrueType font path")
    p.add_argument("--size",    type=int, default=DEFAULT_SIZE, help="Font point size")
    p.add_argument("--text",    default=DEFAULT_TEXT, help="String to render")
    p.add_argument("--out",     default=".",           help="Output directory")
    p.add_argument("--preview", action="store_true",   help="Print ASCII preview")
    return p.parse_args()


# ---------------------------------------------------------------------------
# Render text into a 1-bit PIL image
# ---------------------------------------------------------------------------
def render_text(font_path: str, font_size: int, text: str,
                width: int, height: int) -> Image.Image:
    """
    Renders `text` centered in a `width` x `height` 1-bit image.
    Returns PIL Image in mode "1".
    """
    if not os.path.exists(font_path):
        raise FileNotFoundError(f"Font not found: {font_path}")

    font = ImageFont.truetype(font_path, font_size)
    img  = Image.new("1", (width, height), 0)   # black background
    draw = ImageDraw.Draw(img)

    # Measure text bounding box
    bbox = draw.textbbox((0, 0), text, font=font)
    tw   = bbox[2] - bbox[0]
    th   = bbox[3] - bbox[1]

    # Warn if text overflows the area
    if tw > width:
        print(f"WARNING: text width {tw}px exceeds area width {width}px – consider smaller --size")
    if th > height:
        print(f"WARNING: text height {th}px exceeds area height {height}px – consider smaller --size")

    # Center the text
    x = (width  - tw) // 2 - bbox[0]
    y = (height - th) // 2 - bbox[1]

    draw.text((x, y), text, font=font, fill=1)

    print(f"Font    : {os.path.basename(font_path)}  size={font_size}pt")
    print(f"Text    : '{text}'  bbox={tw}x{th}px  placed at ({x},{y})")
    pixels_on = sum(1 for p in img.getdata() if p)
    print(f"Active  : {pixels_on} / {width*height} pixels ({100*pixels_on/(width*height):.1f}%)")

    return img


# ---------------------------------------------------------------------------
# Export to $readmemh-compatible hex file
# ---------------------------------------------------------------------------
def export_hex(img: Image.Image, out_path: str):
    """
    Exports the 1-bit image as a hex file for Verilog $readmemh.

    Format:
      One hex value per row.
      Each row is TXT_W bits wide → TXT_W/4 hex digits.
      MSB of the hex value = leftmost pixel (x=0).
      LSB of the hex value = rightmost pixel (x=TXT_W-1).

    Example (TXT_W=320): 80 hex digits per line.
    """
    width, height = img.size
    hex_digits = width // 4   # number of hex chars per row

    with open(out_path, "w") as f:
        for row in range(height):
            # Build integer: bit[width-1] = pixel(0), bit[0] = pixel(width-1)
            row_val = 0
            for col in range(width):
                pixel = img.getpixel((col, row))
                if pixel:
                    row_val |= (1 << (width - 1 - col))
            f.write(f"{row_val:0{hex_digits}x}\n")

    print(f"HEX     : {out_path}  ({height} lines x {hex_digits} hex digits)")


# ---------------------------------------------------------------------------
# Export PNG previews
# ---------------------------------------------------------------------------
def export_png(img: Image.Image, out_path: str, scale: int = 2):
    """Saves the bitmap as a scaled PNG for visual verification."""
    # Convert 1-bit to RGB (white on black)
    rgb = Image.new("RGB", img.size, (0, 0, 0))
    for y in range(img.height):
        for x in range(img.width):
            if img.getpixel((x, y)):
                rgb.putpixel((x, y), (255, 255, 255))
    # Scale up for visibility
    rgb_scaled = rgb.resize((img.width * scale, img.height * scale),
                            Image.NEAREST)
    rgb_scaled.save(out_path)
    print(f"PNG     : {out_path}  ({rgb_scaled.width}x{rgb_scaled.height}px)")


# ---------------------------------------------------------------------------
# ASCII terminal preview
# ---------------------------------------------------------------------------
def ascii_preview(img: Image.Image, sample_x: int = 4, sample_y: int = 2):
    """Prints a downsampled ASCII preview of the bitmap."""
    w, h = img.size
    cols = w // sample_x
    print(f"\nASCII preview (1:{sample_x}x{sample_y} sample):")
    print("+" + "-" * cols + "+")
    for row in range(0, h, sample_y):
        line = "|"
        for col in range(0, w, sample_x):
            line += "█" if img.getpixel((col, row)) else " "
        line += "|"
        print(line)
    print("+" + "-" * cols + "+")


# ---------------------------------------------------------------------------
# Verify hex file round-trip
# ---------------------------------------------------------------------------
def verify_hex(hex_path: str, img: Image.Image) -> bool:
    """Reads back the hex file and compares with original bitmap."""
    width, height = img.size
    errors = 0
    with open(hex_path) as f:
        for row, line in enumerate(f):
            row_val = int(line.strip(), 16)
            for col in range(width):
                expected = 1 if img.getpixel((col, row)) else 0
                actual   = (row_val >> (width - 1 - col)) & 1
                if expected != actual:
                    errors += 1
    if errors == 0:
        print("Verify  : OK – hex file matches bitmap perfectly")
        return True
    else:
        print(f"Verify  : FAIL – {errors} pixel mismatches")
        return False


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    args = parse_args()

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    hex_path     = str(out_dir / "lathe_font.hex")
    png_path     = str(out_dir / "lathe_font.png")
    png_inv_path = str(out_dir / "lathe_font_inv.png")

    print("=" * 60)
    print("  Font ROM Generator for 'Lathe' text overlay")
    print(f"  Target area : {TXT_W} x {TXT_H} px")
    print("=" * 60)

    # 1. Render
    img = render_text(args.font, args.size, args.text, TXT_W, TXT_H)

    # 2. ASCII preview
    if args.preview:
        ascii_preview(img)

    # 3. Export hex
    export_hex(img, hex_path)

    # 4. Export PNG (white on black)
    export_png(img, png_path, scale=3)

    # 5. Export inverted PNG (black on white – easier to read on screen)
    img_inv = img.convert("L").point(lambda p: 255 - p * 255)
    img_inv_rgb = img_inv.convert("RGB")
    img_inv_scaled = img_inv_rgb.resize(
        (img.width * 3, img.height * 3), Image.NEAREST)
    img_inv_scaled.save(png_inv_path)
    print(f"PNG inv : {png_inv_path}")

    # 6. Verify round-trip
    verify_hex(hex_path, img)

    # 7. Print Verilog snippet
    print()
    print("=" * 60)
    print("  Verilog integration:")
    print("=" * 60)
    print("""
  // In image_composer.v, replace the initial block with:
  initial begin
      $readmemh("lathe_font.hex", font_rom);
  end

  // Ensure font_rom is declared as:
  reg [319:0] font_rom [0:99];

  // Pixel access (1 cycle latency):
  font_pixel <= font_rom[ly_r][319 - lx_r];
""")

    print("Done.")


if __name__ == "__main__":
    main()
