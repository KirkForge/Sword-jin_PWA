#!/usr/bin/env bash
# Swordjin Art Batch Generator — OpenRouter + Gemini 2.5 Flash Image
set -euo pipefail

API_KEY=$(cat /home/kirk/.picoclaw/workspace/.openrouter)
MODEL="google/gemini-2.5-flash-image"
BASE_URL="https://openrouter.ai/api/v1/chat/completions"
OUTDIR="/home/kirk/Madlab/Clean-Live/Sword-jin_PWA/assets/art"

STYLE="Dark fantasy wuxia 2D game art, clean pixel-art inspired style, limited palette: gold #FFD700, steel blue #5080C8, dark bg #0D1117, bone white #DCE6F0, rust #8B2500, purple #8C2E8C. No text, no letters, no words."

call_api() {
    local prompt="$1"
    local outfile="$2"
    
    if [ -f "$outfile" ]; then
        echo "⏭️  SKIP (exists): $outfile"
        return 0
    fi
    
    echo -n "🎨 Generating: $outfile ... "
    
    local payload
    payload=$(jq -n \
        --arg model "$MODEL" \
        --arg prompt "${STYLE} ${prompt}" \
        '{
            model: $model,
            messages: [{ role: "user", content: $prompt }],
            max_tokens: 4096
        }')
    
    local response
    response=$(curl -s -w "\n%{http_code}" \
        -X POST "$BASE_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $API_KEY" \
        -H "HTTP-Referer: https://github.com/KirkForge/Sword-jin_PWA" \
        -d "$payload")
    
    local http_code
    http_code=$(echo "$response" | tail -1)
    local body
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" != "200" ]; then
        echo "❌ HTTP $http_code"
        echo "$body" | head -c 500
        echo
        return 1
    fi
    
    # Try to extract inline data (base64 image in content)
    local content
    content=$(echo "$body" | jq -r '.choices[0].message.content // empty')
    
    # Check if content is base64 image data
    if echo "$content" | grep -qE '^[A-Za-z0-9+/=]{100,}'; then
        echo "$content" | base64 -d > "$outfile"
        echo "✅ (inline base64, $(wc -c < "$outfile") bytes)"
        return 0
    fi
    
    # Check for parts array with inline_data (Gemini image format)
    local img_data
    img_data=$(echo "$body" | jq -r '.choices[0].message.parts[] | select(.inline_data) | .inline_data.data // empty' 2>/dev/null | head -1)
    if [ -n "$img_data" ]; then
        echo "$img_data" | base64 -d > "$outfile"
        echo "✅ (parts inline_data, $(wc -c < "$outfile") bytes)"
        return 0
    fi
    
    # Check for image_url in content parts
    local img_url
    img_url=$(echo "$body" | jq -r '.choices[0].message.content[] | select(.type=="image_url") | .image_url.url // empty' 2>/dev/null | head -1)
    if [ -n "$img_url" ]; then
        if echo "$img_url" | grep -q '^data:image'; then
            echo "$img_url" | sed 's/^data:image\/png;base64,//' | base64 -d > "$outfile"
            echo "✅ (data URI, $(wc -c < "$outfile") bytes)"
            return 0
        else
            curl -s -o "$outfile" "$img_url"
            echo "✅ (URL download, $(wc -c < "$outfile") bytes)"
            return 0
        fi
    fi
    
    echo "❌ No image data found in response"
    echo "$body" | jq -r '.choices[0].message' 2>/dev/null | head -c 300
    echo
    # Save raw response for debugging
    echo "$body" > "${outfile}.debug.json"
    return 1
}

# === 1. Title Screen ===
call_api \
    "A lone swordsman (Jin) in blue tunic standing on a cliff edge at sunset, facing a dark iron fortress in the distance. His sword is drawn and raised. Wind blows his dark brown hair and tunic. Below the cliff, an army of skeletal warriors with glowing green eyes marches toward the fortress. The sky is deep navy #0D1117 with a burning orange #FF8020 sunset on the horizon. Gold #FFD700 light glints off the blade. Epic, dramatic, vertical composition." \
    "$OUTDIR/title/title_splash.png"

# === 2. Chapter Backgrounds ===
call_api \
    "Wide landscape background, no characters. Open grassy field at dusk. Rolling hills of dark green #2D5A1E grass stretching to the horizon. Sky is deep navy #0D1117 at top fading to burnt orange #FF8020 at the horizon line. A few distant dead trees silhouetted. Scattered rocks #505860. Faint moonlight. Parallax-ready: foreground grass is slightly darker and more detailed, midground has gentle hills, background fades to silhouette. Horizontal 16:9 composition." \
    "$OUTDIR/bg/field_sunset.png"

call_api \
    "Wide landscape background, no characters. Dense dark forest at night. Tall gnarled trees with dark canopies #1E3A0E blocking most of the sky. Faint green #00DC00 glow from between tree roots (mushroom light). Ground is dark earth #1E2E14 with exposed roots. Occasional ghostly white #DCE6F0 wisps floating between trees. Sky barely visible through canopy, dark navy #0A0E14. Foreground has close tree trunks, midground has path through trees, background is impenetrable darkness. Spooky, claustrophobic. Horizontal 16:9 composition." \
    "$OUTDIR/bg/forest_night.png"

