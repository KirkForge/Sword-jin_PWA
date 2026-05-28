extends Node
# GameState — Persistent save/load + progression tracking
# v0.71 — retention systems: rested XP, daily streak, chapter stars, bestiary, achievements
# Roadmap: v0.80+ P2P co-op (4 players, ENetMultiplayerPeer, host/join by IP)

const SAVE_FILE := "user://swordjin_save.json"
const SAVE_VERSION := "3.0"

# ── Weapon definitions ──
const WEAPON_STATS := {
	"broken_sword":    {"damage": 8,  "cooldown": 0.40, "description": "A rusted relic. Barely sharp."},
	"steel_dagger":    {"damage": 12, "cooldown": 0.30, "description": "Merchant's gift. Light and lethal."},
	"captains_blade":  {"damage": 15, "cooldown": 0.50, "description": "A commander's weapon. Heavy but ruthless."},
	"spirit_edge":     {"damage": 18, "cooldown": 0.35, "description": "Ghost-forged blade. Cuts ethereal and flesh alike."},
	"crimson_edge":    {"damage": 22, "cooldown": 0.45, "description": "Fang officer's saber. Wickedly fast."},
	"wardens_halberd": {"damage": 28, "cooldown": 0.60, "description": "Gate Warden's polearm. Devastating reach."},
	"ghost_forge_blade": {"damage": 32, "cooldown": 0.45, "description": "Forged in spectral fire. Cuts through armor and spirit alike."},
	"shadow_blade": {"damage": 38, "cooldown": 0.40, "description": "The Shadow Lord's own blade. Darkness itself obeys."},
}

# ── Skill definitions ──
const SKILL_STATS := {
	"whirlwind_slash": {"damage_mult": 1.5, "cooldown": 2.0, "radius": 60, "description": "Spin attack hitting all nearby enemies."},
	"shadow_step":     {"distance": 150, "cooldown": 3.0, "damage": 10, "description": "Teleport behind target + stab."},
	"battle_cry":      {"heal_pct": 0.15, "cooldown": 5.0, "buff_duration": 3.0, "description": "War cry: heals 15% HP + damage buff."},
	"dodge_roll":      {"cooldown": 1.2, "description": "Dash in facing direction with i-frames."},
}

# ── Loot rarity tiers (Variable Ratio Reinforcement) ──
# Each tier: color, weight (lower = rarer), gold_min, gold_max
const LOOT_TIERS := {
	"common":    {"color": "#ffffff", "weight": 60, "gold": [2, 5]},
	"uncommon":  {"color": "#1eff00", "weight": 25, "gold": [5, 15]},
	"rare":      {"color": "#0070dd", "weight": 10, "gold": [15, 40]},
	"legendary": {"color": "#ff8000", "weight": 5,  "gold": [40, 100]},
}

# ── Bestiary definitions (enemy type → lore unlocks at kill milestones) ──
const BESTIARY_LORE := {
	"skeleton":          {10: "The risen dead shamble without purpose.", 50: "Once soldiers of a forgotten kingdom.", 100: "Their bones carry the echo of a war drum."},
	"skeleton_archer":   {10: "Even in death, their aim is true.", 50: "They guard the fortress walls endlessly.", 100: "Their arrows are tipped with rusted iron."},
	"skeleton_captain":  {10: "A captain who leads from beyond the grave.", 50: "The Crimson Fang resurrected him.", 100: "His sword arm never tires."},
	"ghost":             {10: "A wisp of a soul, trapped between worlds.", 50: "They weep for what they've lost.", 100: "Some say they're the spirits of the innocent."},
	"bandit":            {10: "Desperate men with desperate measures.", 50: "The roads made them this way.", 100: "Every bandit was once someone's neighbor."},
	"assassin":          {10: "Silent. Fast. Lethal.", 50: "Trained by the Crimson Fang.", 100: "They never miss twice."},
	"golem":             {10: "Ancient stone given purpose.", 50: "Built to guard what should stay buried.", 100: "Their core hums with old magic."},
	"dark_mage":         {10: "A scholar who sought power beyond death.", 50: "Their spells corrupt the very air.", 100: "They traded their soul for knowledge."},
	"wolf":              {10: "A wild predator of the mountain passes.", 50: "Wolves hunt in packs; this one is a scout.", 100: "The mountain remembers their howl."},
	"shadow_lord":       {10: "The Lord of Shadows stirs.", 50: "He was once a man.", 100: "The final truth: he chose this."},
}

