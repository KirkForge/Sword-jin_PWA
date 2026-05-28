#!/usr/bin/env python3
"""Swordjin Sprite Sheet Generator v2 — Animated pixel art sprites.

Generates sprite sheets for all characters with idle, walk, and attack frames.
Each sprite sheet is a horizontal strip: frame0, frame1, frame2, ...
Frame size: 16x16 pixels, scaled 2x = 32x32 display.
"""
import os
from PIL import Image, ImageDraw

OUT = "/home/kirk/Madlab/Clean-Live/Sword-jin_PWA/assets/art"
SCALE = 2
SPRITE_SIZE = 16  # logical pixels per frame

def px(draw, x, y, color, s=SCALE):
    draw.rectangle([x*s, y*s, (x+1)*s-1, (y+1)*s-1], fill=color)

def draw_sprite(draw, ox, oy, pixels, palette, s=SCALE):
    """Draw a single sprite at offset (ox, oy) in logical pixels."""
    for y, row in enumerate(pixels):
        for x, ch in enumerate(row):
            color = palette.get(ch, (0,0,0,0))
            if color[3] > 0:
                px(draw, ox+x, oy+y, color, s)

def make_sheet(name, frames, palette, subdir, frame_w=16, frame_h=16):
    """Create a horizontal sprite sheet from a list of frame definitions."""
    out_dir = f"{OUT}/{subdir}"
    os.makedirs(out_dir, exist_ok=True)
    out_path = f"{out_dir}/{name}.png"
    
    w = frame_w * SCALE * len(frames)
    h = frame_h * SCALE
    img = Image.new("RGBA", (w, h), (0,0,0,0))
    draw = ImageDraw.Draw(img)
    
    for i, frame_pixels in enumerate(frames):
        draw_sprite(draw, i * frame_w, 0, frame_pixels, palette)
    
    img.save(out_path)
    print(f"  {name}.png — {len(frames)} frames, {w}x{h}px")
    return out_path

# === PALETTES ===
PLAYER_PAL = {
    ' ': (0,0,0,0),
    'h': (100,60,30,255),    # hair dark brown
    'H': (140,80,40,255),    # hair light
    's': (220,180,140,255),  # skin
    'S': (190,150,110,255),  # skin shadow
    'b': (50,80,160,255),    # blue tunic
    'B': (30,55,120,255),    # blue tunic shadow
    'd': (60,45,30,255),     # dark brown (boots/belt)
    'l': (180,160,120,255),  # leather
    'w': (200,200,210,255),  # sword blade
    'W': (240,240,250,255),  # sword blade highlight
    'r': (160,40,40,255),    # red accent
    'c': (80,80,80,255),     # dark gray
}

SKELETON_PAL = {
    ' ': (0,0,0,0),
    'b': (220,230,240,255),  # bone white
    'B': (180,190,200,255),  # bone shadow
    'e': (0,220,0,255),      # eye glow green
    'E': (0,160,0,255),      # eye dim
    'd': (50,50,60,255),     # dark joint
    'r': (100,30,30,255),    # rust on captain
    's': (30,35,45,255),     # shield dark
    'S': (60,70,80,255),     # shield light
    'g': (180,160,40,255),   # gold trim
}

CAPTAIN_PAL = {
    ' ': (0,0,0,0),
    'b': (220,230,240,255),
    'B': (180,190,200,255),
    'e': (220,0,0,255),      # red eyes
    'E': (160,0,0,255),
    'd': (50,50,60,255),
    'r': (100,30,30,255),
    's': (80,80,100,255),    # shield
    'S': (120,120,140,255),
    'g': (180,160,40,255),   # gold
}

ARCHER_PAL = {
    ' ': (0,0,0,0),
    'b': (200,210,220,255),
    'B': (160,170,180,255),
    'e': (0,180,0,255),
    'E': (0,120,0,255),
    'd': (50,50,60,255),
    'a': (120,70,30,255),    # bow wood
    'A': (160,100,40,255),   # bow highlight
    'f': (60,100,40,255),    # fletching
}

MERCHANT_PAL = {
    ' ': (0,0,0,0),
    's': (220,180,140,255),  # skin
    'S': (190,150,110,255),
    'p': (140,40,140,255),   # purple robe
    'P': (100,20,100,255),
    'h': (100,60,30,255),   # hat
    'H': (130,80,40,255),
    'g': (180,160,40,255),   # gold
    'd': (60,45,30,255),
}

