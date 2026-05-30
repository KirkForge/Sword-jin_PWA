#!/usr/bin/env python3
"""Swordjin art generation via OpenRouter + Gemini 2.5 Flash Image."""

import base64, json, os, sys, time, requests

API_KEY = open(os.path.expanduser("~/.picoclaw/workspace/.openrouter")).read().strip()
MODEL = "google/gemini-2.5-flash-image"
OUT_DIR = "/home/kirk/Madlab/Clean-Live/Sword-jin_PWA/assets/art"
API_URL = "https://openrouter.ai/api/v1/chat/completions"

STYLE = (
    "Dark fantasy wuxia 2D game art, clean pixel-art inspired style, "
    "limited palette: gold #FFD700, steel blue #5080C8, dark bg #0D1117, "
    "bone white #DCE6F0, rust #8B2500, purple #8C2E8C. "
    "No text, no letters, no words."
)

# ── All 37 prompts ──────────────────────────────────────────────────────────

PROMPTS = []

# 1. Title splash
PROMPTS.append({
    "subdir": "title",
    "filename": "title_splash.png",
    "prompt": (
        f"{STYLE} A lone swordsman (Jin) in blue tunic standing on a cliff edge at sunset, "
        "facing a dark iron fortress in the distance. His sword is drawn and raised. "
        "Wind blows his dark brown hair and tunic. Below the cliff, an army of skeletal warriors "
        "with glowing green eyes marches toward the fortress. The sky is deep navy #0D1117 with "
        "a burning orange #FF8020 sunset on the horizon. Gold #FFD700 light glints off the blade. "
        "Epic, dramatic, vertical composition."
    ),
})

# 2. Chapter backgrounds
PROMPTS.append({
    "subdir": "bg",
    "filename": "field_sunset.png",
    "prompt": (
        f"{STYLE} Wide landscape background, no characters. Open grassy field at dusk. "
        "Rolling hills of dark green #2D5A1E grass stretching to the horizon. Sky is deep navy "
        "#0D1117 at top fading to burnt orange #FF8020 at the horizon line. A few distant dead "
        "trees silhouetted. Scattered rocks #505860. Faint moonlight. Parallax-ready: foreground "
        "grass is slightly darker and more detailed, midground has gentle hills, background fades "
        "to silhouette. Horizontal 16:9 composition."
    ),
})
PROMPTS.append({
    "subdir": "bg",
    "filename": "forest_night.png",
    "prompt": (
        f"{STYLE} Wide landscape background, no characters. Dense dark forest at night. "
        "Tall gnarled trees with dark canopies #1E3A0E blocking most of the sky. Faint green "
        "#00DC00 glow from between tree roots (mushroom light). Ground is dark earth #1E2E14 "
        "with exposed roots. Occasional ghostly white #DCE6F0 wisps floating between trees. "
        "Sky barely visible through canopy, dark navy #0A0E14. Foreground has close tree trunks, "
        "midground has path through trees, background is impenetrable darkness. Spooky, claustrophobic. "
        "Horizontal 16:9 composition."
    ),
})
PROMPTS.append({
    "subdir": "bg",
    "filename": "fortress_dawn.png",
    "prompt": (
        f"{STYLE} Wide landscape background, no characters. Ancient stone fortress at dawn. "
        "Massive grey stone walls #505860 with battlements. A steel blue #5080C8 dawn sky above "
        "with thin clouds. Torches with orange #FF8020 flames on the ramparts. Gate is slightly "
        "ajar with darkness inside. Foreground: stone path and scattered rubble. Midground: "
        "fortress gate and walls. Background: mountain silhouettes in morning mist. Imposing, "
        "fortified. Horizontal 16:9 composition."
    ),
})
PROMPTS.append({
    "subdir": "bg",
    "filename": "iron_throne.png",
    "prompt": (
        f"{STYLE} Wide landscape background, no characters. Dark iron throne room interior. "
        "Massive iron gate #404858 with rust #8B2500 highlights at the far end, faintly glowing "
        "red from behind. Walls are dark iron #303848 with torch sconces casting orange #FF8020 "
        "light pools. Floor is dark stone #283040 with a long red carpet #8B2500 leading to the "
        "gate. Ceiling is lost in shadow #0D1117. Foreground: stone pillars on each side. "
        "Dramatic, ominous, final boss atmosphere. Horizontal 16:9 composition."
    ),
})

# 3. Achievement badges
BADGES = [
    ("first_blood", "A single blood-red sword dripping"),
    ("body_count_50", "A skull pile, 3 skulls stacked"),
    ("body_count_200", "A mountain of skulls with a sword planted in it"),
    ("flawless_chapter", "A glowing blue shield with a gold star"),
    ("first_step", "A single boot stepping onto a stone path"),
    ("half_way", "A compass with the needle pointing forward"),
    ("act2_reacher", "An iron gate with a crack of red light"),
    ("armory_3", "Three crossed swords of different sizes"),
    ("armory_all", "Six weapons arranged in a fan (swords, daggers, bow)"),
    ("bestiary_half", "An open book with a skull bookmark"),
    ("bestiary_all", "A closed book with a glowing green eye on the cover"),
    ("speed_demon", "A lightning bolt with motion lines"),
    ("perfectionist", "Three gold stars in a triangle"),
    ("legendary_find", "A sword radiating gold beams"),
    ("combo_master", "Three overlapping slash arcs in red-orange-yellow"),
    ("first_crit", "An eye with a golden iris and crosshair pupil"),
    ("crit_50", "A bullseye target with an arrow in the center"),
    ("enraged_kill", "A red-veined fist crushing a skull"),
    ("summon_slayer", "A broken staff with purple shards scattering"),
    ("streak_3", "Three lit candles in a row"),
    ("streak_7", "Seven lit candles with the tallest in center"),
    ("daily_challenger", "A calendar page with a sword through it"),
    ("daily_veteran", "A medal with seven notches on the ribbon"),
    ("ghost_hunter", "A ghost silhouette with a blue targeting reticle"),
    ("speed_demon_5", "Five small lightning bolts in a circle"),
]