# ── Achievement definitions ──
const ACHIEVEMENTS := {
	"first_blood":      {"name": "First Blood",       "desc": "Defeat your first enemy",           "icon": "⚔️"},
	"blade_master":     {"name": "Blade Master",       "desc": "Collect all weapons",              "icon": "🗡️"},
	"shadow_dancer":    {"name": "Shadow Dancer",      "desc": "Dodge 50 attacks",                 "icon": "💨"},
	"speed_demon":      {"name": "Speed Demon",        "desc": "Complete a chapter in under 60s",  "icon": "⚡"},
	"pacifist":         {"name": "Pacifist",           "desc": "Complete a chapter without attacking", "icon": "🕊️"},
	"collector":        {"name": "Collector",          "desc": "Unlock 5 bestiary entries",         "icon": "📖"},
	"no_damage":        {"name": "Untouchable",        "desc": "Complete a chapter without taking damage", "icon": "🛡️"},
	"streak_7":         {"name": "Devoted",            "desc": "7-day login streak",               "icon": "🔥"},
	"streak_30":        {"name": "Unbreakable",        "desc": "30-day login streak",              "icon": "💎"},
	"act1_complete":    {"name": "Act 1 Complete",     "desc": "Complete Act 1",                    "icon": "🏛️"},
	"act2_complete":    {"name": "Act 2 Complete",     "desc": "Complete Act 2",                    "icon": "🌑"},
	"act3_complete":    {"name": "Act 3 Complete",     "desc": "Complete Act 3",                    "icon": "⚔️"},
	"act4_complete":    {"name": "Act 4 Complete",     "desc": "Complete Act 4 — Reclaim the city", "icon": "👑"},
	"level_10":         {"name": "Veteran",            "desc": "Reach level 10",                   "icon": "⭐"},
	"level_25":         {"name": "Legend",             "desc": "Reach level 25",                   "icon": "🌟"},
	"gold_hoarder":     {"name": "Gold Hoarder",       "desc": "Accumulate 500 gold",              "icon": "💰"},
	"bestiary_master":  {"name": "Bestiary Master",     "desc": "Reach 100 kills on 3 enemy types", "icon": "🐉"},
	"daily_warrior":    {"name": "Daily Warrior",        "desc": "Complete a daily challenge",       "icon": "📅"},
}

# ── Rested XP constants ──
const RESTED_XP_RATE := 2.0          # 2x XP while rested
const RESTED_XP_MAX_HOURS := 8.0     # Full rested bonus after 8 hours
const RESTED_XP_CHAPTERS := 3       # Bonus lasts for 3 chapters
const RESTED_XP_PER_HOUR := 50      # XP stored per hour away (caps at MAX_HOURS worth)

# ── Daily streak constants ──
const STREAK_GOLD_BASE := 10
const STREAK_GOLD_INCREMENT := 5
const STREAK_POTION_DAY := 3        # Free potion every 3 days
const STREAK_MAX_DAYS := 30

# ── Inventory ──
var inventory: Dictionary = {
	"potions": 0,
	"keys": {},
	"artifacts": [],
	"gold": 0,
}

# ── Player Progress ──
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

# ── Settings ──
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

# ── Gate Key mechanic (Ch004) ──
var has_gate_key := false