call_api \
    "Wide landscape background, no characters. Ancient stone fortress at dawn. Massive grey stone walls #505860 with battlements. A steel blue #5080C8 dawn sky above with thin clouds. Torches with orange #FF8020 flames on the ramparts. Gate is slightly ajar with darkness inside. Foreground: stone path and scattered rubble. Midground: fortress gate and walls. Background: mountain silhouettes in morning mist. Imposing, fortified. Horizontal 16:9 composition." \
    "$OUTDIR/bg/fortress_dawn.png"

call_api \
    "Wide landscape background, no characters. Dark iron throne room interior. Massive iron gate #404858 with rust #8B2500 highlights at the far end, faintly glowing red from behind. Walls are dark iron #303848 with torch sconces casting orange #FF8020 light pools. Floor is dark stone #283040 with a long red carpet #8B2500 leading to the gate. Ceiling is lost in shadow #0D1117. Foreground: stone pillars on each side. Dramatic, ominous, final boss atmosphere. Horizontal 16:9 composition." \
    "$OUTDIR/bg/iron_throne.png"

# === 3. Achievement Badges (25) ===
BADGE_PROMPT_PREFIX="Single centered achievement badge icon on dark #0D1117 background. Circular frame with gold #FFD700 border and dark fill. Inside the circle:"

declare -A BADGES
BADGES[first_blood]="A single blood-red sword dripping"
BADGES[body_count_50]="A skull pile, 3 skulls stacked"
BADGES[body_count_200]="A mountain of skulls with a sword planted in it"
BADGES[flawless_chapter]="A glowing blue shield with a gold star"
BADGES[first_step]="A single boot stepping onto a stone path"
BADGES[half_way]="A compass with the needle pointing forward"
BADGES[act2_reacher]="An iron gate with a crack of red light"
BADGES[armory_3]="Three crossed swords of different sizes"
BADGES[armory_all]="Six weapons arranged in a fan (swords, daggers, bow)"
BADGES[bestiary_half]="An open book with a skull bookmark"
BADGES[bestiary_all]="A closed book with a glowing green eye on the cover"
BADGES[speed_demon]="A lightning bolt with motion lines"
BADGES[perfectionist]="Three gold stars in a triangle"
BADGES[legendary_find]="A sword radiating gold beams"
BADGES[combo_master]="Three overlapping slash arcs in red-orange-yellow"
BADGES[first_crit]="An eye with a golden iris and crosshair pupil"
BADGES[crit_50]="A bullseye target with an arrow in the center"
BADGES[enraged_kill]="A red-veined fist crushing a skull"
BADGES[summon_slayer]="A broken staff with purple shards scattering"
BADGES[streak_3]="Three lit candles in a row"
BADGES[streak_7]="Seven lit candles with the tallest in center"
BADGES[daily_challenger]="A calendar page with a sword through it"
BADGES[daily_veteran]="A medal with seven notches on the ribbon"
BADGES[ghost_hunter]="A ghost silhouette with a blue targeting reticle"
BADGES[speed_demon_5]="Five small lightning bolts in a circle"

for badge in "${!BADGES[@]}"; do
    call_api "${BADGE_PROMPT_PREFIX} ${BADGES[$badge]}" "$OUTDIR/badges/${badge}.png"
done

# === 4. Item Art (6) ===
ITEM_PROMPT_PREFIX="Single centered item on dark #0D1117 background. Clean icon style, suitable for inventory display. No frame, no border."

call_api "${ITEM_PROMPT_PREFIX} A rusty broken sword, blade is cracked and chipped with rust #8B2500 spots, handle wrapped in dark leather #3C2D1E, lying at slight angle" "$OUTDIR/items/broken_sword.png"
call_api "${ITEM_PROMPT_PREFIX} A clean short dagger, silver-white blade #C8C8D2, simple crossguard, dark wood handle #604020, point facing up" "$OUTDIR/items/steel_dagger.png"
call_api "${ITEM_PROMPT_PREFIX} An ornate long sword, gleaming blade #E0E8F0, gold #FFD700 crossguard with scrollwork, worn leather grip #604020, ruby pommel, point facing up" "$OUTDIR/items/captains_blade.png"
call_api "${ITEM_PROMPT_PREFIX} A glass bottle of glowing red #E04040 liquid, cork stopper, round-bottomed flask shape, faint red glow around it" "$OUTDIR/items/health_potion.png"
call_api "${ITEM_PROMPT_PREFIX} A standard steel long sword, blade #D0D8E0, steel blue #5080C8 crossguard, leather-wrapped grip #3C2D1E" "$OUTDIR/items/steel_sword.png"
call_api "${ITEM_PROMPT_PREFIX} A single gold coin #FFD700 with a sword stamped on it, slight 3/4 rotation to show thickness, edge has reeded detail" "$OUTDIR/items/gold_coin.png"

# === 5. Merchant Portrait ===
call_api \
    "Portrait of a traveling merchant, bust view, centered on dark #0D1117 background. Elderly man with weathered skin #DCB48C, wise squinting eyes. Wearing a deep purple #8C2E8C robe with gold #FFD700 trim. A wide-brimmed dark brown #644020 hat. A heavy pack over one shoulder with potion bottles and scrolls visible. Warm, mysterious, trustworthy. No frame." \
    "$OUTDIR/npcs/merchant_portrait.png"

echo ""
echo "========================================="
echo "🎉 Batch complete! Generated files:"
echo "========================================="
find "$OUTDIR" -name "*.png" -exec ls -lh {} \; 2>/dev/null | sort