GHOST_PAL = {
    ' ': (0,0,0,0),
    'g': (180,200,255,180),  # ghost blue-white (semi-transparent)
    'G': (140,160,220,200),  # ghost shadow
    'e': (100,180,255,255),  # eye glow
    'E': (60,120,220,255),   # eye dim
    'w': (220,230,255,220),  # white wisps
    'a': (160,180,255,160),  # aura fade
    'A': (120,140,200,120),  # aura outer
}

BANDIT_PAL = {
    ' ': (0,0,0,0),
    's': (220,180,140,255),  # skin
    'S': (190,150,110,255),  # skin shadow
    'b': (100,70,30,255),    # brown cloak
    'B': (70,50,20,255),     # brown dark
    'h': (60,45,30,255),     # hood
    'H': (40,30,20,255),     # hood shadow
    'd': (80,60,40,255),     # dagger
    'D': (200,200,210,255),  # dagger blade
    'l': (160,130,80,255),   # leather belt
}

ASSASSIN_PAL = {
    ' ': (0,0,0,0),
    'c': (30,30,40,255),     # dark cloak
    'C': (50,50,60,255),     # cloak highlight
    'r': (220,30,30,255),    # red eyes
    'R': (180,20,20,255),    # red eyes dim
    'd': (60,60,70,255),     # dark detail
    'D': (200,200,210,255),  # dagger blade
    's': (200,170,130,255),  # skin (minimal)
    'a': (20,20,25,240),     # aura
}

GOLEM_PAL = {
    ' ': (0,0,0,0),
    'r': (140,130,120,255),  # rock gray
    'R': (100,95,90,255),    # rock shadow
    'm': (80,180,80,255),    # magic green glow
    'M': (40,120,40,255),    # magic dim
    'd': (80,75,70,255),     # dark crack
    'D': (60,55,50,255),     # deep crack
    'c': (160,150,140,255),  # crystal
    'C': (200,190,180,255),  # crystal highlight
}

# === SPRITE FRAMES ===
# Each frame is a 16x16 character grid

# --- PLAYER ---
PLAYER_IDLE_0 = [
    "     hhhhhh     ", "    hHHHHHh    ", "    ssssss     ", "    sSsSss     ",
    "     ssss      ", "     bbb       ", "    bBbbBb     ", "    bbbbbB     ",
    "     bbbb      ", "     bbbb      ", "      dd       ", "     d  d      ",
    "     d  d      ", "    dd  dd     ", "                ", "                ",
]

PLAYER_IDLE_1 = [
    "     hhhhhh     ", "    hHHHHHh    ", "    ssssss     ", "    sSsSss     ",
    "     ssss      ", "     bbb       ", "    bBbbBb     ", "    bbbbbB     ",
    "     bbbb      ", "     bbbb      ", "      dd       ", "     d  d      ",
    "     d  d      ", "    dd  dd     ", "                ", "                ",
]

PLAYER_IDLE_2 = [
    "     hhhhhh     ", "    hHHHHHh    ", "    ssssss     ", "    sSsSss     ",
    "     ssss      ", "     bbb       ", "    bBbbBb     ", "    bbbbbB     ",
    "     bbbb      ", "     bbbb      ", "      dd       ", "     d  d      ",
    "     d  d      ", "    dd  dd     ", "                ", "                ",
]

PLAYER_WALK_0 = [
    "     hhhhhh     ", "    hHHHHHh    ", "    ssssss     ", "    sSsSss     ",
    "     ssss      ", "     bbb       ", "    bBbbBb     ", "    bbbbbB     ",
    "     bbbb      ", "     bbbb      ", "     d         ", "     d d       ",
    "      dd       ", "     dd        ", "                ", "                ",
]

PLAYER_WALK_1 = [
    "     hhhhhh     ", "    hHHHHHh    ", "    ssssss     ", "    sSsSss     ",
    "     ssss      ", "     bbb       ", "    bBbbBb     ", "    bbbbbB     ",
    "     bbbb      ", "     bbbb      ", "      dd       ", "     d  d      ",
    "     d  d      ", "    dd  dd     ", "                ", "                ",
]

PLAYER_WALK_2 = [
    "     hhhhhh     ", "    hHHHHHh    ", "    ssssss     ", "    sSsSss     ",
    "     ssss      ", "     bbb       ", "    bBbbBb     ", "    bbbbbB     ",
    "     bbbb      ", "     bbbb      ", "        d      ", "       d d     ",
    "        dd     ", "        dd     ", "                ", "                ",
]

