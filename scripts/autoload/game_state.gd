extends Node
# GameState — Persistent save/load + progression tracking
# v0.80 — ghost runs + local leaderboard

const SAVE_FILE := "user://swordjin_save.json"

# Rarity tiers — color coding & drop weights
const RARITY := {
	"common":    {"color": "#AAAAAA", "weight": 60, "label": "Common"},
	"uncommon":  {"color": "#55FF55", "weight": 25, "label": "Uncommon"},
	"rare":      {"color": "#5555FF", "weight": 12, "label": "Rare"},
	"legendary": {"color": "#FFAA00", "weight": 3,  "label": "Legendary"},
}

# Weapon definitions — unlocked weapons auto-equip if better
const WEAPON_STATS := {
	"broken_sword":    {"damage": 8,  "cooldown": 0.40, "rarity": "common",    "description": "A rusted relic. Barely sharp."},
	"steel_dagger":    {"damage": 12, "cooldown": 0.30, "rarity": "common",    "description": "Merchant's gift. Light and lethal."},
	"captains_blade":  {"damage": 15, "cooldown": 0.50, "rarity": "uncommon",  "description": "A commander's weapon. Heavy but ruthless."},
	"spirit_edge":     {"damage": 18, "cooldown": 0.35, "rarity": "uncommon",  "description": "Ghost-forged blade. Cuts ethereal and flesh alike."},
	"crimson_edge":    {"damage": 22, "cooldown": 0.45, "rarity": "rare",      "description": "Fang officer's saber. Wickedly fast."},
	"wardens_halberd": {"damage": 28, "cooldown": 0.60, "rarity": "legendary", "description": "Gate Warden's polearm. Devastating reach."},
}

# Skill definitions
const SKILL_STATS := {
	"whirlwind_slash": {"damage_mult": 1.5, "cooldown": 2.0, "radius": 60, "description": "Spin attack hitting all nearby enemies."},
	"shadow_step":     {"distance": 150, "cooldown": 3.0, "damage": 10, "description": "Teleport behind target + stab."},
	"battle_cry":      {"heal_pct": 0.15, "cooldown": 5.0, "buff_duration": 3.0, "description": "War cry: heals 15% HP + damage buff."},
	"dodge_roll":      {"cooldown": 1.2, "description": "Dash in facing direction with i-frames."},
}

# Inventory
var inventory: Dictionary = {
	"potions": 0,
	"keys": {},
	"artifacts": [],
	"gold": 0,
}

# Player Progress
var current_act: int = 1
var current_chapter: int = 1
var completed_chapters: Array = []
var player_level: int = 1
var player_xp: int = 0
var player_gold: int = 0
var unlocked_weapons: Array = []
var unlocked_skills: Array = []
var equipped_weapon: String = "broken_sword"
var equipped_skills: Array = ["dodge_roll"]

# Settings
var settings: Dictionary = {
	"master_volume": 1.0,
	"sfx_volume": 1.0,
	"bgm_volume": 0.7,
	"screen_shake": true,
	"hit_stop": true,
	"show_damage_numbers": true,
	"auto_aim": false,
	"text_speed": 1.0,
}

# Gate Key mechanic (Ch004)
var has_gate_key := false

# Chapter State (runtime only)
var chapter_kills: int = 0
var chapter_objectives_met: Dictionary = {}
var is_paused: bool = false

# Health persistence
var saved_health: int = 100
var saved_max_health: int = 100

# Poison state
var poison_timer: float = 0.0
var poison_damage: int = 0
var poison_tick_rate: float = 1.0

# Battle cry buff
var damage_buff_mult: float = 1.0
var damage_buff_timer: float = 0.0

# Chapter Stars (chapter_id → 1-3 stars)
# ⭐ = complete the chapter
# ⭐⭐ = complete without dying
# ⭐⭐⭐ = complete under par time
var chapter_stars: Dictionary = {}

# Bestiary definitions — enemy type catalog with lore unlocks at kill milestones
const BESTIARY := {
	"skeleton": {
		"name": "Skeleton",
		"description": "Reanimated bones of fallen soldiers. Shambling but relentless.",
		"lore": {
			10: "Skeletons are the weakest of the undead, animated by residual battlefield malice.",
			50: "A skeleton's bones rattle with ancient war memories. Some still clutch rusted weapons.",
			100: "The oldest skeletons can reform after destruction — only fire or holy blades end them permanently.",
		},
		"stats": {"hp": 30, "damage": 8, "speed": 80, "type": "Undead"},
	},
	"skeleton_archer": {
		"name": "Skeleton Archer",
		"description": "Bone archers that keep their distance and rain arrows from afar.",
		"lore": {
			10: "Skeleton archers retain enough muscle memory to aim, but their arrows fly erratically.",
			50: "Some archer skeletons still carry quivers from their living days — arrows marked with regiment sigils.",
			100: "The finest skeleton archers were once imperial marksmen. Their undead accuracy is terrifying.",
		},
		"stats": {"hp": 25, "damage": 7, "speed": 70, "type": "Undead"},
	},
	"skeleton_captain": {
		"name": "Skeleton Captain",
		"description": "Armored commander of the undead. Shield blocks attacks. Charges when enraged.",
		"lore": {
			5: "Captains were military officers in life. Death hasn't diminished their tactical instinct.",
			25: "The captain's shield bears the crest of a kingdom that no longer exists.",
			50: "Skeleton captains can command lesser undead. Destroying one often causes nearby skeletons to falter.",
		},
		"stats": {"hp": 80, "damage": 15, "speed": 65, "type": "Undead • Boss"},
	},
	"ghost": {
		"name": "Ghost",
		"description": "Spectral entity that phases between tangible and intangible. Attacks pierce armor.",
		"lore": {
			10: "Ghosts are souls trapped between worlds. They flicker when they phase, briefly vulnerable.",
			50: "The ghost's wail isn't just eerie — it's a resonance attack that weakens the living's will to fight.",
			100: "Ancient ghosts can possess the living. The spectral blade 'Spirit Edge' is forged from their essence.",
		},
		"stats": {"hp": 35, "damage": 18, "speed": 60, "type": "Spectral"},
	},
	"bandit": {
		"name": "Bandit",
		"description": "Fast flanking fighter. Circles behind targets and strikes quickly.",
		"lore": {
			10: "Bandits are deserters and outlaws who prey on travelers along the Iron Road.",
			50: "The Crimson Fang recruits bandits with promises of gold and power. Most don't live to collect.",
			100: "Some bandits were once imperial soldiers — their military training makes them dangerous even without armor.",
		},
		"stats": {"hp": 50, "damage": 12, "speed": 90, "type": "Human"},
	},
	"assassin": {
		"name": "Assassin",
		"description": "Crimson Fang elite. Vanishes and reappears behind targets. Poisoned blades.",
		"lore": {
			5: "Assassins are Crimson Fang operatives trained in shadow techniques and venomcraft.",
			25: "An assassin's poison slows the heart and clouds the mind. Without an antidote, death follows within hours.",
			50: "The Crimson Fang's assassination order has toppled three kingdoms. Their symbol: a red fang in shadow.",
		},
		"stats": {"hp": 45, "damage": 20, "speed": 140, "type": "Human • Elite"},
	},
	"golem": {
		"name": "Golem",
		"description": "Massive stone construct. Armor absorbs damage. Devastating but slow attacks.",
		"lore": {
			5: "Golems are ancient constructs built to guard fortresses. Their stone skin deflects most blades.",
			25: "A golem's core is a geode of compressed earth magic. Destroying it is the only way to stop one.",
			50: "The Gate Warden golem has stood for a thousand years. Its halberd is the legendary Wardens_halberd.",
		},
		"stats": {"hp": 180, "damage": 30, "speed": 40, "type": "Construct"},
	},
}

