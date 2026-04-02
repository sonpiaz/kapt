#!/usr/bin/env python3
"""
Generate Kapt app icon: rounded square with blue/purple gradient and white camera viewfinder symbol.
Outputs a 1024x1024 PNG for use with sips to create .icns.
"""

import math
from PIL import Image, ImageDraw

SIZE = 1024
CORNER_RADIUS = int(SIZE * 0.22)  # ~225px — macOS standard ~22% of width

# ── Helpers ──────────────────────────────────────────────────────────────────

def make_rounded_square_mask(size, radius):
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return mask


def lerp_color(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))


def make_gradient(size, top_left, top_right, bottom_left, bottom_right):
    """Bilinear gradient between four corner colors."""
    img = Image.new("RGB", (size, size))
    pixels = img.load()
    for y in range(size):
        ty = y / (size - 1)
        for x in range(size):
            tx = x / (size - 1)
            top = lerp_color(top_left, top_right, tx)
            bottom = lerp_color(bottom_left, bottom_right, tx)
            pixels[x, y] = lerp_color(top, bottom, ty)
    return img


# ── Gradient background ───────────────────────────────────────────────────────
# Deep blue (top-left) → purple/violet (top-right)
# Blue (bottom-left) → deep indigo (bottom-right)

TL = (34,  88, 210)   # vivid blue
TR = (120, 60, 220)   # purple
BL = (20,  60, 170)   # deep blue
BR = (80,  30, 180)   # deep indigo

bg = make_gradient(SIZE, TL, TR, BL, BR)

# ── Round the square ─────────────────────────────────────────────────────────
mask = make_rounded_square_mask(SIZE, CORNER_RADIUS)
icon = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
icon.paste(bg, (0, 0))
icon.putalpha(mask)

# ── Draw viewfinder symbol ────────────────────────────────────────────────────
# Classic camera-viewfinder: a square frame with L-shaped corner brackets
# plus a small crosshair / center circle.

draw = ImageDraw.Draw(icon)

WHITE = (255, 255, 255, 240)
CENTER = SIZE // 2

# Outer square (frame), inset 27% from edges
INSET = int(SIZE * 0.27)
FRAME = SIZE - 2 * INSET          # ~468px square
X0, Y0 = INSET, INSET
X1, Y1 = SIZE - INSET, SIZE - INSET

# Corner bracket arm length = 20% of frame size
ARM = int(FRAME * 0.20)
# Line width scales with icon size
LW = max(4, int(SIZE * 0.022))    # ~22px at 1024

def draw_bracket(draw, cx, cy, dx, dy, arm, lw, color):
    """Draw an L-bracket at corner (cx,cy). dx/dy are +1/-1 inward directions."""
    # Horizontal arm
    draw.line([(cx, cy), (cx + dx * arm, cy)], fill=color, width=lw)
    # Vertical arm
    draw.line([(cx, cy), (cx, cy + dy * arm)], fill=color, width=lw)

# Top-left
draw_bracket(draw, X0, Y0, +1, +1, ARM, LW, WHITE)
# Top-right
draw_bracket(draw, X1, Y0, -1, +1, ARM, LW, WHITE)
# Bottom-left
draw_bracket(draw, X0, Y1, +1, -1, ARM, LW, WHITE)
# Bottom-right
draw_bracket(draw, X1, Y1, -1, -1, ARM, LW, WHITE)

# Center crosshair: small cross
CROSS = int(FRAME * 0.10)   # arm length of crosshair
CLW   = max(3, int(SIZE * 0.016))
draw.line([(CENTER - CROSS, CENTER), (CENTER + CROSS, CENTER)], fill=WHITE, width=CLW)
draw.line([(CENTER, CENTER - CROSS), (CENTER, CENTER + CROSS)], fill=WHITE, width=CLW)

# Center dot circle (filled)
R_DOT = int(SIZE * 0.032)
draw.ellipse(
    [CENTER - R_DOT, CENTER - R_DOT, CENTER + R_DOT, CENTER + R_DOT],
    fill=WHITE
)

# Outer glow: very subtle inner shadow/rim on the rounded rect to add depth
# (draw slightly transparent white ring just inside the mask edge)
GLOW_INSET = int(SIZE * 0.018)
GLOW_ALPHA = 40
glow_color = (255, 255, 255, GLOW_ALPHA)
glow_lw = max(2, int(SIZE * 0.014))
draw.rounded_rectangle(
    [GLOW_INSET, GLOW_INSET, SIZE - GLOW_INSET, SIZE - GLOW_INSET],
    radius=CORNER_RADIUS - GLOW_INSET,
    outline=glow_color,
    width=glow_lw
)

# ── Save ─────────────────────────────────────────────────────────────────────
import os, sys

out_dir = os.path.join(os.path.dirname(__file__), "..", "Resources")
os.makedirs(out_dir, exist_ok=True)
out_path = os.path.join(out_dir, "AppIcon_1024.png")
icon.save(out_path, "PNG")
print(f"Saved: {os.path.realpath(out_path)}")
