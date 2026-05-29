extends Node
# GameState — Persistent save/load + progression tracking
# v0.76 — bestiary system with kill counts, lore unlocks, and enemy tracking

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

# Loot tracking
var chapter_loot: Array = []  # Runtime: items dropped this chapter run
var collected_weapons: Dictionary = {}  # weapon_id → {"count": int, "best_rarity": String}

# Chapter performance tracking (runtime, reset per chapter)
var chapter_start_time: float = 0.0
var chapter_deaths: int = 0

func _ready():
	load_game()
	print("GameState loaded — Act %d, Ch %d, Level %d, Weapon: %s, Skills: %s" % [current_act, current_chapter, player_level, equipped_weapon, str(equipped_skills)])

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