# Kill tracking: enemy_type → total kill count (persisted)
var bestiary: Dictionary = {}  # enemy_type → {"kills": int, "lore_unlocked": [int]}

# ─── Achievement Badges ──────────────────────────────────────────────────────
# 4 categories: Combat, Exploration, Collection, Mastery
# Each achievement has: id, name, icon (emoji), description, category, condition function

const ACHIEVEMENTS := {
	# Combat
	"first_blood": {
		"name": "First Blood",
		"icon": "🗡",
		"description": "Defeat your first enemy.",
		"category": "Combat",
	},
	"body_count_50": {
		"name": "Body Count",
		"icon": "💀",
		"description": "Defeat 50 enemies total.",
		"category": "Combat",
	},
	"body_count_200": {
		"name": "Massacre",
		"icon": "☠",
		"description": "Defeat 200 enemies total.",
		"category": "Combat",
	},
	"flawless_chapter": {
		"name": "Untouchable",
		"icon": "🛡",
		"description": "Complete a chapter without dying.",
		"category": "Combat",
	},
	# Exploration
	"first_step": {
		"name": "First Step",
		"icon": "👣",
		"description": "Complete your first chapter.",
		"category": "Exploration",
	},
	"half_way": {
		"name": "Halfway There",
		"icon": "🗺",
		"description": "Complete 5 chapters.",
		"category": "Exploration",
	},
	"act2_reacher": {
		"name": "Beyond the Gate",
		"icon": "🏰",
		"description": "Reach Act 2.",
		"category": "Exploration",
	},
	# Collection
	"armory_3": {
		"name": "Armed and Ready",
		"icon": "⚔",
		"description": "Collect 3 different weapons.",
		"category": "Collection",
	},
	"armory_all": {
		"name": "Living Arsenal",
		"icon": "🔧",
		"description": "Collect all 6 weapons.",
		"category": "Collection",
	},
	"bestiary_half": {
		"name": "Field Researcher",
		"icon": "📖",
		"description": "Discover 4 enemy types in the bestiary.",
		"category": "Collection",
	},
	"bestiary_all": {
		"name": "Monster Scholar",
		"icon": "🎓",
		"description": "Discover all 7 enemy types in the bestiary.",
		"category": "Collection",
	},
	# Mastery
	"speed_demon": {
		"name": "Speed Demon",
		"icon": "⚡",
		"description": "Earn a 3-star rating on any chapter.",
		"category": "Mastery",
	},
	"perfectionist": {
		"name": "Perfectionist",
		"icon": "💎",
		"description": "Earn 3 stars on 5 chapters.",
		"category": "Mastery",
	},
	"legendary_find": {
		"name": "Jackpot",
		"icon": "🌟",
		"description": "Find a legendary-rarity weapon drop.",
		"category": "Mastery",
	},
	# Streak (Retention)
	"streak_3": {
		"name": "Committed",
		"icon": "🔥",
		"description": "Log in 3 days in a row.",
		"category": "Mastery",
	},
	"streak_7": {
		"name": "Unstoppable",
		"icon": "🔥",
		"description": "Log in 7 days in a row.",
		"category": "Mastery",
	},
	# Daily Challenge (Retention)
	"daily_challenger": {
		"name": "Daily Challenger",
		"icon": "⚔",
		"description": "Complete your first daily challenge.",
		"category": "Mastery",
	},
	"daily_veteran": {
		"name": "Daily Veteran",
		"icon": "🏅",
		"description": "Complete 7 daily challenges.",
		"category": "Mastery",
	},
	# Ghost Runs (Social)
	"ghost_hunter": {
		"name": "Ghost Hunter",
		"icon": "👻",
		"description": "Beat your own ghost in a chapter.",
		"category": "Mastery",
	},
	"speed_demon_5": {
		"name": "Speed Demon",
		"icon": "⚡",
		"description": "Earn ⭐⭐⭐ on 5 different chapters.",
		"category": "Mastery",
	},
}