# ── Chapter State (runtime only) ──
var chapter_kills: int = 0
var chapter_objectives_met: Dictionary = {}
var is_paused: bool = false
var chapter_start_time: float = 0.0     # for speed star
var chapter_damage_taken: int = 0        # for no-damage star

# ── Health persistence ──
var saved_health: int = 100
var saved_max_health: int = 100

# ── Poison state ──
var poison_timer: float = 0.0
var poison_damage: int = 0
var poison_tick_rate: float = 1.0

# ── Battle cry buff ──
var damage_buff_mult: float = 1.0
var damage_buff_timer: float = 0.0

# ── RETENTION: Chapter Stars ──
# chapter_id → {"time": best_time, "damage_taken": best, "kills": best, "stars": earned}
var chapter_stars: Dictionary = {}

# ── RETENTION: Bestiary ──
# enemy_type → kill_count
var bestiary: Dictionary = {}

# ── RETENTION: Achievements ──
var unlocked_achievements: Array = []

# ── RETENTION: Daily Streak ──
var daily_streak: int = 0
var last_login_date: String = ""       # "YYYY-MM-DD"
var streak_rewards_claimed: Array = []  # days already claimed

# ── RETENTION: Rested XP ──
var rested_xp_pool: int = 0            # accumulated rested XP available
var rested_chapters_remaining: int = 0  # chapters left with 2x bonus
var last_logout_time: int = 0          # unix timestamp

# ── RETENTION: Daily Challenge ──
var daily_challenge_date: String = ""   # "YYYY-MM-DD" of current challenge
var daily_challenge_completed: bool = false
var daily_challenge_best_time: float = 0.0  # best completion time in seconds
var daily_challenge_stars: int = 0
var daily_modifiers: Dictionary = {}  # Active daily challenge modifiers

func _ready():
	load_game()
	_process_daily_streak()
	_process_rested_xp()
	print("GameState loaded — Act %d, Ch %d, Level %d, Weapon: %s, Skills: %s" % [current_act, current_chapter, player_level, equipped_weapon, str(equipped_skills)])
	if rested_chapters_remaining > 0:
		print("🔥 RESTED XP ACTIVE — 2x bonus for %d more chapters!" % rested_chapters_remaining)
	if daily_streak > 0:
		print("📅 Daily streak: %d days" % daily_streak)

signal achievement_unlocked(ach_id: String)

# ── SAVE / LOAD ──

func save_game():
	var data := {
		"version": SAVE_VERSION,
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
		# v3.0 retention data
		"chapter_stars": chapter_stars,
		"bestiary": bestiary,
		"unlocked_achievements": unlocked_achievements,
		"daily_streak": daily_streak,
		"last_login_date": last_login_date,
		"streak_rewards_claimed": streak_rewards_claimed,
		"rested_xp_pool": rested_xp_pool,
		"rested_chapters_remaining": rested_chapters_remaining,
		"last_logout_time": last_logout_time,
		"daily_challenge_date": daily_challenge_date,
		"daily_challenge_completed": daily_challenge_completed,
		"daily_challenge_best_time": daily_challenge_best_time,
		"daily_challenge_stars": daily_challenge_stars,
	}
	
	var file := FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print("Game saved (v%s)" % SAVE_VERSION)
	else:
		push_error("Failed to save game")