PLAYER_ATTACK_0 = [
    "     hhhhhh     ", "    hHHHHHh    ", "    ssssss     ", "    sSsSss     ",
    "     ssss      ", "     bbb       ", "    bBbbBb     ", "    bbbbbB     ",
    "     bbbb      ", "     bbbb      ", "      dd       ", "     d  d      ",
    "     d  d      ", "    dd  dd     ", "                ", "                ",
]

PLAYER_ATTACK_1 = [
    "     hhhhhh     ", "    hHHHHHh    ", "    ssssss     ", "    sSsSss     ",
    "     ssss  w   ", "     bbb  wW   ", "    bBbbBwwW   ", "    bbbbbBww    ",
    "     bbbb      ", "     bbbb      ", "      dd       ", "     d  d      ",
    "     d  d      ", "    dd  dd     ", "                ", "                ",
]

PLAYER_ATTACK_2 = [
    "     hhhhhh     ", "    hHHHHHh    ", "    ssssss     ", "    sSssSss    ",
    "     ssss wW   ", "     bbb wwW   ", "    bBbbBwwW   ", "    bbbbbB w    ",
    "     bbbb      ", "     bbbb      ", "      dd       ", "     d  d      ",
    "     d  d      ", "    dd  dd     ", "                ", "                ",
]

PLAYER_ATTACK_3 = [
    "     hhhhhh     ", "    hHHHHHh    ", "    ssssss     ", "    sSsSss     ",
    "     ssss      ", "     bbb       ", "    bBbbBb     ", "    bbbbbB     ",
    "     bbbb      ", "     bbbb      ", "      dd       ", "     d  d      ",
    "     d  d      ", "    dd  dd     ", "                ", "                ",
]

# --- SKELETON ---
SKELETON_IDLE_0 = [
    "       bb       ", "      bbbb      ", "     bb  bb     ", "     b eeeb     ",
    "     b BBBb     ", "      bbbb      ", "      bbbb      ", "     bb  bb     ",
    "    bb    bb    ", "    B      B    ", "                ", "                ",
    "                ", "                ", "                ", "                ",
]

SKELETON_IDLE_1 = [
    "       bb       ", "      bbbb      ", "     bb  bb     ", "     b eeeb     ",
    "     b BBBb     ", "      bbbb      ", "      bbbb      ", "     bb  bb     ",
    "    bb    bb    ", "    B      B    ", "                ", "                ",
    "                ", "                ", "                ", "                ",
]

SKELETON_WALK_0 = [
    "       bb       ", "      bbbb      ", "     bb  bb     ", "     b eeeb     ",
    "     b BBBb     ", "      bbbb      ", "      bbbb      ", "     bb  bb     ",
    "    b      B    ", "   bB           ", "                ", "                ",
    "                ", "                ", "                ", "                ",
]

SKELETON_WALK_1 = [
    "       bb       ", "      bbbb      ", "     bb  bb     ", "     b eeeb     ",
    "     b BBBb     ", "      bbbb      ", "      bbbb      ", "     bb  bb     ",
    "    B      b    ", "          Bb    ", "                ", "                ",
    "                ", "                ", "                ", "                ",
]

SKELETON_ATTACK_0 = [
    "       bb       ", "      bbbb      ", "     bb  bb     ", "     b eeeb     ",
    "     b BBBb     ", "      bbbb      ", "      bbbb      ", "     bb  bb     ",
    "    bb    bb    ", "    B      B    ", "                ", "                ",
    "                ", "                ", "                ", "                ",
]

SKELETON_ATTACK_1 = [
    "       bb       ", "      bbbb      ", "     bb  bb     ", "     b eeeb     ",
    "     b BBBb  d  ", "      bbbbB d   ", "      bbbb  d   ", "     bb  bb d   ",
    "    bb    bb    ", "    B      B    ", "                ", "                ",
    "                ", "                ", "                ", "                ",
]

# --- SKELETON CAPTAIN ---
CAPTAIN_IDLE_0 = [
    "       bb       ", "      bbbb      ", "     bb  bb     ", "     b eeeb     ",
    "     b BBBb     ", "      bbbb      ", "      bbbb      ", "     ss  ss     ",
    "    sss  sss    ", "    d      d    ", "                ", "                ",
    "                ", "                ", "                ", "                ",
]