# Achievement tracking (persisted)
var achievements_unlocked: Dictionary = {}  # achievement_id → timestamp (float, OS.get_unix_time())
signal achievement_unlocked(achievement_id: String, achievement_data: Dictionary)

# ─── Daily Login Streak ───────────────────────────────────────────────────────
# Consecutive days played → escalating gold + potion rewards
# Streak breaks if >24h since last login
# Streak caps at 7 days, then cycles (day 8 = day 1 rewards again, streak counter keeps going)

const STREAK_REWARDS := {
	1: {"gold": 10,  "potions": 0, "label": "Day 1 — 10g"},
	2: {"gold": 20,  "potions": 1, "label": "Day 2 — 20g + 1🧪"},
	3: {"gold": 30,  "potions": 1, "label": "Day 3 — 30g + 1🧪"},
	4: {"gold": 50,  "potions": 2, "label": "Day 4 — 50g + 2🧪"},
	5: {"gold": 75,  "potions": 2, "label": "Day 5 — 75g + 2🧪"},
	6: {"gold": 100, "potions": 3, "label": "Day 6 — 100g + 3🧪"},
	7: {"gold": 150, "potions": 3, "label": "Day 7 — 150g + 3🧪 🔥"},
}

var daily_streak: int = 0          # Consecutive days
var last_login_date: String = ""   # YYYY-MM-DD format (UTC date)
var streak_claimed_today: bool = false  # Whether today's reward was claimed
signal streak_claimed(streak_day: int, rewards: Dictionary)

# ─── Daily Challenge ──────────────────────────────────────────────────────────
# Deterministic daily challenge: seeded by date, picks chapter + modifiers
# Same challenge for everyone on the same day
# Bonus gold reward + achievement tracking

const DAILY_CHALLENGE_MODIFIERS := {
	"double_enemies": {
		"icon": "👥",
		"label": "Double Trouble",
		"description": "2× enemy count",
		"color": "#FF5555",
	},
	"no_potions": {
		"icon": "🚫",
		"label": "No Heal",
		"description": "No potions drop",
		"color": "#FF8800",
	},
	"speed_run": {
		"icon": "⏱",
		"label": "Speed Run",
		"description": "Complete in 90 seconds",
		"color": "#55FFFF",
	},
	"glass_cannon": {
		"icon": "💀",
		"label": "Glass Cannon",
		"description": "50% HP, 2× damage",
		"color": "#FF55FF",
	},
	"armored_foes": {
		"icon": "🛡",
		"label": "Armored Foes",
		"description": "Enemies have +50% HP",
		"color": "#AAAAFF",
	},
	"no_dodge": {
		"icon": "⚡",
		"label": "No Dodge",
		"description": "Dodge roll disabled",
		"color": "#FFFF55",
	},
	"elite_patrol": {
		"icon": "👑",
		"label": "Elite Patrol",
		"description": "All enemies are captains",
		"color": "#FFAA55",
	},
	"poison_swamp": {
		"icon": "☠",
		"label": "Poison Swamp",
		"description": "1 poison tick/3sec",
		"color": "#55FF55",
	},
}

# Daily challenge state
var daily_challenge_completed_today: bool = false
var daily_challenge_best_gold: int = 0  # Lifetime best gold from daily challenges
var daily_challenge_total_completed: int = 0  # Lifetime total completions
signal daily_challenge_completed(rewards: Dictionary)

# Daily challenge runtime state (not persisted, set when starting a challenge)
var is_daily_challenge_run: bool = false
var active_daily_modifiers: Array = []  # Array of modifier IDs active this run

# Loot tracking
var chapter_loot: Array = []  # Runtime: items dropped this chapter run
var collected_weapons: Dictionary = {}  # weapon_id → {"count": int, "best_rarity": String}

# Chapter performance tracking (runtime, reset per chapter)
var chapter_start_time: float = 0.0
var chapter_deaths: int = 0

# Ghost run settings (persisted)
var ghost_runs_enabled: bool = true  # Whether to show ghost replays

func _ready():
	load_game()
	_check_daily_streak()
	print("GameState loaded — Act %d, Ch %d, Level %d, Weapon: %s, Skills: %s, Streak: %d" % [current_act, current_chapter, player_level, equipped_weapon, str(equipped_skills), daily_streak])

func save_game():
	var data := {
		"version": "2.1",
		"current_act": current_act,
		"current_chapter": current_chapter,
		"completed_chapters": completed_chapters,
		"player_level": player_level,
		"player_xp": player_xp,
		"player_gold": player_gold,
		"unlocked_weapons": unlocked_weapons,
		"unlocked_skills": unlocked_skills,
		"equipped_weapon": equipped_weapon,
		"equipped_skills": equipped_skills,
		"saved_health": saved_health,
		"saved_max_health": saved_max_health,
		"has_gate_key": has_gate_key,
		"inventory": inventory,
		"settings": settings,
		"chapter_stars": chapter_stars,
		"collected_weapons": collected_weapons,
		"bestiary": bestiary,
		"achievements_unlocked": achievements_unlocked,
		"daily_streak": daily_streak,
		"last_login_date": last_login_date,
		"streak_claimed_today": streak_claimed_today,
		"daily_challenge_completed_today": daily_challenge_completed_today,
		"daily_challenge_best_gold": daily_challenge_best_gold,
		"daily_challenge_total_completed": daily_challenge_total_completed,
		"ghost_runs_enabled": ghost_runs_enabled,
	}
	
	var file := FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print("Game saved")
	else:
		push_error("Failed to save game")