func load_game():
	if not FileAccess.file_exists(SAVE_FILE):
		print("No save file — starting fresh")
		_init_new_game()
		return
	
	var file := FileAccess.open(SAVE_FILE, FileAccess.READ)
	if file == null:
		push_error("Cannot read save file")
		_init_new_game()
		return
	
	var text := file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("Save file corrupt — starting fresh")
		_init_new_game()
		return
	
	var data = json.data
	if data is Dictionary:
		# v2.0 fields (always present)
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
		settings = data.get("settings", {
			"master_volume": 1.0, "sfx_volume": 1.0, "bgm_volume": 0.7,
			"screen_shake": true, "hit_stop": true, "show_damage_numbers": true,
			"auto_aim": false, "text_speed": 1.0,
		})
		# v3.0 retention fields (graceful migration from old saves)
		chapter_stars = data.get("chapter_stars", {})
		bestiary = data.get("bestiary", {})
		unlocked_achievements = data.get("unlocked_achievements", [])
		daily_streak = data.get("daily_streak", 0)
		last_login_date = data.get("last_login_date", "")
		streak_rewards_claimed = data.get("streak_rewards_claimed", [])
		rested_xp_pool = data.get("rested_xp_pool", 0)
		rested_chapters_remaining = data.get("rested_chapters_remaining", 0)
		last_logout_time = data.get("last_logout_time", 0)
		daily_challenge_date = data.get("daily_challenge_date", "")
		daily_challenge_completed = data.get("daily_challenge_completed", false)
		daily_challenge_best_time = data.get("daily_challenge_best_time", 0.0)
		daily_challenge_stars = data.get("daily_challenge_stars", 0)
		
		print("Save loaded — HP %d/%d, weapon: %s, stars: %d, bestiary: %d" % [
			saved_health, saved_max_health, equipped_weapon,
			chapter_stars.size(), bestiary.size()])

func _init_new_game():
	"""First-time player setup"""
	current_act = 1
	current_chapter = 1
	player_gold = 0
	unlocked_weapons = ["broken_sword"]
	unlocked_skills = ["dodge_roll"]
	equipped_weapon = "broken_sword"
	equipped_skills = ["dodge_roll"]
	chapter_stars = {}
	bestiary = {}
	unlocked_achievements = []
	daily_streak = 1
	last_login_date = _today_string()
	streak_rewards_claimed = []
	rested_xp_pool = 0
	rested_chapters_remaining = 0
	last_logout_time = 0
	daily_challenge_date = ""
	daily_challenge_completed = false
	daily_challenge_best_time = 0.0
	daily_challenge_stars = 0
	save_game()

func _save_indexeddb():
	if OS.has_feature("web") and OS.has_feature("wasm"):
		JavaScriptBridge.eval("""
			if (typeof Module !== 'undefined' && Module.FS && Module.FS.syncfs) {
				Module.FS.syncfs(false, function(err) {
					if (err) console.error('Save sync error:', err);
				});
			}
		""")

# ── RETENTION: Daily Streak ──

func _today_string() -> String:
	return Time.get_datetime_string_from_system().substr(0, 10)  # "YYYY-MM-DD"

func _process_daily_streak():
	var today = _today_string()
	if last_login_date == "":
		# First ever login
		daily_streak = 1
		last_login_date = today
		_claim_streak_reward(1)
		save_game()
	elif last_login_date == today:
		# Already logged in today, just ensure streak is intact
		pass
	else:
		var last = Time.get_unix_time_from_datetime_string(last_login_date + "T00:00:00")
		var now = Time.get_unix_time_from_datetime_string(today + "T00:00:00")
		var days_diff = int((now - last) / 86400)
		if days_diff == 1:
			# Consecutive day
			daily_streak += 1
			if daily_streak > STREAK_MAX_DAYS:
				daily_streak = STREAK_MAX_DAYS
			_claim_streak_reward(daily_streak)
		elif days_diff > 1:
			# Streak broken
			daily_streak = 1
			_claim_streak_reward(1)
		last_login_date = today
		save_game()

func _claim_streak_reward(day: int):
	if day in streak_rewards_claimed:
		return
	streak_rewards_claimed.append(day)
	var gold_reward = STREAK_GOLD_BASE + (day - 1) * STREAK_GOLD_INCREMENT
	player_gold += gold_reward
	inventory["gold"] = player_gold
	if day % STREAK_POTION_DAY == 0:
		inventory["potions"] += 1
	print("📅 Streak day %d! +%d gold%s" % [day, gold_reward, " +1 potion" if day % STREAK_POTION_DAY == 0 else ""])