for badge_id, subject in BADGES:
    PROMPTS.append({
        "subdir": "badges",
        "filename": f"{badge_id}.png",
        "prompt": (
            f"{STYLE} Single centered achievement badge icon on dark #0D1117 background. "
            f"Circular frame with gold #FFD700 border and dark fill. Inside the circle: {subject}. "
            "Clean, readable at small size, icon-style, no background detail beyond the circle frame."
        ),
    })

# 4. Item art
ITEMS = [
    ("broken_sword", "A rusty broken sword, blade is cracked and chipped with rust #8B2500 spots, handle wrapped in dark leather #3C2D1E, lying at slight angle"),
    ("steel_dagger", "A clean short dagger, silver-white blade #C8C8D2, simple crossguard, dark wood handle #604020, point facing up"),
    ("captains_blade", "An ornate long sword, gleaming blade #E0E8F0, gold #FFD700 crossguard with scrollwork, worn leather grip #604020, ruby pommel, point facing up"),
    ("health_potion", "A glass bottle of glowing red #E04040 liquid, cork stopper, round-bottomed flask shape, faint red glow around it"),
    ("steel_sword", "A standard steel long sword, blade #D0D8E0, steel blue #5080C8 crossguard, leather-wrapped grip #3C2D1E"),
    ("gold_coin", "A single gold coin #FFD700 with a sword stamped on it, slight 3/4 rotation to show thickness, edge has reeded detail"),
]

for item_id, desc in ITEMS:
    PROMPTS.append({
        "subdir": "items",
        "filename": f"{item_id}.png",
        "prompt": (
            f"{STYLE} Single centered item on dark #0D1117 background. "
            f"Clean icon style, suitable for inventory display. No frame, no border. {desc}"
        ),
    })

# 5. Merchant portrait
PROMPTS.append({
    "subdir": "npcs",
    "filename": "merchant_portrait.png",
    "prompt": (
        f"{STYLE} Portrait of a traveling merchant, bust view, centered on dark #0D1117 background. "
        "Elderly man with weathered skin #DCB48C, wise squinting eyes. Wearing a deep purple #8C2E8C "
        "robe with gold #FFD700 trim. A wide-brimmed dark brown #644020 hat. A heavy pack over one "
        "shoulder with potion bottles and scrolls visible. Warm, mysterious, trustworthy. No frame."
    ),
})


def generate_one(idx, total, entry):
    subdir = os.path.join(OUT_DIR, entry["subdir"])
    os.makedirs(subdir, exist_ok=True)
    filepath = os.path.join(subdir, entry["filename"])

    if os.path.exists(filepath):
        print(f"[{idx+1}/{total}] SKIP (exists): {entry['subdir']}/{entry['filename']}")
        return True

    print(f"[{idx+1}/{total}] Generating: {entry['subdir']}/{entry['filename']}")

    payload = {
        "model": MODEL,
        "messages": [
            {
                "role": "user",
                "content": entry["prompt"],
            }
        ],
    }

    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
    }

    try:
        resp = requests.post(API_URL, json=payload, headers=headers, timeout=120)
        resp.raise_for_status()
        data = resp.json()
    except Exception as e:
        print(f"  ERROR request failed: {e}")
        return False

    # OpenRouter puts images in message.images[].image_url.url (data URI)
    images = data.get("choices", [{}])[0].get("message", {}).get("images", [])
    for img in images:
        url = img.get("image_url", {}).get("url", "") if isinstance(img, dict) else ""
        if url.startswith("data:image"):
            b64 = url.split(",", 1)[1]
            with open(filepath, "wb") as f:
                f.write(base64.b64decode(b64))
            print(f"  Saved: {filepath} ({os.path.getsize(filepath)} bytes)")
            return True

    print(f"  FAILED: Could not extract image from response")
    print(f"  Response keys: {list(data.keys())}")
    if "choices" in data:
        msg = data["choices"][0].get("message", {})
        print(f"  Message keys: {list(msg.keys())}")
        print(f"  Images count: {len(msg.get('images', []))}")
        c = msg.get("content", "")
        if isinstance(c, str):
            print(f"  Content text: {c[:200]}")
    return False


def main():
    total = len(PROMPTS)
    print(f"Swordjin Art Generator — {total} images via {MODEL}")
    print(f"Output dir: {OUT_DIR}")
    print()

    success = 0
    failed = 0
    skipped = 0

    for idx, entry in enumerate(PROMPTS):
        filepath = os.path.join(OUT_DIR, entry["subdir"], entry["filename"])
        if os.path.exists(filepath):
            skipped += 1
            print(f"[{idx+1}/{total}] SKIP (exists): {entry['subdir']}/{entry['filename']}")
            continue

        ok = generate_one(idx, total, entry)
        if ok:
            success += 1
        else:
            failed += 1

        # Rate limit: be nice to the API
        if idx < total - 1:
            time.sleep(2)

    print()
    print(f"Done! Success: {success}, Failed: {failed}, Skipped: {skipped}")


if __name__ == "__main__":
    main()