extends Control
## Inventory screen — weapon equip, skill slot assignment, potion count, gold.
## Accessible from pause menu.

@onready var weapon_label = $VBoxContainer/WeaponSection/WeaponLabel
@onready var weapon_list = $VBoxContainer/WeaponSection/WeaponList
@onready var skill_label = $VBoxContainer/SkillSection/SkillLabel
@onready var skill_list = $VBoxContainer/SkillSection/SkillList
@onready var potion_label = $VBoxContainer/StatsSection/PotionLabel
@onready var gold_label = $VBoxContainer/StatsSection/GoldLabel
@onready var close_btn = $CloseButton

func _ready():
	_refresh()
	close_btn.pressed.connect(_on_close)

func _refresh():
	# Weapons
	weapon_label.text = "Equipped: %s" % GameState.equipped_weapon
	
	for child in weapon_list.get_children():
		child.queue_free()
	
	for weapon_id in GameState.unlocked_weapons:
		var stats = GameState.WEAPON_STATS.get(weapon_id, {})
		var btn = Button.new()
		var icon_path: String = stats.get("icon", "")
		if icon_path != "" and ResourceLoader.exists(icon_path):
			btn.icon = load(icon_path)
		btn.text = "%s — DMG %d, CD %.2fs%s" % [
			weapon_id.replace("_", " ").capitalize(),
			stats.get("damage", 0),
			stats.get("cooldown", 0),
			" ⚔" if weapon_id == GameState.equipped_weapon else ""
		]
		btn.pressed.connect(_on_weapon_selected.bind(weapon_id))
		weapon_list.add_child(btn)
	
	# Skills
	skill_label.text = "Skills: %s" % str(GameState.equipped_skills)
	
	for child in skill_list.get_children():
		child.queue_free()
	
	var slot_map = {}
	for i in range(GameState.equipped_skills.size()):
		slot_map[GameState.equipped_skills[i]] = i
	
	for skill_id in GameState.unlocked_skills:
		var stats = GameState.SKILL_STATS.get(skill_id, {})
		var slot = slot_map.get(skill_id, -1)
		var slot_str = " [Slot %d]" % (slot + 1) if slot >= 0 else ""
		var btn = Button.new()
		btn.text = "%s — %s%s" % [
			skill_id.replace("_", " ").capitalize(),
			stats.get("description", ""),
			slot_str,
		]
		btn.pressed.connect(_on_skill_selected.bind(skill_id))
		skill_list.add_child(btn)
	
	# Stats
	potion_label.text = "Potions: %d" % GameState.inventory.get("potions", 0)
	gold_label.text = "Gold: %d" % GameState.inventory.get("gold", 0)

func _on_weapon_selected(weapon_id: String):
	if GameState.equipped_weapon != weapon_id:
		GameState.equip_weapon(weapon_id)
		AudioManager.play_sfx("ui_click")
		_refresh()

func _on_skill_selected(skill_id: String):
	# Cycle through available slots (1-3)
	var current_slots = GameState.equipped_skills
	var slot = current_slots.find(skill_id)
	if slot >= 0:
		# Unequip
		current_slots[slot] = ""
	else:
		# Equip in first empty slot
		var assigned = false
		for i in range(3):
			if i >= current_slots.size() or current_slots[i] == "":
				GameState.equip_skill(skill_id, i)
				assigned = true
				break
		if not assigned:
			# Replace slot 1
			GameState.equip_skill(skill_id, 0)
	AudioManager.play_sfx("ui_click")
	_refresh()

func _on_close():
	queue_free()