func get_streak_reward_preview(day: int) -> Dictionary:
	var gold = STREAK_GOLD_BASE + (day - 1) * STREAK_GOLD_INCREMENT
	var potion = 1 if day % STREAK_POTION_DAY == 0 else 0
	return {"gold": gold, "potion": potion}

# ── RETENTION: Rested XP ──

func _process_rested_xp():
	if last_logout_time == 0:
		# First session ever, no rested XP
		last_logout_time = int(Time.get_unix_time_from_system())
		return
	
	var now = int(Time.get_unix_time_from_system())
	var hours_away = (now - last_logout_time) / 3600.0
	
	if hours_away >= 1.0:
		# Accumulate rested XP: RESTED_XP_PER_HOUR per hour, capped at RESTED_XP_MAX_HOURS worth
		var effective_hours = min(hours_away, RESTED_XP_MAX_HOURS)
		var xp_earned = int(effective_hours * RESTED_XP_PER_HOUR)
		rested_xp_pool = mini(rested_xp_pool + xp_earned, int(RESTED_XP_MAX_HOURS * RESTED_XP_PER_HOUR))
		
		if hours_away >= RESTED_XP_MAX_HOURS:
			rested_chapters_remaining = RESTED_XP_CHAPTERS
			print("🔥 Full rested bonus! 2x XP for %d chapters, pool: %d XP" % [rested_chapters_remaining, rested_xp_pool])
		elif hours_away >= 1.0:
			# Partial rest — still grant some bonus chapters
			var partial = max(1, int(RESTED_XP_CHAPTERS * (hours_away / RESTED_XP_MAX_HOURS)))
			rested_chapters_remaining = mini(rested_chapters_remaining + partial, RESTED_XP_CHAPTERS)
	
	# Update logout time for next session
	last_logout_time = now
	save_game()

func get_xp_multiplier() -> float:
	if rested_chapters_remaining > 0 and rested_xp_pool > 0:
		return RESTED_XP_RATE
	return 1.0

func consume_rested_chapter():
	if rested_chapters_remaining > 0:
		rested_chapters_remaining -= 1
		if rested_chapters_remaining <= 0:
			print("Rested XP bonus expired")
		save_game()

# ── RETENTION: Chapter Stars ──

func calculate_stars(chapter_id: String, time_seconds: float, damage_taken: int, kills: int) -> int:
	var stars := 0
	var ch = ChapterDatabase.chapters.get(chapter_id, {})
	var est_time = ch.get("playtime_estimate_minutes", 3) * 60
	
	# Star 1: Complete the chapter (always earned)
	stars += 1
	
	# Star 2: Speed — complete in under 1.5x estimated time
	if time_seconds <= est_time * 1.5:
		stars += 1
	
	# Star 3: No damage taken
	if damage_taken == 0:
		stars += 1
	
	return mini(stars, 3)

func update_chapter_stars(chapter_id: String, time_seconds: float, damage_taken: int, kills: int) -> int:
	var new_stars = calculate_stars(chapter_id, time_seconds, damage_taken, kills)
	var existing = chapter_stars.get(chapter_id, {"stars": 0})
	var prev_stars = existing.get("stars", 0) if existing is Dictionary else 0
	
	if new_stars > prev_stars:
		chapter_stars[chapter_id] = {
			"stars": new_stars,
			"time": time_seconds,
			"damage_taken": damage_taken,
			"kills": kills,
		}
		print("⭐ %s: %d stars (was %d)" % [chapter_id, new_stars, prev_stars])
		_check_achievements()
	else:
		print("⭐ %s: %d stars (no improvement)" % [chapter_id, new_stars])
	
	return new_stars

func get_total_stars() -> int:
	var total := 0
	for ch in chapter_stars.values():
		total += ch.get("stars", 0) if ch is Dictionary else 0
	return total