func load_game():
	if not FileAccess.file_exists(SAVE_FILE):
		print("No save file — starting fresh")
		return
	
	var file := FileAccess.open(SAVE_FILE, FileAccess.READ)
	if file == null:
		push_error("Cannot read save file")
		return
	
	var text := file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("Save file corrupt — starting fresh")
		return
	
	var data = json.data
	if data is Dictionary:
		current_act = data.get("current_act", 1)
		current_chapter = data.get("current_chapter", 1)
		completed_chapters = data.get("completed_chapters", [])
		player_level = data.get("player_level", 1)
		player_xp = data.get("player_xp", 0)
		player_gold = data.get("player_gold", 0)
		unlocked_weapons = data.get("unlocked_weapons", [])
		unlocked_skills = data.get("unlocked_skills", [])
		equipped_weapon = data.get("equipped_weapon", "broken_sword")
		equipped_skills = data.get("equipped_skills", ["dodge_roll"])
		saved_health = data.get("saved_health", 100)
		saved_max_health = data.get("saved_max_health", 100)
		has_gate_key = data.get("has_gate_key", false)
		inventory = data.get("inventory", {"potions": 0, "keys": {}, "artifacts": [], "gold": 0})
		chapter_stars = data.get("chapter_stars", {})
		collected_weapons = data.get("collected_weapons", {})
		bestiary = data.get("bestiary", {})
		achievements_unlocked = data.get("achievements_unlocked", {})
		daily_streak = data.get("daily_streak", 0)
		last_login_date = data.get("last_login_date", "")
		streak_claimed_today = data.get("streak_claimed_today", false)
		daily_challenge_completed_today = data.get("daily_challenge_completed_today", false)
		daily_challenge_best_gold = data.get("daily_challenge_best_gold", 0)
		daily_challenge_total_completed = data.get("daily_challenge_total_completed", 0)
		ghost_runs_enabled = data.get("ghost_runs_enabled", true)
		settings = data.get("settings", {
			"master_volume": 1.0, "sfx_volume": 1.0, "bgm_volume": 0.7,
			"screen_shake": true, "hit_stop": true, "show_damage_numbers": true,
			"auto_aim": false, "text_speed": 1.0,
		})
		print("Save loaded — HP %d/%d, weapon: %s, skills: %s" % [saved_health, saved_max_health, equipped_weapon, str(equipped_skills)])

func apply_settings():
	AudioManager.set_master_volume(settings.master_volume)
	AudioManager.set_sfx_volume(settings.sfx_volume)
	AudioManager.set_bgm_volume(settings.bgm_volume)

func complete_current_chapter():
	var chapter_id := "act%02d_ch%03d" % [current_act, current_chapter]
	if not completed_chapters.has(chapter_id):
		completed_chapters.append(chapter_id)
	
	# Calculate stars based on performance
	var elapsed := (Time.get_ticks_msec() / 1000.0) - chapter_start_time
	var stars := calculate_stars(chapter_id, chapter_deaths, elapsed)
	print("Chapter %s complete — %d stars (deaths: %d, time: %.1fs)" % [chapter_id, stars, chapter_deaths, elapsed])
	
	var next_chapter_id: String = ChapterDatabase.get_current_chapter().get("next_chapter", "")
	if next_chapter_id != "" and ChapterDatabase.chapters.has(next_chapter_id):
		ChapterDatabase.chapters[next_chapter_id]["is_unlocked"] = true
	
	var rewards = ChapterDatabase.get_current_chapter().get("rewards", {})
	player_xp += rewards.get("xp", 0)
	player_gold += rewards.get("gold", 0)
	inventory["gold"] = player_gold
	
	if rewards.has("unlock_weapon"):
		var w = rewards.unlock_weapon
		if w not in unlocked_weapons:
			unlocked_weapons.append(w)
		_auto_equip_best_weapon()
	if rewards.has("unlock_skill"):
		var s = rewards.unlock_skill
		if s not in unlocked_skills:
			unlocked_skills.append(s)
		if equipped_skills.size() < 3:
			equipped_skills.append(s)
	
	saved_health = mini(saved_health + 25, saved_max_health)
	
	# Check chapter-based achievements
	check_chapter_achievements(chapter_deaths, stars)
	
	save_game()

func calculate_stars(chapter_id: String, deaths: int, elapsed_time: float) -> int:
	# ⭐ = complete (always at least 1)
	# ⭐⭐ = no deaths
	# ⭐⭐⭐ = no deaths + under par time
	var stars := 1
	if deaths == 0:
		stars = 2
	# Par time per chapter (seconds) — generous targets
	var par_times := {
		"act01_ch001": 60, "act01_ch002": 75, "act01_ch003": 90, "act01_ch004": 120,
		"act02_ch005": 75, "act02_ch006": 90, "act02_ch007": 90, "act02_ch008": 120,
		"act02_ch009": 120, "act02_ch010": 150,
	}
	var par_time: float = par_times.get(chapter_id, 120.0)
	if deaths == 0 and elapsed_time <= par_time:
		stars = 3
	# Only upgrade, never downgrade
	if chapter_stars.get(chapter_id, 0) < stars:
		chapter_stars[chapter_id] = stars
	return stars

func get_stars(chapter_id: String) -> int:
	return chapter_stars.get(chapter_id, 0)

func get_total_stars() -> int:
	var total := 0
	for stars in chapter_stars.values():
		total += stars
	return total

func get_max_possible_stars() -> int:
	return ChapterDatabase.chapters.size() * 3

func get_level_xp_requirement(level: int) -> int:
	return level * level * 100

func add_xp(amount: int):
	player_xp += amount
	var required := get_level_xp_requirement(player_level)
	while player_xp >= required:
		player_xp -= required
		player_level += 1
		saved_max_health += 10
		saved_health = saved_max_health
		print("LEVEL UP! Now level %d — HP %d" % [player_level, saved_max_health])

func is_chapter_unlocked(act: int, chapter: int) -> bool:
	var id := "act%02d_ch%03d" % [act, chapter]
	if ChapterDatabase.chapters.has(id):
		return ChapterDatabase.chapters[id].get("is_unlocked", false)
	return false

