# Swordjin — Codex Work Order

## Project Overview

**Swordjin** is a lightweight fantasy action RPG built in Godot 4.4.1 (GL Compatibility renderer), targeting PWA/HTML5 and mobile. 640×360 viewport, pixel-art aesthetic, 3-5 minute chapter sessions with strong retention hooks.

**Repo:** `git@github.com:KirkForge/Sword-jin_PWA.git`
**Branch:** `main`
**Current version:** v0.73a (Critical hits + hit flash + XP popups)
**Codebase:** ~6,300 lines GDScript across 41 scripts, 32 scenes, 20 chapters across 4 acts

---

## Current State (v0.72)

### What's Done

| System | Status | Details |
|--------|--------|---------|
| Core combat | ✅ | Player, 10 enemy types, dodge roll, charged heavy, 4 skills, hit stop, damage numbers |
| 4 acts / 20 chapters | ✅ | JSON-driven, arena_builder procedural tilemaps, dialogue triggers |
| 3 boss fights | ✅ | Skeleton Captain (Act 1), Golem+Ghost (Act 2), Shadow Lord 2-phase (Act 3) |
| 8 weapons | ✅ | broken_sword → shadow_blade, unlock via chapter rewards |
| 4 skills | ✅ | whirlwind_slash, shadow_step, battle_cry, dodge_roll |
| Loot rarity | ✅ | Common/uncommon/rare/legendary with variable ratio weights, bosses boosted |
| Critical hits | ✅ | 10% chance, 1.5× damage, gold text + "!" + scale punch, distinct SFX |
| Hit flash | ✅ | White flash on crit, red on normal, brown on golem, purple on dark mage |
| XP popups | ✅ | setup_xp() in DamageNumber, blue text, smaller font, float up |
| Bestiary | ✅ | 10 enemy types, kill tracking, lore unlocks at 10/50/100 kills |
| Achievements | ✅ | 16 auto-awarded, popup toast on unlock |
| Chapter stars | ✅ | 1-3 stars per chapter (completion, speed, no-damage) |
| Rested XP | ✅ | 2× XP for first 3 chapters after 8h+ break |
| Daily streak | ✅ | Escalating gold/potion rewards, streak counter |
| Daily challenge | ✅ | Deterministic seed, 8 modifiers, challenge UI, completion tracking |
| Stats dashboard | ✅ | Streak, rested XP, stars, gold, level, weapons |
| Save v3 | ✅ | Backward-compatible, auto-migrates from v1/v2 |
| Mobile controls | ✅ | Touch joystick + action buttons |
| PWA pipeline | ✅ | Export presets, patch script |

### Enemy Types (10)
skeleton, skeleton_archer, skeleton_captain, ghost, bandit, assassin, golem, dark_mage, wolf, shadow_lord

### Enemy Scenes Status
- ✅ Full sprites: skeleton, skeleton_archer, skeleton_captain, shadow_lord, dark_mage, wolf
- ⬜ ColorRect placeholders: ghost, bandit, assassin, golem (functional, need real sprites)

---

## Work Order: v0.73 — Polish & PWA Readiness

### Priority 1: PWA Export Validation

**Goal:** Get the game running in a browser with zero crashes and full touch support.

1. **Export and test HTML5 build**
   - Run Godot export to HTML5
   - Test in Chrome, Firefox, Safari mobile
   - Verify touch controls work on mobile viewport
   - Verify audio plays (Web Audio API compatibility)
   - Check save/load works with `user://` on web (should use IndexedDB via Godot)

2. **PWA manifest validation**
   - Verify `manifest.json` has correct `start_url`, `display: standalone`, icons
   - Test "Add to Home Screen" on iOS and Android
   - Verify service worker caches game assets
   - Test offline play after first load

3. **Performance profiling**
   - Target: 60fps on mid-range phones (Snapdragon 778G equivalent)
   - Profile arena_builder tilemap rendering
   - Check draw call count (target < 100 per frame)
   - Verify GL Compatibility renderer doesn't fall back to software

### Priority 2: Juice & Feel