func get_max_possible_stars() -> int:
	return ChapterDatabase.chapters.size() * 3

# ── RETENTION: Bestiary ──

func record_kill(enemy_type: String):
	if not bestiary.has(enemy_type):
		bestiary[enemy_type] = 0
	bestiary[enemy_type] += 1
	
	var count = bestiary[enemy_type]
	# Check for lore unlocks
	if BESTIARY_LORE.has(enemy_type):
		var lore = BESTIARY_LORE[enemy_type]
		for milestone in lore:
			if count == milestone:
				print("📖 Bestiary: %s — %s" % [enemy_type.capitalize(), lore[milestone]])
	
	# Check bestiary achievements
	if bestiary.size() >= 5:
		unlock_achievement("collector")
	var master_count = 0
	for kills in bestiary.values():
		if kills >= 100:
			master_count += 1
	if master_count >= 3:
		unlock_achievement("bestiary_master")
	
	chapter_kills += 1

func get_bestiary_entry(enemy_type: String) -> Dictionary:
	var count = bestiary.get(enemy_type, 0)
	var lore = BESTIARY_LORE.get(enemy_type, {})
	return {"type": enemy_type, "kills": count, "lore": lore}

func get_bestiary_unlock_count() -> int:
	return bestiary.size()

# ── RETENTION: Achievements ──

func unlock_achievement(id: String) -> bool:
	if unlocked_achievements.has(id):
		return false
	if not ACHIEVEMENTS.has(id):
		return false
	unlocked_achievements.append(id)
	var ach = ACHIEVEMENTS[id]
	print("🏆 Achievement Unlocked: %s %s — %s" % [ach["icon"], ach["name"], ach["desc"]])
	achievement_unlocked.emit(id)
	save_game()
	return true

func _check_achievements():
	# Auto-check conditions
	if unlocked_weapons.size() >= WEAPON_STATS.size():
		unlock_achievement("blade_master")
	if player_level >= 10:
		unlock_achievement("level_10")
	if player_level >= 25:
		unlock_achievement("level_25")
	if player_gold >= 500:
		unlock_achievement("gold_hoarder")
	if daily_streak >= 7:
		unlock_achievement("streak_7")
	if daily_streak >= 30:
		unlock_achievement("streak_30")
	
	# Act completion achievements
	var act1_done = true
	var act2_done = true
	for i in range(1, 5):
		if not completed_chapters.has("act01_ch%03d" % i):
			act1_done = false
	for i in range(5, 11):
		if not completed_chapters.has("act02_ch%03d" % i):
			act2_done = false
	if act1_done:
		unlock_achievement("act1_complete")
	if act2_done:
		unlock_achievement("act2_complete")
	
	# Act 3 completion
	var act3_done = true
	for i in range(11, 16):
		if not completed_chapters.has("act03_ch%03d" % i):
			act3_done = false
	if act3_done:
		unlock_achievement("act3_complete")
	
	# Act 4 completion
	var act4_done = true
	for i in range(16, 21):
		if not completed_chapters.has("act04_ch%03d" % i):
			act4_done = false
	if act4_done:
		unlock_achievement("act4_complete")

# ── LOOT: Variable Ratio Reinforcement ──

func roll_loot(is_boss: bool = false) -> Dictionary:
	var total_weight := 0
	for tier in LOOT_TIERS.values():
		total_weight += tier["weight"]
	
	var roll := randi() % total_weight
	var cumulative := 0
	var selected_tier := "common"
	
	for tier_name in LOOT_TIERS:
		var tier = LOOT_TIERS[tier_name]
		cumulative += tier["weight"]
		if is_boss:
			# Bosses: shift rarity up (remove common, double legendary)
			if tier_name == "common":
				continue
			if tier_name == "legendary":
				cumulative += tier["weight"]  # Double weight for bosses
		if roll < cumulative:
			selected_tier = tier_name
			break
	
	var tier_data = LOOT_TIERS[selected_tier]
	var gold = randi_range(tier_data["gold"][0], tier_data["gold"][1])
	# Bosses drop 3x gold
	if is_boss:
		gold *= 3
	
	player_gold += gold
	inventory["gold"] = player_gold
	
	return {"tier": selected_tier, "color": tier_data["color"], "gold": gold}

