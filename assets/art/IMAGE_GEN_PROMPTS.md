# Swordjin — OpenRouter Image Generation Prompts

**Model:** `google/gemini-2.5-flash-image` (cheapest, $0.30/$2.50 per 1M tokens)
**Style anchor (prepend to ALL prompts):**
> Dark fantasy wuxia 2D game art, clean pixel-art inspired style, limited palette: gold #FFD700, steel blue #5080C8, dark bg #0D1117, bone white #DCE6F0, rust #8B2500, purple #8C2E8C. No text, no letters, no words. Square composition, transparent-friendly subject on dark background.

---

## 1. Title Screen Key Art
**File:** `art/title/title_splash.png` (1024×1024, then cropped)

**Prompt:**
> Dark fantasy wuxia 2D game art, clean pixel-art inspired style, limited palette: gold #FFD700, steel blue #5080C8, dark bg #0D1117, bone white #DCE6F0, rust #8B2500, purple #8C2E8C. No text, no letters, no words. A lone swordsman (Jin) in blue tunic standing on a cliff edge at sunset, facing a dark iron fortress in the distance. His sword is drawn and raised. Wind blows his dark brown hair and tunic. Below the cliff, an army of skeletal warriors with glowing green eyes marches toward the fortress. The sky is deep navy #0D1117 with a burning orange #FF8020 sunset on the horizon. Gold #FFD700 light glints off the blade. Epic, dramatic, vertical composition.

---

## 2. Chapter Backgrounds (4 images)

### 2a. Field at Dusk (Chapter 1)
**File:** `art/bg/field_sunset.png` (1920×1080)

**Prompt:**
> Dark fantasy wuxia 2D game art, clean pixel-art inspired style, limited palette: gold #FFD700, steel blue #5080C8, dark bg #0D1117, bone white #DCE6F0, rust #8B2500, purple #8C2E8C. No text, no letters, no words. Wide landscape background, no characters. Open grassy field at dusk. Rolling hills of dark green #2D5A1E grass stretching to the horizon. Sky is deep navy #0D1117 at top fading to burnt orange #FF8020 at the horizon line. A few distant dead trees silhouetted. Scattered rocks #505860. Faint moonlight. Parallax-ready: foreground grass is slightly darker and more detailed, midground has gentle hills, background fades to silhouette. Horizontal 16:9 composition.

### 2b. Dark Forest (Chapter 2)
**File:** `art/bg/forest_night.png` (1920×1080)

**Prompt:**
> Dark fantasy wuxia 2D game art, clean pixel-art inspired style, limited palette: gold #FFD700, steel blue #5080C8, dark bg #0D1117, bone white #DCE6F0, rust #8B2500, purple #8C2E8C. No text, no letters, no words. Wide landscape background, no characters. Dense dark forest at night. Tall gnarled trees with dark canopies #1E3A0E blocking most of the sky. Faint green #00DC00 glow from between tree roots (mushroom light). Ground is dark earth #1E2E14 with exposed roots. Occasional ghostly white #DCE6F0 wisps floating between trees. Sky barely visible through canopy, dark navy #0A0E14. Foreground has close tree trunks, midground has path through trees, background is impenetrable darkness. Spooky, claustrophobic. Horizontal 16:9 composition.

### 2c. Stone Fortress at Dawn (Chapter 3)
**File:** `art/bg/fortress_dawn.png` (1920×1080)

**Prompt:**
> Dark fantasy wuxia 2D game art, clean pixel-art inspired style, limited palette: gold #FFD700, steel blue #5080C8, dark bg #0D1117, bone white #DCE6F0, rust #8B2500, purple #8C2E8C. No text, no letters, no words. Wide landscape background, no characters. Ancient stone fortress at dawn. Massive grey stone walls #505860 with battlements. A steel blue #5080C8 dawn sky above with thin clouds. Torches with orange #FF8020 flames on the ramparts. Gate is slightly ajar with darkness inside. Foreground: stone path and scattered rubble. Midground: fortress gate and walls. Background: mountain silhouettes in morning mist. Imposing, fortified. Horizontal 16:9 composition.

### 2d. Iron Throne Room (Chapter 4)
**File:** `art/bg/iron_throne.png` (1920×1080)

**Prompt:**
> Dark fantasy wuxia 2D game art, clean pixel-art inspired style, limited palette: gold #FFD700, steel blue #5080C8, dark bg #0D1117, bone white #DCE6F0, rust #8B2500, purple #8C2E8C. No text, no letters, no words. Wide landscape background, no characters. Dark iron throne room interior. Massive iron gate #404858 with rust #8B2500 highlights at the far end, faintly glowing red from behind. Walls are dark iron #303848 with torch sconces casting orange #FF8020 light pools. Floor is dark stone #283040 with a long red carpet #8B2500 leading to the gate. Ceiling is lost in shadow #0D1117. Foreground: stone pillars on each side. Dramatic, ominous, final boss atmosphere. Horizontal 16:9 composition.

---

## 3. Achievement Badge Art (20 images, 256×256)

### Batch prompt template (one call per badge, vary the subject):

> Dark fantasy wuxia 2D game art, clean pixel-art inspired style, limited palette: gold #FFD700, steel blue #5080C8, dark bg #0D1117, bone white #DCE6F0, rust #8B2500, purple #8C2E8C. No text, no letters, no words. Single centered achievement badge icon on dark #0D1117 background. Circular frame with gold #FFD700 border and dark fill. Inside the circle: [SUBJECT]. Clean, readable at small size, icon-style, no background detail beyond the circle frame.

**Badge subjects:**