**Goal:** Make combat feel snappy and satisfying.

4. **Screen shake** — Already exists (`screen_shake.gd`). Tune values:
   - Boss phase transitions: heavy shake (12px, 0.4s)
   - Player hit: medium shake (6px, 0.2s)
   - Player dodge: micro shake (2px, 0.1s)
   - Enemy death: small shake (4px, 0.15s)

5. **Hit flash** — White flash on damage:
   - Player hit: flash white 0.1s
   - Enemy hit: flash white 0.08s
   - Boss phase change: red flash 0.3s

6. **Damage numbers** — Already exist (`damage_number.gd`). Add:
   - Critical hits (random 10% chance, 1.5× damage, gold text, bigger font)
   - Healing numbers (green, float up)
   - XP gain popups (blue, float up after enemy kill)

7. **Audio polish**
   - Verify all SFX play correctly (attack hit, dodge, skill, boss phase, UI clicks)
   - Add missing: loot drop sound, achievement unlock sound, level-up fanfare
   - BGM crossfade between acts

### Priority 3: Missing Enemy Sprites

8. **Replace ColorRect placeholders with pixel art sprites**
   - ghost: semi-transparent blue-white wisp (16×16, 3 frames: idle/attack/die)
   - bandit: brown-cloaked rogue (16×16, 3 frames: idle/walk/attack)
   - assassin: dark-cloaked figure, red eyes (16×16, 3 frames: idle/dash/attack)
   - golem: large stone creature (24×32, 3 frames: idle/attack/stomp)

   Use `scripts/generate_sprites_v2.py` to generate placeholder sprites, or create hand-drawn pixel art. Each enemy needs `idle.png`, `walk.png`, `attack.png` in `assets/sprites/{enemy_type}/`.

### Priority 4: Act 3 & 4 Level Layouts

9. **Create .tscn scene files for chapters 011–020**
   - Currently arena_builder generates procedural tilemaps from JSON, but we need hand-crafted `.tscn` layouts for boss arenas and narrative moments
   - ch011: Underground entrance (narrow corridors, dark theme)
   - ch012–014: Caverns (wide arenas, stalagmites, dark_mage enemies)
   - ch015: Shadow Lord boss arena (large, dramatic lighting)
   - ch016–017: City streets (urban cover, bandit/assassin enemies)
   - ch018–019: Throne room approach (dark_mage + wolf packs)
   - ch020: Final Shadow Lord Commander fight (massive arena, phase transitions)

### Priority 5: Quality of Life

10. **Settings screen improvements**
    - SFX volume slider (currently BGM only)
    - Screen shake toggle (accessibility)
    - Reset save confirmation dialog
    - Credits screen

11. **Victory screen polish**
    - Show loot rarity with colored glow
    - Star animation (spin in one at a time)
    - "Next Chapter" button with preview text

12. **Chapter select screen**
    - Grid of 20 chapters with lock/unlock states
    - Star display per chapter
    - Act headers (Act 1: The Village, Act 2: The Fortress, etc.)

---

## Architecture Reference

### Key Autoloads (singleton scripts)
- `GameState` (`scripts/autoload/game_state.gd`) — Save/load, progression, inventory, streaks, bestiary, achievements
- `ChapterDatabase` (`scripts/autoload/chapter_database.gd`) — Chapter JSON loading, current chapter state
- `AudioManager` (`scripts/autoload/audio_manager.gd`) — BGM/SFX management

### Scene Structure
```
scenes/
├── main.tscn              # Game root (loads level_manager)
├── title_screen.tscn      # MainMenu: New/Continue/Stats/Achievements/Daily
├── player.tscn            # Player character
├── skeleton.tscn          # Enemy scenes (10 types)
├── ...                    # Each enemy has .tscn + .gd
├── shadow_lord.tscn       # Act 3 boss (2-phase)
├── mobile_controls.tscn   # Touch joystick + buttons
├── chapter_manager.tscn  # Chapter flow controller
├── dialogue_manager.tscn  # Dialogue box overlay
├── screen_fader.tscn      # Transition effects
├── ui/                    # All UI screens
│   ├── victory_screen.tscn
│   ├── bestiary_screen.tscn
│   ├── achievements_screen.tscn
│   ├── stats_screen.tscn
│   ├── daily_challenge_screen.tscn
│   ├── streak_popup.tscn
│   └── achievement_popup.tscn
└── projectiles/           # Arrow, shadow_bolt, etc.
```

