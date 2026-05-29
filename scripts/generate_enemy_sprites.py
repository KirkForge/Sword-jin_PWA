#!/usr/bin/env python3
"""Generate placeholder enemy sprites for bandit, assassin, golem, ghost.
Each enemy gets idle, walk, attack frames at 64x32 (matching existing sprites)."""

from PIL import Image, ImageDraw
import os

OUT = "assets/art/enemies"
os.makedirs(OUT, exist_ok=True)

def make_sprite(color_main, color_accent, shape="humanoid", size=(64, 32)):
    """Generate a placeholder enemy sprite."""
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    w, h = size
    
    if shape == "humanoid":
        # Head
        cx, cy = w // 2, h // 3
        head_r = 5
        d.ellipse([cx - head_r, cy - head_r, cx + head_r, cy + head_r], fill=color_accent)
        # Body
        d.rectangle([cx - 4, cy + head_r, cx + 4, h - 4], fill=color_main)
        # Arms
        d.line([cx - 8, cy + head_r + 2, cx - 2, cy + head_r + 6], fill=color_accent, width=2)
        d.line([cx + 8, cy + head_r + 2, cx + 2, cy + head_r + 6], fill=color_accent, width=2)
        # Legs
        d.line([cx - 3, h - 4, cx - 6, h], fill=color_main, width=2)
        d.line([cx + 3, h - 4, cx + 6, h], fill=color_main, width=2)
    
    elif shape == "large":
        # Golem — big blocky shape
        cx, cy = w // 2, h // 2
        d.rectangle([cx - 12, 2, cx + 12, h - 2], fill=color_main)
        d.rectangle([cx - 8, 4, cx + 8, 12], fill=color_accent)  # face area
        # Cracks
        d.line([cx - 4, 10, cx, 18], fill=(0, 0, 0, 180), width=1)
        d.line([cx + 2, 14, cx + 6, 22], fill=(0, 0, 0, 180), width=1)
        # Arms
        d.rectangle([cx - 18, 8, cx - 12, 20], fill=color_accent)
        d.rectangle([cx + 12, 8, cx + 18, 20], fill=color_accent)
    
    elif shape == "spectral":
        # Ghost — translucent wavy shape
        cx, cy = w // 2, h // 3
        # Body — wavy bottom
        points_top = [(cx - 10, cy - 2), (cx + 10, cy - 2)]
        body_bottom = []
        for i in range(5):
            x = cx - 10 + i * 5
            y = h - 2 + (3 if i % 2 == 0 else -2)
            body_bottom.append((x, y))
        all_points = [(cx - 10, cy - 2), (cx + 10, cy - 2)] + body_bottom + [(cx + 10, h - 2), (cx - 10, h - 2)]
        d.polygon(all_points, fill=(*color_main[:3], 140))
        # Eyes
        d.ellipse([cx - 6, cy, cx - 3, cy + 3], fill=color_accent)
        d.ellipse([cx + 3, cy, cx + 6, cy + 3], fill=color_accent)
    
    elif shape == "rogue":
        # Assassin/bandit — lean, hooded
        cx, cy = w // 2, h // 3
        # Hood
        d.polygon([(cx - 7, cy - 4), (cx, cy - 8), (cx + 7, cy - 4)], fill=color_accent)
        d.rectangle([cx - 6, cy - 4, cx + 6, cy + 2], fill=color_accent)
        # Body
        d.rectangle([cx - 3, cy + 2, cx + 3, h - 4], fill=color_main)
        # Blade
        d.line([cx + 8, cy + 2, cx + 16, cy - 4], fill=(200, 200, 200, 200), width=1)
        # Legs
        d.line([cx - 2, h - 4, cx - 5, h], fill=color_main, width=2)
        d.line([cx + 2, h - 4, cx + 5, h], fill=color_main, width=2)
    
    return img


# Bandit — brown/leather, rogue shape
BANDIT_MAIN = (139, 90, 43, 255)     # Brown leather
BANDIT_ACCENT = (180, 120, 60, 255)  # Lighter brown

# Assassin — dark purple, rogue shape
ASSASSIN_MAIN = (60, 20, 80, 255)    # Dark purple
ASSASSIN_ACCENT = (120, 40, 140, 255) # Purple hood

# Golem — stone gray, large shape
GOLEM_MAIN = (120, 110, 100, 255)    # Stone gray
GOLEM_ACCENT = (160, 150, 130, 255)  # Lighter stone

# Ghost — pale blue, spectral shape
GHOST_MAIN = (100, 150, 220, 180)   # Translucent blue
GHOST_ACCENT = (200, 220, 255, 255) # Bright eyes


enemies = [
    ("bandit", BANDIT_MAIN, BANDIT_ACCENT, "rogue"),
    ("assassin", ASSASSIN_MAIN, ASSASSIN_ACCENT, "rogue"),
    ("golem", GOLEM_MAIN, GOLEM_ACCENT, "large"),
    ("ghost", GHOST_MAIN, GHOST_ACCENT, "spectral"),
]

for name, main_c, accent_c, shape in enemies:
    idle = make_sprite(main_c, accent_c, shape)
    walk = make_sprite(main_c, accent_c, shape)
    attack = make_sprite(main_c, accent_c, shape)
    
    # Walk frame: shift legs slightly
    if shape in ("humanoid", "rogue"):
        walk_d = ImageDraw.Draw(walk)
        # Shift legs slightly
        cx = 32
        walk_d.line([cx - 3, 28, cx - 8, 32], fill=main_c, width=2)
        walk_d.line([cx + 3, 28, cx + 8, 32], fill=main_c, width=2)
    
    # Attack frame: extend weapon arm
    if shape == "rogue":
        atk_d = ImageDraw.Draw(attack)
        cx = 32
        atk_d.line([cx + 8, cy := 10, cx + 20, cy - 8], fill=(200, 200, 200, 200), width=2)
    elif shape == "large":
        atk_d = ImageDraw.Draw(attack)
        # Arm raised
        atk_d.rectangle([cx := 32 + 12, 2, cx + 6, 16], fill=accent_c)
    
    idle.save(os.path.join(OUT, f"{name}_idle.png"))
    walk.save(os.path.join(OUT, f"{name}_walk.png"))
    attack.save(os.path.join(OUT, f"{name}_attack.png"))
    print(f"Generated: {name}_idle.png, {name}_walk.png, {name}_attack.png")

print("Done! All 4 enemy placeholder sprites generated.")