CAPTAIN_IDLE_1 = [
    "       bb       ", "      bbbb      ", "     bb  bb     ", "     b eeeb     ",
    "     b BBBb     ", "      bbbb      ", "      bbbb      ", "     ss  ss     ",
    "    sss  sss    ", "    d      d    ", "                ", "                ",
    "                ", "                ", "                ", "                ",
]

CAPTAIN_WALK_0 = [
    "       bb       ", "      bbbb      ", "     bb  bb     ", "     b eeeb     ",
    "     b BBBb     ", "      bbbb      ", "      bbbb      ", "     ss  ss     ",
    "    s      sss  ", "   dS      d    ", "                ", "                ",
    "                ", "                ", "                ", "                ",
]

CAPTAIN_WALK_1 = [
    "       bb       ", "      bbbb      ", "     bb  bb     ", "     b eeeb     ",
    "     b BBBb     ", "      bbbb      ", "      bbbb      ", "     ss  ss     ",
    "   sss      s   ", "    d      Sd   ", "                ", "                ",
    "                ", "                ", "                ", "                ",
]

CAPTAIN_ATTACK_0 = [
    "       bb       ", "      bbbb      ", "     bb  bb     ", "     b eeeb     ",
    "     b BBBb     ", "      bbbb      ", "      bbbb      ", "     ss  ss     ",
    "    sss  sss    ", "    d      d    ", "                ", "                ",
    "                ", "                ", "                ", "                ",
]

CAPTAIN_ATTACK_1 = [
    "       bb       ", "      bbbb      ", "     bb  bb     ", "     b eeeb     ",
    "     b BBBb  s  ", "      bbbbS sS  ", "      bbbb  sS  ", "     ss  ss sS  ",
    "    sss  sss    ", "    d      d    ", "                ", "                ",
    "                ", "                ", "                ", "                ",
]

# --- SKELETON ARCHER ---
ARCHER_IDLE_0 = [
    "       bb       ", "      bbbb      ", "     bb  bb     ", "     b eeeb     ",
    "     b BBBb     ", "      bbbb      ", "      bbbb      ", "     bb  bb     ",
    "    b      b    ", "    B      B    ", "                ", "                ",
    "                ", "                ", "                ", "                ",
]

ARCHER_IDLE_1 = [
    "       bb       ", "      bbbb      ", "     bb  bb     ", "     b eeeb     ",
    "     b BBBb     ", "      bbbb      ", "      bbbb      ", "     bb  bb     ",
    "    b      b    ", "    B      B    ", "                ", "                ",
    "                ", "                ", "                ", "                ",
]

ARCHER_WALK_0 = [
    "       bb       ", "      bbbb      ", "     bb  bb     ", "     b eeeb     ",
    "     b BBBb     ", "      bbbb      ", "      bbbb      ", "     bb  bb     ",
    "    b       B   ", "   bB          ", "                ", "                ",
    "                ", "                ", "                ", "                ",
]

ARCHER_WALK_1 = [
    "       bb       ", "      bbbb      ", "     bb  bb     ", "     b eeeb     ",
    "     b BBBb     ", "      bbbb      ", "      bbbb      ", "     bb  bb     ",
    "    B       b   ", "          Bb    ", "                ", "                ",
    "                ", "                ", "                ", "                ",
]

# --- MERCHANT ---
MERCHANT_IDLE_0 = [
    "     hhhhhh     ", "    hHHHHHh    ", "    ssssss     ", "    sSsSss     ",
    "     ssss      ", "     ppp       ", "    pPppPp     ", "    pppppP     ",
    "     pppp      ", "     pppp      ", "      dd       ", "     d  d      ",
    "     d  d      ", "    dd  dd     ", "                ", "                ",
]

MERCHANT_IDLE_1 = [
    "     hhhhhh     ", "    hHHHHHh    ", "    ssssss     ", "    sSsSss     ",
    "     ssss      ", "     ppp       ", "    pPppPp     ", "    pppppP     ",
    "     pppp      ", "     pppp      ", "      dd       ", "     d  d      ",
    "     d  d      ", "    dd  dd     ", "                ", "                ",
]

# --- GHOST ---
GHOST_IDLE_0 = [
    "                ", "      aaaa      ", "     aGGGGa     ", "    aGgGGgGa    ",
    "    Gg eegG     ", "    Gg EGGgG    ", "     GgggG      ", "      gggg      ",
    "     g  gg      ", "    g    gg     ", "   a      ga    ", "  A        A    ",
    "                ", "                ", "                ", "                ",
]