# ── XP & LEVELING ──

func complete_current_chapter():
	var chapter_id := "act%02d_ch%03d" % [current_act, current_chapter]
	if not completed_chapters.has(chapter_id):
		completed_chapters.append(chapter_id)
	
	var next_chapter_id: String = ChapterDatabase.get_current_chapter().get("next_chapter", "")
	if next_chapter_id != "" and ChapterDatabase.chapters.has(next_chapter_id):
		ChapterDatabase.chapters[next_chapter_id]["is_unlocked"] = true
	
	var rewards = ChapterDatabase.get_current_chapter().get("rewards", {})
	var xp_gained: int = rewards.get("xp", 0)
	var gold_gained: int = rewards.get("gold", 0)
	
	# Apply rested XP multiplier
	var xp_mult = get_xp_multiplier()
	if xp_mult > 1.0:
		var bonus = int(xp_gained * (xp_mult - 1.0))
		rested_xp_pool = maxi(rested_xp_pool - bonus, 0)
		xp_gained = int(xp_gained * xp_mult)
		consume_rested_chapter()
		print("🔥 Rested XP: %d XP (×%.1f)" % [xp_gained, xp_mult])
	
	player_xp += xp_gained
	player_gold += gold_gained
	inventory["gold"] = player_gold
	
	# Chapter stars
	var time_taken = Time.get_ticks_msec() / 1000.0 - chapter_start_time if chapter_start_time > 0 else 999.0
	update_chapter_stars(chapter_id, time_taken, chapter_damage_taken, chapter_kills)
	
	# Loot roll for every chapter
	var loot = roll_loot(is_boss = false)
	print("Loot: %s (+%d gold)" % [loot["tier"], loot["gold"]])
	
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
	
	# Achievement checks
	if completed_chapters.size() == 1:
		unlock_achievement("first_blood")
	_check_achievements()
	
	_save_indexeddb()
	save_game()

func get_level_xp_requirement(level: int) -> int:
	return level * level * 100

func add_xp(amount: int):
	# Apply rested XP multiplier
	var mult = get_xp_multiplier()
	var actual = int(amount * mult)
	if mult > 1.0:
		var bonus = actual - amount
		rested_xp_pool = maxi(rested_xp_pool - bonus, 0)
		print("🔥 Rested XP bonus: +%d XP" % bonus)
	player_xp += actual
	var required := get_level_xp_requirement(player_level)
	while player_xp >= required:
		player_xp -= required
		player_level += 1
		saved_max_health += 10
		saved_health = saved_max_health
		print("LEVEL UP! Now level %d — HP %d" % [player_level, saved_max_health])
		_check_achievements()
	save_game()

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
	chapter_damage_taken = 0

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

func apply_settings():
	AudioManager.set_master_volume(settings.master_volume)
	AudioManager.set_sfx_volume(settings.sfx_volume)
	AudioManager.set_bgm_volume(settings.bgm_volume)

# ── Daily Challenge ──
# Generates a deterministic daily challenge based on the current date.
# Same challenge for all players on the same day. Resets at midnight.