func reset_chapter_state():
	chapter_kills = 0
	chapter_objectives_met.clear()
	poison_timer = 0
	poison_damage = 0
	damage_buff_mult = 1.0
	damage_buff_timer = 0.0
	chapter_start_time = Time.get_ticks_msec() / 1000.0
	chapter_deaths = 0
	chapter_loot.clear()

func _save_indexeddb():
	if OS.has_feature("web") and OS.has_feature("wasm"):
		JavaScriptBridge.eval("""
			if (typeof Module !== 'undefined' && Module.FS && Module.FS.syncfs) {
				Module.FS.syncfs(false, function(err) {
					if (err) console.error('Save sync error:', err);
				});
			}
		""")

func add_potion(count: int = 1):
	inventory["potions"] += count
	print("Potions: %d" % inventory["potions"])

func use_potion() -> bool:
	if inventory["potions"] <= 0:
		return false
	inventory["potions"] -= 1
	saved_health = mini(saved_health + 30, saved_max_health)
	print("Used potion! HP: %d/%d (%d left)" % [saved_health, saved_max_health, inventory["potions"]])
	return true

func _auto_equip_best_weapon():
	var best_weapon := "broken_sword"
	var best_dmg: int = 0
	for weapon_id in unlocked_weapons:
		if weapon_id in WEAPON_STATS:
			var dmg: int = WEAPON_STATS[weapon_id].get("damage", 0)
			if dmg > best_dmg:
				best_dmg = dmg
				best_weapon = weapon_id
	if best_weapon != equipped_weapon:
		equipped_weapon = best_weapon
		print("Auto-equipped: %s (DMG %d, CD %.2fs)" % [equipped_weapon, WEAPON_STATS[equipped_weapon].damage, WEAPON_STATS[equipped_weapon].cooldown])

func get_weapon_stats(weapon_id: String = equipped_weapon) -> Dictionary:
	if weapon_id in WEAPON_STATS:
		return WEAPON_STATS[weapon_id]
	return WEAPON_STATS["broken_sword"]

func get_skill_stats(skill_id: String) -> Dictionary:
	if skill_id in SKILL_STATS:
		return SKILL_STATS[skill_id]
	return {}

func equip_weapon(weapon_id: String) -> bool:
	if weapon_id in unlocked_weapons:
		equipped_weapon = weapon_id
		save_game()
		return true
	return false

func equip_skill(skill_id: String, slot: int) -> bool:
	if skill_id not in unlocked_skills:
		return false
	while equipped_skills.size() <= slot:
		equipped_skills.append("")
	equipped_skills[slot] = skill_id
	save_game()
	return true

class ChapterProgress:
	var chapter_id: String
	var best_time: float
	var stars: int = 0
	var completed: bool = false

# ─── Loot Drop System ───────────────────────────────────
# Variable ratio reinforcement: enemies drop loot on death
# Boss/champion kills = guaranteed drop + rare chance
# Trash mob kills = 5% uncommon drop chance

func roll_loot_drop(enemy_type: String, is_boss: bool = false) -> Dictionary:
	"""Roll for a loot drop when an enemy dies. Returns {} if no drop."""
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	
	# Drop chance: trash 15%, boss/champion 100%
	var drop_chance := 1.0 if is_boss else 0.15
	if rng.randf() > drop_chance:
		return {}
	
	# Roll rarity: weighted random from RARITY
	var rarity := _roll_rarity(is_boss)
	
	# Pick a weapon of that rarity (or nearest lower)
	var weapon_id := _pick_weapon_by_rarity(rarity)
	if weapon_id.is_empty():
		return {}
	
	var loot := {
		"weapon_id": weapon_id,
		"rarity": rarity,
		"gold_value": _gold_value_for_rarity(rarity),
	}
	
	# Track in chapter loot
	chapter_loot.append(loot)
	
	# If weapon not yet owned, unlock it
	if weapon_id not in unlocked_weapons:
		unlocked_weapons.append(weapon_id)
		_auto_equip_best_weapon()
		loot["is_new"] = true
	else:
		loot["is_new"] = false
	
	# Update collection tracking
	if not collected_weapons.has(weapon_id):
		collected_weapons[weapon_id] = {"count": 0, "best_rarity": rarity}
	collected_weapons[weapon_id]["count"] += 1
	var rarity_order := ["common", "uncommon", "rare", "legendary"]
	var current_rank := rarity_order.find(collected_weapons[weapon_id]["best_rarity"])
	var new_rank := rarity_order.find(rarity)
	if new_rank > current_rank:
		collected_weapons[weapon_id]["best_rarity"] = rarity
	
	# Add gold value
	player_gold += loot.gold_value
	inventory["gold"] = player_gold
	
	print("LOOT DROP: %s [%s] (gold: %d)%s" % [weapon_id, rarity, loot.gold_value, " NEW!" if loot.get("is_new") else " dup"])
	
	# Check loot achievements
	check_loot_achievements(rarity)
	
	save_game()
	return loot

func _roll_rarity(is_boss: bool) -> String:
	"""Weighted random rarity roll. Bosses get +15% to rare/legendary."""
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	
	var weights := {}
	for r in RARITY.keys():
		weights[r] = RARITY[r].weight
	
	# Boss bonus: shift weight from common up to rare/legendary
	if is_boss:
		weights["common"] = max(10, weights["common"] - 30)
		weights["uncommon"] += 10
		weights["rare"] += 12
		weights["legendary"] += 8
	
	var total := 0.0
	for w in weights.values():
		total += w
	
	var roll := rng.randf() * total
	var cumulative := 0.0
	for r in ["legendary", "rare", "uncommon", "common"]:
		cumulative += weights[r]
		if roll <= cumulative:
			return r
	return "common"

