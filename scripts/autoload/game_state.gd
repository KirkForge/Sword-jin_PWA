extends Node
# GameState — Persistent save/load + progression tracking
# v0.74 — chapter star ratings, death tracking, par times

const SAVE_FILE := "user://swordjin_save.json"

# Weapon definitions — unlocked weapons auto-equip if better
const WEAPON_STATS := {
	"broken_sword":    {"damage": 8,  "cooldown": 0.40, "description": "A rusted relic. Barely sharp."},
	"steel_dagger":    {"damage": 12, "cooldown": 0.30, "description": "Merchant's gift. Light and lethal."},
	"captains_blade":  {"damage": 15, "cooldown": 0.50, "description": "A commander's weapon. Heavy but ruthless."},
	"spirit_edge":     {"damage": 18, "cooldown": 0.35, "description": "Ghost-forged blade. Cuts ethereal and flesh alike."},
	"crimson_edge":    {"damage": 22, "cooldown": 0.45, "description": "Fang officer's saber. Wickedly fast."},
	"wardens_halberd": {"damage": 28, "cooldown": 0.60, "description": "Gate Warden's polearm. Devastating reach."},
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