GHOST_IDLE_1 = [
    "                ", "      aaaa      ", "     aGGGGa     ", "    aGgGGgGa    ",
    "    Gg eegG     ", "    Gg EGGgG    ", "     GgggG      ", "      gggg      ",
    "     gg  g      ", "    gg    g     ", "   ag      a    ", "  A          A  ",
    "                ", "                ", "                ", "                ",
]

GHOST_ATTACK_0 = [
    "                ", "      aaaa      ", "     aGGGGa     ", "    aGgGGgGa    ",
    "    Gg eegG     ", "    Gg EGGgG    ", "     GgggG      ", "      gggg      ",
    "     g  gg      ", "    g    gg     ", "   a      ga    ", "  A        A    ",
    "                ", "                ", "                ", "                ",
]

GHOST_ATTACK_1 = [
    "                ", "      aaaa      ", "     aGGGGa     ", "    aGgGGgGa    ",
    "    Gg eegG     ", "    Gg EGGgG    ", "     GgggG      ", "      gggg      ",
    "   wwwwgggg     ", "  wwWWww  gg    ", "   wwww    g    ", "  A          A  ",
    "                ", "                ", "                ", "                ",
]

GHOST_DIE_0 = [
    "                ", "       aa       ", "      aGGa      ", "     aGgGa      ",
    "     Gg ggG     ", "     G EGGgG    ", "      GggG      ", "       gg       ",
    "      g  g      ", "     g    g     ", "    a      a    ", "   A        A   ",
    "                ", "                ", "                ", "                ",
]

# --- BANDIT ---
BANDIT_IDLE_0 = [
    "      hhhhh     ", "     hHHHHHh    ", "     sssss     ", "     sSsSss     ",
    "      sss      ", "      bbb       ", "     bBbbBb     ", "     bbbbbB     ",
    "      bbbb      ", "      bbbb      ", "       dd       ", "      d  d      ",
    "      d  d      ", "     dd  dd     ", "                ", "                ",
]

BANDIT_IDLE_1 = [
    "      hhhhh     ", "     hHHHHHh    ", "     sssss     ", "     sSsSss     ",
    "      sss      ", "      bbb       ", "     bBbbBb     ", "     bbbbbB     ",
    "      bbbb      ", "      bbbb      ", "       dd       ", "      d  d      ",
    "      d  d      ", "     dd  dd     ", "                ", "                ",
]

BANDIT_WALK_0 = [
    "      hhhhh     ", "     hHHHHHh    ", "     sssss     ", "     sSsSss     ",
    "      sss      ", "      bbb       ", "     bBbbBb     ", "     bbbbbB     ",
    "      bbbb      ", "      bbbb      ", "      d         ", "      d d       ",
    "       dd       ", "      dd        ", "                ", "                ",
]

BANDIT_WALK_1 = [
    "      hhhhh     ", "     hHHHHHh    ", "     sssss     ", "     sSsSss     ",
    "      sss      ", "      bbb       ", "     bBbbBb     ", "     bbbbbB     ",
    "      bbbb      ", "      bbbb      ", "       dd       ", "      d  d      ",
    "      d  d      ", "     dd  dd     ", "                ", "                ",
]

BANDIT_ATTACK_0 = [
    "      hhhhh     ", "     hHHHHHh    ", "     sssss     ", "     sSsSss     ",
    "      sss      ", "      bbb       ", "     bBbbBb     ", "     bbbbbB     ",
    "      bbbb      ", "      bbbb      ", "       dd       ", "      d  d      ",
    "      d  d      ", "     dd  dd     ", "                ", "                ",
]

BANDIT_ATTACK_1 = [
    "      hhhhh     ", "     hHHHHHh    ", "     sssss     ", "     sSsSss   D ",
    "      sss    Dd ", "      bbb     Dd ", "     bBbbBb     ", "     bbbbbB     ",
    "      bbbb      ", "      bbbb      ", "       dd       ", "      d  d      ",
    "      d  d      ", "     dd  dd     ", "                ", "                ",
]

# --- ASSASSIN ---
ASSASSIN_IDLE_0 = [
    "      ccc      ", "     cCCCCc    ", "     c  cc     ", "     c rrc     ",
    "     c CCc     ", "      ccc      ", "      ccc      ", "     cc  cc    ",
    "    cc    cc   ", "    c      c   ", "                ", "                ",
    "                ", "                ", "                ", "                ",
]