func _pick_weapon_by_rarity(rarity: String) -> String:
	"""Pick a weapon matching the rolled rarity. Falls back to lower rarity."""
	var rarity_order := ["legendary", "rare", "uncommon", "common"]
	var target_idx := rarity_order.find(rarity)
	
	# Try exact rarity first, then fall back to lower
	for i in range(target_idx, rarity_order.size()):
		var r := rarity_order[i]
		var candidates: Array = []
		for wid in WEAPON_STATS.keys():
			if WEAPON_STATS[wid].get("rarity", "common") == r:
				candidates.append(wid)
		if not candidates.is_empty():
			candidates.sort()
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			return candidates[rng.randi() % candidates.size()]
	return ""

func _gold_value_for_rarity(rarity: String) -> int:
	match rarity:
		"common":    return 5
		"uncommon":  return 15
		"rare":      return 40
		"legendary": return 100
		_:           return 5

func get_loot_summary() -> Dictionary:
	"""Get summary of chapter loot for victory screen."""
	var by_rarity := {}
	for loot in chapter_loot:
		var r: String = loot.get("rarity", "common")
		if not by_rarity.has(r):
			by_rarity[r] = {"count": 0, "items": [], "gold": 0}
		by_rarity[r].count += 1
		by_rarity[r].items.append(loot.weapon_id)
		by_rarity[r].gold += loot.get("gold_value", 0)
	return {
		"total_drops": chapter_loot.size(),
		"total_gold": chapter_loot.reduce(func(acc, l): return acc + l.get("gold_value", 0), 0),
		"new_weapons": chapter_loot.filter(func(l): return l.get("is_new", false)).size(),
		"by_rarity": by_rarity,
	}

func get_collection_progress() -> Dictionary:
	"""Get weapon collection stats for UI."""
	var total_weapons := WEAPON_STATS.size()
	var collected := collected_weapons.size()
	return {
		"total": total_weapons,
		"collected": collected,
		"percentage": (collected * 100.0 / total_weapons) if total_weapons > 0 else 0.0,
	}

# ─── Bestiary ─────────────────────────────────────────────────────────────────

func record_kill(enemy_type: String) -> void:
	"""Record a kill in the bestiary. Call from enemy death handlers."""
	if not BESTIARY.has(enemy_type):
		print("BESTIARY: Unknown enemy type '%s'" % enemy_type)
		return
	
	if not bestiary.has(enemy_type):
		bestiary[enemy_type] = {"kills": 0, "lore_unlocked": []}
	
	bestiary[enemy_type]["kills"] += 1
	chapter_kills += 1
	
	# Check for lore unlock milestones
	var entry: Dictionary = BESTIARY[enemy_type]
	var lore_milestones: Array = entry.get("lore", {}).keys()
	lore_milestones.sort()
	
	for milestone in lore_milestones:
		if bestiary[enemy_type]["kills"] >= milestone and milestone not in bestiary[enemy_type]["lore_unlocked"]:
			bestiary[enemy_type]["lore_unlocked"].append(milestone)
			print("BESTIARY LORE UNLOCK: %s at %d kills — %s" % [
				entry.name, milestone, entry.lore[milestone].left(60) + "..."
			])
	
	# Check kill-based achievements
	check_achievements()
	save_game()

func get_bestiary_entry(enemy_type: String) -> Dictionary:
	"""Get bestiary entry for an enemy type, including kill count and unlocked lore."""
	var entry: Dictionary = BESTIARY.get(enemy_type, {}).duplicate()
	var kills: int = bestiary.get(enemy_type, {}).get("kills", 0)
	var unlocked: Array = bestiary.get(enemy_type, {}).get("lore_unlocked", [])
	entry["kill_count"] = kills
	entry["lore_unlocked"] = unlocked
	entry["discovered"] = kills > 0
	return entry

func get_bestiary_progress() -> Dictionary:
	"""Get overall bestiary completion stats."""
	var total_types := BESTIARY.size()
	var discovered := 0
	var total_kills := 0
	var lore_unlocked_count := 0
	var total_lore := 0
	
	for enemy_type in BESTIARY:
		var kills: int = bestiary.get(enemy_type, {}).get("kills", 0)
		if kills > 0:
			discovered += 1
		total_kills += kills
		var lore: Dictionary = BESTIARY[enemy_type].get("lore", {})
		total_lore += lore.size()
		var unlocked: Array = bestiary.get(enemy_type, {}).get("lore_unlocked", [])
		lore_unlocked_count += unlocked.size()
	
	return {
		"total_types": total_types,
		"discovered": discovered,
		"percentage": (discovered * 100.0 / total_types) if total_types > 0 else 0.0,
		"total_kills": total_kills,
		"lore_unlocked": lore_unlocked_count,
		"total_lore": total_lore,
	}

# ─── Achievement System ─────────────────────────────────────────────────────

func unlock_achievement(achievement_id: String) -> bool:
	"""Try to unlock an achievement. Returns true if newly unlocked, false if already had it."""
	if not ACHIEVEMENTS.has(achievement_id):
		push_warning("ACHIEVEMENT: Unknown id '%s'" % achievement_id)
		return false
	if achievements_unlocked.has(achievement_id):
		return false  # Already unlocked
	
	achievements_unlocked[achievement_id] = Time.get_unix_time_from_system()
	var data: Dictionary = ACHIEVEMENTS[achievement_id]
	print("🏆 ACHIEVEMENT UNLOCKED: %s %s — %s" % [data.icon, data.name, data.description])
	achievement_unlocked.emit(achievement_id, data)
	save_game()
	return true

func is_achievement_unlocked(achievement_id: String) -> bool:
	return achievements_unlocked.has(achievement_id)