### Chapter JSON Format (example: `chapters/act01/chapter001.json`)
```json
{
  "chapter_id": "act01_ch001",
  "title": "The Rusted Blade",
  "act": 1,
  "chapter": 1,
  "type": "combat",
  "playtime_estimate_minutes": 3,
  "objective": "Defeat 4 skeletons",
  "background_color": [0.08, 0.1, 0.12],
  "enemies": [
    {"type": "skeleton", "count": 4, "positions": [...], "stats": {...}}
  ],
  "dialogue": [
    {"speaker": "INNKEEPER", "text": "...", "trigger": "start"}
  ],
  "rewards": {"xp": 50, "unlock_weapon": "broken_sword", "gold": 10},
  "next_chapter": "act01_ch002",
  "is_unlocked": true
}
```

### Save Format (v3.0)
```json
{
  "version": "3.0",
  "gold": 0,
  "weapons_unlocked": ["broken_sword"],
  "current_weapon": "broken_sword",
  "xp": 0,
  "level": 1,
  "chapters_completed": [],
  "chapter_stars": {},
  "bestiary_kills": {},
  "achievements": [],
  "daily_streak": 0,
  "last_login": "",
  "rested_chapters_remaining": 0,
  "daily_challenge_completed": ""
}
```

### Loot System
- Boss kills: guaranteed uncommon+, 30% rare, 5% legendary
- Regular kills: 60% common, 25% uncommon, 10% rare, 5% legendary
- Gold drops scale with tier (common: 2-5, legendary: 40-100)

### Combat Mechanics
- Player: 100 HP, dodge roll (i-frames), 4 skills, weapon switching
- Enemies: individual AI scripts, type-specific behavior
- Bosses: `is_in_group("boss")`, loot table override, health phases
- Damage: weapon_damage × skill_mult, critical = random 10% chance × 1.5
- Hit stop: 3 frames on player hit, 2 frames on enemy hit

---

## Testing Checklist

- [ ] Fresh install: new game → chapter 001 → victory → chapter select
- [ ] Save/load: complete 3 chapters, restart, verify all progress persists
- [ ] Rested XP: close game, set clock +8h, reopen, verify 2× indicator shows
- [ ] Daily streak: close game, set clock +24h, reopen, verify streak increments
- [ ] Daily challenge: verify seed-based modifiers change per day
- [ ] Bestiary: kill 10 of one type, verify lore unlock
- [ ] Achievements: verify "First Blood" triggers on first kill
- [ ] Boss fights: verify Shadow Lord 2-phase, loot drops with rarity glow
- [ ] Mobile: touch controls, viewport scaling, no crashes
- [ ] PWA: Add to Home Screen, offline play, service worker caching

---

## File Conventions

- GDScript 4 (typed where possible, `@export` for inspector vars)
- Scenes: `.tscn` with matching `.gd` script
- Chapter data: `chapters/actXX/chapterNNN.json`
- Sprites: `assets/sprites/{enemy_type}/{idle,walk,attack,die}.png` (16×16 or 24×32 for large)
- Save file: `user://swordjin_save.json`
- All UI screens in `scenes/ui/`
- All autoloads in `scripts/autoload/`

---

## Next Milestones (after v0.73)

| Version | Focus |
|---------|-------|
| v0.80 | P2P co-op (4 players, ENetMultiplayerPeer, host/join by IP) |
| v0.85 | Ghost runs / leaderboards (PlayFab) |
| v0.90 | Soundtrack + SFX pass |
| v1.00 | Launch: full PWA, app store submission |

---

*"The rusted blade is all I have. But it's enough."* — Jin