ASSASSIN_IDLE_1 = [
    "      ccc      ", "     cCCCCc    ", "     c  cc     ", "     c rrc     ",
    "     c CCc     ", "      ccc      ", "      ccc      ", "     cc  cc    ",
    "    cc    cc   ", "    c      c   ", "                ", "                ",
    "                ", "                ", "                ", "                ",
]

ASSASSIN_DASH_0 = [
    "               c", "      ccc    c ", "     cCCCC  c  ", "     c  cc c   ",
    "     c rrc     ", "      ccc      ", "      ccc      ", "     cc  cc    ",
    "    cc    cc   ", "    c      c   ", "                ", "                ",
    "                ", "                ", "                ", "                ",
]

ASSASSIN_ATTACK_0 = [
    "      ccc      ", "     cCCCCc    ", "     c  cc     ", "     c rrc     ",
    "     c CCc     ", "      ccc      ", "      ccc      ", "     cc  cc    ",
    "    cc    cc   ", "    c      c   ", "                ", "                ",
    "                ", "                ", "                ", "                ",
]

ASSASSIN_ATTACK_1 = [
    "      ccc      ", "     cCCCCc    ", "     c  cc     ", "     c rrc    D",
    "     c CCc    Dd", "      ccc     D", "      ccc      ", "     cc  cc    ",
    "    cc    cc   ", "    c      c   ", "                ", "                ",
    "                ", "                ", "                ", "                ",
]

# --- GOLEM (24x32 frame, large enemy) ---
GOLEM_IDLE_0 = [
    "         rrr         ", "        rRRRr        ", "        rMrr         ", "       rRMRrr       ",
    "       rrrrrr       ", "      rrrrrrr       ", "      rRrRRRr       ", "     rRr rRrr      ",
    "     rR  rRRr      ", "     rRr rRRr      ", "     rRRRRRRr      ", "      rrrrrr       ",
    "      rrrrrr       ", "     rrrrrrrr      ", "     rrr  rrr      ", "     rrr  rrr      ",
    "      rr  rr       ", "       r  r        ", "      rr  rr       ", "     rRr rRr       ",
    "     rRr rRr       ", "      rr  rr       ", "       r  r        ", "                ",
    "                ", "                ", "                ", "                ", "                ",
    "                ", "                ",
]

GOLEM_IDLE_1 = [
    "         rrr         ", "        rRRRr        ", "        rMrr         ", "       rRMRrr       ",
    "       rrrrrr       ", "      rrrrrrr       ", "      rRrRRRr       ", "     rRr rRrr      ",
    "     rR  rRRr      ", "     rRr rRRr      ", "     rRRRRRRr      ", "      rrrrrr       ",
    "      rrrrrr       ", "     rrrrrrrr      ", "     rrr  rrr      ", "     rrr  rrr      ",
    "      rr  rr       ", "       r  r        ", "      rr  rr       ", "     rRr rRr       ",
    "     rRr rRr       ", "      rr  rr       ", "       r  r        ", "                ",
    "                ", "                ", "                ", "                ", "                ",
    "                ", "                ",
]

GOLEM_ATTACK_0 = [
    "         rrr         ", "        rRRRr        ", "        rMrr         ", "       rRMRrr       ",
    "       rrrrrr       ", "      rrrrrrr       ", "      rRrRRRr       ", "     rRr rRrr      ",
    "     rR  rRRr      ", "     rRr rRRr      ", "     rRRRRRRr      ", "      rrrrrr       ",
    "      rrrrrr       ", "     rrrrrrrr      ", "     rrr  rrr      ", "     rrr  rrr      ",
    "      rr  rr       ", "       r  r        ", "      rr  rr       ", "     rRr rRr       ",
    "     rRr rRr       ", "      rr  rr       ", "       r  r        ", "                ",
    "                ", "                ", "                ", "                ", "                ",
    "                ", "                ",
]