| File | Achievement | Subject |
|------|------------|---------|
| `art/badges/first_blood.png` | First Blood | A single blood-red sword dripping |
| `art/badges/body_count_50.png` | Body Count | A skull pile, 3 skulls stacked |
| `art/badges/body_count_200.png` | Massacre | A mountain of skulls with a sword planted in it |
| `art/badges/flawless_chapter.png` | Untouchable | A glowing blue shield with a gold star |
| `art/badges/first_step.png` | First Step | A single boot stepping onto a stone path |
| `art/badges/half_way.png` | Halfway There | A compass with the needle pointing forward |
| `art/badges/act2_reacher.png` | Beyond the Gate | An iron gate with a crack of red light |
| `art/badges/armory_3.png` | Armed and Ready | Three crossed swords of different sizes |
| `art/badges/armory_all.png` | Living Arsenal | Six weapons arranged in a fan (swords, daggers, bow) |
| `art/badges/bestiary_half.png` | Field Researcher | An open book with a skull bookmark |
| `art/badges/bestiary_all.png` | Monster Scholar | A closed book with a glowing green eye on the cover |
| `art/badges/speed_demon.png` | Speed Demon | A lightning bolt with motion lines |
| `art/badges/perfectionist.png` | Perfectionist | Three gold stars in a triangle |
| `art/badges/legendary_find.png` | Jackpot | A sword radiating gold beams |
| `art/badges/combo_master.png` | Combo King | Three overlapping slash arcs in red-orange-yellow |
| `art/badges/first_crit.png` | Critical Eye | An eye with a golden iris and crosshair pupil |
| `art/badges/crit_50.png` | Death Precision | A bullseye target with an arrow in the center |
| `art/badges/enraged_kill.png` | Rage Against the Dying | A red-veined fist crushing a skull |
| `art/badges/summon_slayer.png` | Necromancer's Bane | A broken staff with purple shards scattering |
| `art/badges/streak_3.png` | Committed | Three lit candles in a row |
| `art/badges/streak_7.png` | Unstoppable | Seven lit candles with the tallest in center |
| `art/badges/daily_challenger.png` | Daily Challenger | A calendar page with a sword through it |
| `art/badges/daily_veteran.png` | Daily Veteran | A medal with seven notches on the ribbon |
| `art/badges/ghost_hunter.png` | Ghost Hunter | A ghost silhouette with a blue targeting reticle |
| `art/badges/speed_demon_5.png` | Speed Demon (5★) | Five small lightning bolts in a circle |

---

## 4. Item Art (6 images, 512×512)

**Batch prompt template:**

> Dark fantasy wuxia 2D game art, clean pixel-art inspired style, limited palette: gold #FFD700, steel blue #5080C8, dark bg #0D1117, bone white #DCE6F0, rust #8B2500, purple #8C2E8C. No text, no letters, no words. Single centered item on dark #0D1117 background. Clean icon style, suitable for inventory display. No frame, no border.

| File | Item | Prompt addition |
|------|------|----------------|
| `art/items/broken_sword.png` | Broken Sword | A rusty broken sword, blade is cracked and chipped with rust #8B2500 spots, handle wrapped in dark leather #3C2D1E, lying at slight angle |
| `art/items/steel_dagger.png` | Steel Dagger | A clean short dagger, silver-white blade #C8C8D2, simple crossguard, dark wood handle #604020, point facing up |
| `art/items/captains_blade.png` | Captain's Blade | An ornate long sword, gleaming blade #E0E8F0, gold #FFD700 crossguard with scrollwork, worn leather grip #604020, ruby pommel, point facing up |
| `art/items/health_potion.png` | Health Potion | A glass bottle of glowing red #E04040 liquid, cork stopper, round-bottomed flask shape, faint red glow around it |
| `art/items/steel_sword.png` | Steel Sword | A standard steel long sword, blade #D0D8E0, steel blue #5080C8 crossguard, leather-wrapped grip #3C2D1E |
| `art/items/gold_coin.png` | Gold Coin | A single gold coin #FFD700 with a sword stamped on it, slight 3/4 rotation to show thickness, edge has reeded detail |

---

## 5. Merchant Portrait (1 image, 512×512)

**File:** `art/npcs/merchant_portrait.png`

**Prompt:**
> Dark fantasy wuxia 2D game art, clean pixel-art inspired style, limited palette: gold #FFD700, steel blue #5080C8, dark bg #0D1117, bone white #DCE6F0, rust #8B2500, purple #8C2E8C. No text, no letters, no words. Portrait of a traveling merchant, bust view, centered on dark #0D1117 background. Elderly man with weathered skin #DCB48C, wise squinting eyes. Wearing a deep purple #8C2E8C robe with gold #FFD700 trim. A wide-brimmed dark brown #644020 hat. A heavy pack over one shoulder with potion bottles and scrolls visible. Warm, mysterious, trustworthy. No frame.

---

## Execution Plan

- **Total images:** 1 + 4 + 25 + 6 + 1 = **37 images**
- **Model:** `google/gemini-2.5-flash-image` via OpenRouter
- **Estimated cost:** ~$1-3 total (Gemini Flash is very cheap)
- **Output format:** Request PNG via the image generation API
- **Sizing:** Title 1024×1024, Backgrounds 1920×1080, Badges 256×256, Items 512×512, Portrait 512×512
- **Save path:** `/home/kirk/Madlab/Clean-Live/Sword-jin_PWA/assets/art/`

### API Notes
- OpenRouter image gen uses the chat completions endpoint with image output models
- Response contains base64-encoded image data in the message content
- Need to parse and decode the base64 to save as PNG files