func get_daily_challenge() -> Dictionary:
	var today = _today_string()
	if daily_challenge_date != today:
		# New day — reset challenge state
		daily_challenge_date = today
		daily_challenge_completed = false
		daily_challenge_best_time = 0.0
		daily_challenge_stars = 0
		save_game()
	
	# Seed from date string for deterministic generation
	var seed_val = hash(today)
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	
	# Pick a random base chapter
	var all_chapters = ChapterDatabase.chapters.keys()
	if all_chapters.is_empty():
		return {}
	var base_id = all_chapters[rng.randi() % all_chapters.size()]
	var base_data = ChapterDatabase.chapters.get(base_id, {})
	if base_data.is_empty():
		return {}
	
	# Generate modifiers based on seed
	var modifiers = _generate_daily_modifiers(rng)
	
	return {
		"challenge_id": "daily_%s" % today.replace("-", ""),
		"base_chapter": base_id,
		"title": "Daily: %s" % base_data.get("title", "Unknown"),
		"objective": base_data.get("objective", "Survive!"),
		"modifiers": modifiers,
		"reward_gold": modifiers.reward_gold,
		"reward_xp": modifiers.reward_xp,
		"completed": daily_challenge_completed,
		"best_time": daily_challenge_best_time,
		"stars": daily_challenge_stars,
	}

func _generate_daily_modifiers(rng: RandomNumberGenerator) -> Dictionary:
	# Pick 1-3 modifiers from the pool
	var all_mods = [
		{"name": "Rush", "desc": "Enemies move 30% faster", "speed_mult": 1.3, "icon": "⚡"},
		{"name": "Iron Hide", "desc": "Enemies take 50% less damage", "damage_mult": 0.5, "icon": "🛡️"},
		{"name": "Swarm", "desc": "2× enemy count", "count_mult": 2.0, "icon": "🐝"},
		{"name": "Glass Cannon", "desc": "Player takes 2× damage", "player_damage_mult": 2.0, "icon": "💀"},
		{"name": "No Potions", "desc": "No health potions drop", "no_potions": true, "icon": "🚫"},
		{"name": "Tight Quarters", "desc": "Smaller arena", "arena_shrink": 0.7, "icon": "📏"},
		{"name": "Vampiric", "desc": "Enemies heal on hit", "enemy_lifesteal": true, "icon": "🧛"},
		{"name": "Heavy Hitters", "desc": "Enemies deal 2× damage", "enemy_damage_mult": 2.0, "icon": "💪"},
	]
	
	var num_mods = rng.randi_range(1, 3)
	var chosen = []
	var indices = range(all_mods.size())
	indices.shuffle()
	# Use seeded shuffle for determinism
	for i in range(min(num_mods, all_mods.size())):
		chosen.append(all_mods[indices[i]])
	
	# Calculate bonus reward based on modifier difficulty
	var difficulty_score = chosen.size()  # more mods = harder = better reward
	var reward_gold = 20 + difficulty_score * 15 + rng.randi_range(0, 10)
	var reward_xp = 50 + difficulty_score * 25 + rng.randi_range(0, 20)
	
	return {
		"mods": chosen,
		"reward_gold": reward_gold,
		"reward_xp": reward_xp,
	}

func complete_daily_challenge(time_seconds: float, damage_taken: int, kills: int) -> void:
	daily_challenge_completed = true
	daily_challenge_best_time = max(daily_challenge_best_time, 0.0)
	if daily_challenge_best_time == 0.0 or time_seconds < daily_challenge_best_time:
		daily_challenge_best_time = time_seconds
	
	# Calculate stars for daily challenge
	var stars = calculate_stars("daily", time_seconds, damage_taken, kills)
	daily_challenge_stars = maxi(daily_challenge_stars, stars)
	
	# Reward gold and XP
	var challenge = get_daily_challenge()
	player_gold += challenge.get("reward_gold", 30)
	player_xp += challenge.get("reward_xp", 75)
	
	# Mark daily challenge achievement progress
	unlock_achievement("first_blood")  # at minimum they killed something
	
	save_game()

func has_daily_challenge_available() -> bool:
	var today = _today_string()
	return daily_challenge_date != today or not daily_challenge_completed

class ChapterProgress:
	var chapter_id: String
	var best_time: float
	var stars: int = 0
	var completed: bool = false