func check_achievements() -> void:
	"""Check all achievement conditions and unlock any that are met. Call at key moments."""
	var total_kills := 0
	for enemy_type in bestiary:
		total_kills += bestiary[enemy_type].get("kills", 0)
	
	var completed_count := completed_chapters.size()
	var weapons_count := collected_weapons.size()
	var discovered_enemies := 0
	for enemy_type in BESTIARY:
		if bestiary.get(enemy_type, {}).get("kills", 0) > 0:
			discovered_enemies += 1
	
	var three_star_count := 0
	for stars in chapter_stars.values():
		if stars >= 3:
			three_star_count += 1
	
	# Combat
	if total_kills >= 1:
		unlock_achievement("first_blood")
	if total_kills >= 50:
		unlock_achievement("body_count_50")
	if total_kills >= 200:
		unlock_achievement("body_count_200")
	
	# Exploration
	if completed_count >= 1:
		unlock_achievement("first_step")
	if completed_count >= 5:
		unlock_achievement("half_way")
	if current_act >= 2 or completed_count >= 4:
		unlock_achievement("act2_reacher")
	
	# Collection
	if weapons_count >= 3:
		unlock_achievement("armory_3")
	if weapons_count >= WEAPON_STATS.size():
		unlock_achievement("armory_all")
	if discovered_enemies >= 4:
		unlock_achievement("bestiary_half")
	if discovered_enemies >= BESTIARY.size():
		unlock_achievement("bestiary_all")
	
	# Mastery
	if three_star_count >= 1:
		unlock_achievement("speed_demon")
	if three_star_count >= 5:
		unlock_achievement("perfectionist")

func check_chapter_achievements(deaths: int, stars: int) -> void:
	"""Check achievements that depend on chapter performance. Call after chapter completion."""
	if deaths == 0:
		unlock_achievement("flawless_chapter")
	if stars >= 3:
		unlock_achievement("speed_demon")
	
	# Speed Demon: 3-star 5 different chapters
	var three_star_count := 0
	for chapter_id in chapter_stars:
		if chapter_stars[chapter_id] >= 3:
			three_star_count += 1
	if three_star_count >= 5:
		unlock_achievement("speed_demon_5")
	
	# Re-check general achievements too
	check_achievements()

func check_ghost_achievement(chapter_id: String, completion_time: float) -> void:
	"""Check if player beat their ghost. Called after chapter completion if ghost was active."""
	var best_time := GhostRecorder.get_best_time(chapter_id)
	if best_time > 0 and completion_time < best_time:
		unlock_achievement("ghost_hunter")

func check_loot_achievements(rarity: String) -> void:
	"""Check achievements that depend on loot drops. Call after loot roll."""
	if rarity == "legendary":
		unlock_achievement("legendary_find")
	check_achievements()

func get_achievement_progress() -> Dictionary:
	"""Get achievement stats for UI."""
	var total := ACHIEVEMENTS.size()
	var unlocked := achievements_unlocked.size()
	return {
		"total": total,
		"unlocked": unlocked,
		"percentage": (unlocked * 100.0 / total) if total > 0 else 0.0,
	}

func get_achievements_by_category() -> Dictionary:
	"""Get achievements organized by category for the achievement screen."""
	var categories := {}
	for id in ACHIEVEMENTS:
		var data: Dictionary = ACHIEVEMENTS[id]
		var cat: String = data.get("category", "Other")
		if not categories.has(cat):
			categories[cat] = []
		var entry := data.duplicate()
		entry["id"] = id
		entry["unlocked"] = achievements_unlocked.has(id)
		entry["unlock_time"] = achievements_unlocked.get(id, 0.0)
		categories[cat].append(entry)
	return categories

# ─── Daily Login Streak System ──────────────────────────────────────────────

func _check_daily_streak() -> void:
	"""Check and update daily login streak. Call on game startup."""
	var today := Time.get_datetime_string_from_system().split(" ")[0]  # YYYY-MM-DD
	
	if last_login_date.is_empty():
		# First ever login
		daily_streak = 1
		last_login_date = today
		streak_claimed_today = false
		daily_challenge_completed_today = false  # New day = fresh challenge
		print("STREAK: First login! Day 1")
		return
	
	if last_login_date == today:
		# Same day — already logged in today
		print("STREAK: Already logged in today (day %d)" % daily_streak)
		return
	
	# New day — reset daily challenge
	daily_challenge_completed_today = false
	
	# Check if yesterday was the last login (consecutive)
	var yesterday := _get_yesterday_date(last_login_date)
	if today == yesterday or _is_next_day(last_login_date, today):
		# Consecutive day
		daily_streak += 1
		last_login_date = today
		streak_claimed_today = false
		print("STREAK: Consecutive! Day %d" % daily_streak)
	else:
		# Streak broken — missed a day
		daily_streak = 1
		last_login_date = today
		streak_claimed_today = false
		print("STREAK: Broken! Reset to day 1")

func claim_daily_streak() -> Dictionary:
	"""Claim today's streak reward. Returns reward dict or empty if already claimed."""
	if streak_claimed_today:
		return {}
	
	var reward_day := ((daily_streak - 1) % 7) + 1  # Cycle 1-7
	var rewards: Dictionary = STREAK_REWARDS.get(reward_day, STREAK_REWARDS[1]).duplicate()
	
	# Apply rewards
	player_gold += rewards.get("gold", 0)
	inventory["gold"] = player_gold
	add_potion(rewards.get("potions", 0))
	
	streak_claimed_today = true
	print("STREAK CLAIMED: Day %d → %s" % [daily_streak, rewards.get("label", "")])
	streak_claimed.emit(daily_streak, rewards)
	
	# Check streak achievements
	_check_streak_achievements()
	
	save_game()
	return rewards

func get_streak_info() -> Dictionary:
	"""Get streak status for UI display."""
	var reward_day := ((daily_streak - 1) % 7) + 1
	var next_reward: Dictionary = STREAK_REWARDS.get(reward_day, STREAK_REWARDS[1])
	return {
		"streak": daily_streak,
		"reward_day": reward_day,
		"claimed_today": streak_claimed_today,
		"next_reward": next_reward,
		"days_to_cycle": 7 - reward_day,
	}