GOLEM_ATTACK_1 = [
    "         rrr         ", "        rRRRr        ", "        rMrr         ", "       rRMRrr       ",
    "       rrrrrr       ", "      rrrrrrr       ", "      rRrRRRr       ", "     rRr rRrr   rrr ",
    "     rR  rRRr  rRRr ", "     rRr rRRr  rRRr ", "     rRRRRRRr   rrr ", "      rrrrrr        ",
    "      rrrrrr       ", "     rrrrrrrr      ", "     rrr  rrr      ", "     rrr  rrr      ",
    "      rr  rr       ", "       r  r        ", "      rr  rr       ", "     rRr rRr       ",
    "     rRr rRr       ", "      rr  rr       ", "       r  r        ", "                ",
    "                ", "                ", "                ", "                ", "                ",
    "                ", "                ",
]

if __name__ == "__main__":
    print("=== Swordjin Sprite Sheet Generator v2 ===\n")
    
    print("[Player]")
    make_sheet("player_idle", [PLAYER_IDLE_0, PLAYER_IDLE_1, PLAYER_IDLE_2], PLAYER_PAL, "characters")
    make_sheet("player_walk", [PLAYER_WALK_0, PLAYER_WALK_1, PLAYER_WALK_2], PLAYER_PAL, "characters")
    make_sheet("player_attack", [PLAYER_ATTACK_0, PLAYER_ATTACK_1, PLAYER_ATTACK_2, PLAYER_ATTACK_3], PLAYER_PAL, "characters")
    
    print("\n[Skeleton]")
    make_sheet("skeleton_idle", [SKELETON_IDLE_0, SKELETON_IDLE_1], SKELETON_PAL, "enemies")
    make_sheet("skeleton_walk", [SKELETON_WALK_0, SKELETON_WALK_1], SKELETON_PAL, "enemies")
    make_sheet("skeleton_attack", [SKELETON_ATTACK_0, SKELETON_ATTACK_1], SKELETON_PAL, "enemies")
    
    print("\n[Skeleton Captain]")
    make_sheet("captain_idle", [CAPTAIN_IDLE_0, CAPTAIN_IDLE_1], CAPTAIN_PAL, "enemies")
    make_sheet("captain_walk", [CAPTAIN_WALK_0, CAPTAIN_WALK_1], CAPTAIN_PAL, "enemies")
    make_sheet("captain_attack", [CAPTAIN_ATTACK_0, CAPTAIN_ATTACK_1], CAPTAIN_PAL, "enemies")
    
    print("\n[Skeleton Archer]")
    make_sheet("archer_idle", [ARCHER_IDLE_0, ARCHER_IDLE_1], ARCHER_PAL, "enemies")
    make_sheet("archer_walk", [ARCHER_WALK_0, ARCHER_WALK_1], ARCHER_PAL, "enemies")
    
    print("\n[Merchant]")
    make_sheet("merchant_idle", [MERCHANT_IDLE_0, MERCHANT_IDLE_1], MERCHANT_PAL, "npcs")
    
    print("\n[Ghost]")
    make_sheet("ghost_idle", [GHOST_IDLE_0, GHOST_IDLE_1], GHOST_PAL, "enemies")
    make_sheet("ghost_attack", [GHOST_ATTACK_0, GHOST_ATTACK_1], GHOST_PAL, "enemies")
    make_sheet("ghost_die", [GHOST_DIE_0], GHOST_PAL, "enemies")
    
    print("\n[Bandit]")
    make_sheet("bandit_idle", [BANDIT_IDLE_0, BANDIT_IDLE_1], BANDIT_PAL, "enemies")
    make_sheet("bandit_walk", [BANDIT_WALK_0, BANDIT_WALK_1], BANDIT_PAL, "enemies")
    make_sheet("bandit_attack", [BANDIT_ATTACK_0, BANDIT_ATTACK_1], BANDIT_PAL, "enemies")
    
    print("\n[Assassin]")
    make_sheet("assassin_idle", [ASSASSIN_IDLE_0, ASSASSIN_IDLE_1], ASSASSIN_PAL, "enemies")
    make_sheet("assassin_dash", [ASSASSIN_DASH_0], ASSASSIN_PAL, "enemies")
    make_sheet("assassin_attack", [ASSASSIN_ATTACK_0, ASSASSIN_ATTACK_1], ASSASSIN_PAL, "enemies")
    
    print("\n[Golem]")
    make_sheet("golem_idle", [GOLEM_IDLE_0, GOLEM_IDLE_1], GOLEM_PAL, "enemies", frame_w=24, frame_h=24)
    make_sheet("golem_attack", [GOLEM_ATTACK_0, GOLEM_ATTACK_1], GOLEM_PAL, "enemies", frame_w=24, frame_h=24)
    
    print("\n=== Done! ===")