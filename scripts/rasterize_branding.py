#!/usr/bin/env python3
# ==============================================================================
# 🎨 LIPI BRANDING RASTERIZER & ASSET GENERATOR (scripts/rasterize_branding.py)
# ⚡ Renders pixel-perfect multi-resolution icons & social preview cards
# using Headless Chrome (for exact SVG CSS mix-blend-mode) and Pillow LANCZOS.
# ==============================================================================

import os
import subprocess
import tempfile
from PIL import Image, ImageDraw, ImageFont

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.dirname(SCRIPT_DIR)
BRAND_DIR = os.path.join(ROOT_DIR, "assets", "branding")
PNG_DIR = os.path.join(BRAND_DIR, "png")
os.makedirs(PNG_DIR, exist_ok=True)

def render_svg_to_png(svg_path, output_png_path, width, height):
    """Renders an SVG file to exact pixel dimensions via Google Chrome headless."""
    with open(svg_path, "r", encoding="utf-8") as f:
        svg_content = f.read()

    html_content = f"""<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  html, body {{
    margin: 0;
    padding: 0;
    width: {width}px;
    height: {height}px;
    background: transparent;
    overflow: hidden;
  }}
  svg {{
    width: 100%;
    height: 100%;
    display: block;
  }}
</style>
</head>
<body>
{svg_content}
</body>
</html>
"""
    with tempfile.NamedTemporaryFile(mode="w", suffix=".html", delete=False) as tmp_html:
        tmp_html.write(html_content)
        tmp_html_path = tmp_html.name

    try:
        cmd = [
            "google-chrome",
            "--headless=new",
            "--disable-gpu",
            "--no-sandbox",
            f"--window-size={width},{height}",
            f"--screenshot={output_png_path}",
            f"file://{tmp_html_path}"
        ]
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if res.returncode != 0:
            print(f"Warning: Chrome returned {res.returncode}: {res.stderr.decode()}")
    finally:
        if os.path.exists(tmp_html_path):
            os.remove(tmp_html_path)

def generate_all_assets():
    mark_svg = os.path.join(BRAND_DIR, "lipi_mark.svg")
    logo_svg = os.path.join(BRAND_DIR, "lipi_logo.svg")
    
    print("🎨 Rendering 1024x1024 Master Mark via Headless Chrome...")
    master_mark_png = os.path.join(PNG_DIR, "lipi_icon_1024x1024.png")
    render_svg_to_png(mark_svg, master_mark_png, 1024, 1024)

    print("🎨 Rendering 1024x1024 Master Full Logo via Headless Chrome...")
    master_logo_png = os.path.join(PNG_DIR, "lipi_logo_1024x1024.png")
    render_svg_to_png(logo_svg, master_logo_png, 1024, 1024)

    # Open rendered master mark with Pillow
    img_mark = Image.open(master_mark_png).convert("RGBA")

    # Generate standard icon sizes
    sizes = [16, 32, 48, 64, 128, 256, 512]
    ico_images = []
    for s in sizes:
        resized = img_mark.resize((s, s), Image.Resampling.LANCZOS)
        out_path = os.path.join(PNG_DIR, f"lipi_icon_{s}x{s}.png")
        resized.save(out_path, "PNG")
        print(f"  ✔ Saved {out_path} ({s}x{s})")
        if s in [16, 32, 48]:
            ico_images.append(resized)

    # Generate multi-resolution favicon.ico
    favicon_ico_path = os.path.join(BRAND_DIR, "favicon.ico")
    ico_images[0].save(
        favicon_ico_path,
        format="ICO",
        sizes=[(16, 16), (32, 32), (48, 48)],
        append_images=ico_images[1:]
    )
    print(f"  ✔ Saved multi-resolution {favicon_ico_path}")

    # Generate Full Logo resized
    img_logo = Image.open(master_logo_png).convert("RGBA")
    for s in [256, 512]:
        resized = img_logo.resize((s, s), Image.Resampling.LANCZOS)
        out_path = os.path.join(PNG_DIR, f"lipi_logo_{s}x{s}.png")
        resized.save(out_path, "PNG")
        print(f"  ✔ Saved {out_path}")

    # Generate 1200x630 OpenGraph card
    print("🎨 Generating 1200x630 OpenGraph Social Card...")
    og_img = Image.new("RGBA", (1200, 630), (13, 17, 23, 255)) # Dark slate GitHub style
    draw = ImageDraw.Draw(og_img)

    # Place Logo at left: 420x420
    logo_420 = img_logo.resize((420, 420), Image.Resampling.LANCZOS)
    og_img.paste(logo_420, (80, 105))

    # Add text on the right side
    # Simple default font
    try:
        font_title = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 64)
        font_sub = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 26)
        font_bullets = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
    except Exception:
        font_title = ImageFont.load_default()
        font_sub = ImageFont.load_default()
        font_bullets = ImageFont.load_default()

    draw.text((540, 140), "Lipi Language 2.0", fill=(240, 246, 252, 255), font=font_title)
    draw.text((540, 225), "Sovereign Digital Infrastructure & Direct Silicon Compiler", fill=(139, 148, 158, 255), font=font_sub)

    bullets = [
        "👑 100% Sovereign: 0% C | 0% GCC | 0% Libc | 0% Python",
        "⚡ Tri-Syntax: Bangla (লিপি), English (fn), Modern (def)",
        "🚀 io_uring Zero-Syscall Ring Buffers & Epoll Concurrency",
        "🧠 AVX-512 4x4 Tiled GEMM & Native GGUF v3 AI Engine",
        "🌐 Multi-Node Distributed Raft Consensus Cluster"
    ]
    y_pos = 285
    for b in bullets:
        draw.text((540, y_pos), b, fill=(0, 194, 255, 255), font=font_bullets)
        y_pos += 44

    og_path = os.path.join(PNG_DIR, "og_image.png")
    og_img.save(og_path, "PNG")
    print(f"  ✔ Saved {og_path} (1200x630)")

if __name__ == "__main__":
    generate_all_assets()
    print("🎉 All branding assets generated successfully!")