func _check_streak_achievements() -> void:
	"""Check streak-related achievements."""
	if daily_streak >= 3:
		unlock_achievement("streak_3")
	if daily_streak >= 7:
		unlock_achievement("streak_7")

func _get_yesterday_date(date_str: String) -> String:
	"""Get the date string for the day before the given date."""
	var parts := date_str.split("-")
	var year := int(parts[0])
	var month := int(parts[1])
	var day := int(parts[2])
	
	# Convert to unix timestamp and subtract 86400
	var epoch := Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day, "hour": 12, "minute": 0, "second": 0})
	var yesterday_epoch := epoch - 86400
	var yesterday_dict := Time.get_datetime_dict_from_unix_time(yesterday_epoch)
	return "%04d-%02d-%02d" % [yesterday_dict["year"], yesterday_dict["month"], yesterday_dict["day"]]

func _is_next_day(date1: String, date2: String) -> bool:
	"""Check if date2 is the day after date1."""
	var parts1 := date1.split("-")
	var parts2 := date2.split("-")
	var epoch1 := Time.get_unix_time_from_datetime_dict({
		"year": int(parts1[0]), "month": int(parts1[1]), "day": int(parts1[2]),
		"hour": 12, "minute": 0, "second": 0
	})
	var epoch2 := Time.get_unix_time_from_datetime_dict({
		"year": int(parts2[0]), "month": int(parts2[1]), "day": int(parts2[2]),
		"hour": 12, "minute": 0, "second": 0
	})
	return (epoch2 - epoch1) <= 86400 and epoch2 > epoch1

# ─── Daily Challenge System ───────────────────────────────────────────────────

func get_daily_challenge() -> Dictionary:
	"""Generate today's daily challenge. Deterministic from date seed."""
	var today := Time.get_datetime_string_from_system().split(" ")[0]  # YYYY-MM-DD
	var seed_val := _date_to_seed(today)
	
	# Seeded random for deterministic daily challenge
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	
	# Pick chapter (from unlocked chapters, or any if none unlocked)
	var available_chapters := ChapterDatabase.chapters.keys()
	if available_chapters.is_empty():
		available_chapters = ["act01_ch001"]
	var chapter_idx := rng.randi() % available_chapters.size()
	var chapter_id: String = available_chapters[chapter_idx]
	
	# Pick 2-3 modifiers
	var modifier_keys := DAILY_CHALLENGE_MODIFIERS.keys()
	var num_modifiers := rng.randi_range(2, 3)
	var selected_modifiers := []
	var used_indices := []
	for i in range(num_modifiers):
		var idx := rng.randi() % modifier_keys.size()
		while idx in used_indices:
			idx = rng.randi() % modifier_keys.size()
		used_indices.append(idx)
		selected_modifiers.append(modifier_keys[idx])
	
	# Calculate bonus gold (base 50 + 25 per modifier)
	var bonus_gold := 50 + (25 * num_modifiers)
	
	return {
		"date": today,
		"chapter_id": chapter_id,
		"modifiers": selected_modifiers,
		"bonus_gold": bonus_gold,
		"completed": daily_challenge_completed_today,
	}

func complete_daily_challenge() -> void:
	"""Mark today's daily challenge as completed and award rewards."""
	if daily_challenge_completed_today:
		return
	
	var challenge := get_daily_challenge()
	var bonus_gold: int = challenge.get("bonus_gold", 50)
	
	player_gold += bonus_gold
	daily_challenge_completed_today = true
	daily_challenge_total_completed += 1
	if bonus_gold > daily_challenge_best_gold:
		daily_challenge_best_gold = bonus_gold
	
	print("DAILY CHALLENGE COMPLETE! +%dg bonus" % bonus_gold)
	daily_challenge_completed.emit({"gold": bonus_gold})
	
	# Check achievements
	_check_daily_challenge_achievements()
	save_game()

func _check_daily_challenge_achievements() -> void:
	"""Check daily challenge achievements."""
	if daily_challenge_total_completed >= 1:
		unlock_achievement("daily_challenger")
	if daily_challenge_total_completed >= 7:
		unlock_achievement("daily_veteran")

func _date_to_seed(date_str: String) -> int:
	"""Convert YYYY-MM-DD date to a deterministic integer seed."""
	var parts := date_str.split("-")
	var year := int(parts[0])
	var month := int(parts[1])
	var day := int(parts[2])
	# Simple hash: year*10000 + month*100 + day (deterministic per day)
	return year * 10000 + month * 100 + day

func is_daily_challenge_available() -> bool:
	"""Check if today's daily challenge hasn't been completed yet."""
	return not daily_challenge_completed_today

func reset_daily_challenge_if_new_day() -> void:
	"""Reset daily challenge completion if it's a new day. Called on login."""
	var today := Time.get_datetime_string_from_system().split(" ")[0]
	# If we have a last_login_date and it's different from today, the challenge resets
	# (The streak system already handles last_login_date updates)
	# daily_challenge_completed_today resets naturally since it's date-keyedfunc get_leaderboard_data() -> Array:
	"""Get leaderboard data for all chapters: chapter_id, title, best_time, stars, has_ghost."""
	var result := []
	var sorted_ids := ChapterDatabase.chapters.keys()
	sorted_ids.sort()
	for chapter_id in sorted_ids:
		var ch = ChapterDatabase.chapters[chapter_id]
		if not ch.get("is_unlocked", false):
			continue
		var entry := {
			"chapter_id": chapter_id,
			"title": ch.get("title", chapter_id),
			"best_time": GhostRecorder.get_best_time(chapter_id),
			"stars": get_stars(chapter_id),
			"has_ghost": GhostRecorder.has_ghost(chapter_id),
		}
		result.append(entry)
	return result