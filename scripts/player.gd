extends CharacterBody2D
# Player — Jin the Swordmaster
# v0.86 — cinematic crit system, 3-hit combo, knockback, 11 enemy types

var damage_number_scene = preload("res://scenes/ui/damage_number.tscn")

@export var speed := 200.0
@export var attack_duration := 0.3
var attack_cooldown: float = 0.4
var attack_damage: int = 10
var max_health := 100

# --- Combo System ---
const COMBO_WINDOW := 0.5       # Time window to chain next hit
const COMBO_MAX := 3            # 3-hit combo chain
const COMBO_DAMAGE_MULT := [1.0, 1.2, 1.6]  # Damage multiplier per hit
const COMBO_KNOCKBACK := [80.0, 100.0, 150.0]  # Knockback force per hit
var combo_count := 0            # Current combo hit (0-2)
var combo_window_timer := 0.0  # Timer for chaining next hit
var combo_active := false

# --- Critical Hit System ---
const CRIT_BASE_CHANCE := 0.10       # 10% base crit
const CRIT_COMBO_BONUS := [0.0, 0.05, 0.15]  # Extra crit chance per combo hit
const CRIT_DAMAGE_MULT := 2.0        # 2x damage on crit
var last_hit_was_crit := false       # For other systems to check

# Dodge roll
const DODGE_DURATION := 0.25
const DODGE_COOLDOWN := 1.2
const DODGE_SPEED_MULT := 3.0

# Charged heavy attack
const CHARGE_MAX_TIME := 1.0
const HEAVY_DAMAGE_MULT := 2.5
var is_charging := false
var charge_time := 0.0

# Whirlwind slash
const WHIRLWIND_DURATION := 0.5
const WHIRLWIND_COOLDOWN := 2.0
const WHIRLWIND_RADIUS := 60
var is_whirlwinding := false
var whirlwind_timer := 0.0
var whirlwind_cooldown_timer := 0.0
var _whirlwind_crit_triggered := false

# Shadow step
const SHADOW_STEP_DISTANCE := 150
const SHADOW_STEP_COOLDOWN := 3.0
var shadow_step_cooldown_timer := 0.0

# Battle cry
const BATTLE_CRY_DURATION := 3.0
const BATTLE_CRY_COOLDOWN := 5.0
const BATTLE_CRY_HEAL_PCT := 0.15
var battle_cry_buff_timer := 0.0
var battle_cry_cooldown_timer := 0.0

var health: int
var is_attacking := false
var is_dodging := false
var attack_timer := 0.0
var cooldown_timer := 0.0
var dodge_timer := 0.0
var dodge_cooldown_timer := 0.0
var dodge_enabled := true  # Can be disabled by daily challenge modifier
var is_dead := false

# Poison
var poison_timer := 0.0
var poison_damage := 0
var poison_tick_timer := 0.0

@onready var sprite = $AnimatedSprite2D
@onready var attack_hitbox = $AttackHitbox/CollisionShape2D
@onready var label = $Label
@onready var health_bar = $HealthBar

func _ready():
	add_to_group("player")
	_apply_weapon()
	health = max_health
	attack_hitbox.set_deferred("disabled", true)
	_update_label()
	if health_bar:
		health_bar.update_health(health, max_health)
	sprite.play("idle")

func _apply_weapon():
	var weapon := GameState.get_weapon_stats()
	attack_damage = weapon.get("damage", 10)
	attack_cooldown = weapon.get("cooldown", 0.4)
	max_health = GameState.saved_max_health
	health = GameState.saved_health
	print("Player: %s — DMG %d, CD %.2fs, HP %d/%d" % [GameState.equipped_weapon, attack_damage, attack_cooldown, health, max_health])

func _physics_process(delta):
	if is_dead:
		return
	
	# Poison tick
	if poison_timer > 0:
		poison_tick_timer -= delta
		if poison_tick_timer <= 0:
			health -= poison_damage
			poison_tick_timer = 1.0
			poison_timer -= 1.0
			show_damage_number(poison_damage)
			modulate = Color.GREEN
			await get_tree().create_timer(0.1).timeout
			modulate = Color.WHITE
			_update_label()
			if health <= 0:
				_die()
				return
	
	# Battle cry buff
	if battle_cry_buff_timer > 0:
		battle_cry_buff_timer -= delta
		if battle_cry_buff_timer <= 0:
			GameState.damage_buff_mult = 1.0
	
	# Skill cooldowns
	if whirlwind_cooldown_timer > 0:
		whirlwind_cooldown_timer -= delta
	if shadow_step_cooldown_timer > 0:
		shadow_step_cooldown_timer -= delta
	if battle_cry_cooldown_timer > 0:
		battle_cry_cooldown_timer -= delta
	
	# Timers
	if attack_timer > 0:
		attack_timer -= delta
		if attack_timer <= 0:
			_end_attack()
	
	if cooldown_timer > 0:
		cooldown_timer -= delta
	
	# Combo window timer
	if combo_window_timer > 0:
		combo_window_timer -= delta
		if combo_window_timer <= 0:
			combo_active = false
			combo_count = 0
	
	if dodge_timer > 0:
		dodge_timer -= delta
		if dodge_timer <= 0:
			_end_dodge()
	
	if dodge_cooldown_timer > 0:
		dodge_cooldown_timer -= delta
	
	if whirlwind_timer > 0:
		whirlwind_timer -= delta
		if whirlwind_timer <= 0:
			_end_whirlwind()
	
	if is_dodging or is_whirlwinding:
		move_and_slide()
		return
	
	# Charging
	if is_charging:
		charge_time += delta
		if charge_time >= CHARGE_MAX_TIME:
			_release_heavy_attack()
			return
		velocity = Vector2.ZERO
		modulate = Color(1.0, 1.0 - charge_time / CHARGE_MAX_TIME * 0.5, 1.0 - charge_time / CHARGE_MAX_TIME * 0.5)
		move_and_slide()
		return
	
	# Input
	var input = Vector2.ZERO
	input.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	
	if input.length() > 0:
		input = input.normalized()
		if input.x > 0:
			sprite.scale.x = 1
		elif input.x < 0:
			sprite.scale.x = -1
		if not is_attacking:
			sprite.play("walk")
	else:
		if not is_attacking:
			sprite.play("idle")
	
	# Skill inputs
	if Input.is_action_just_pressed("skill1") and dodge_cooldown_timer <= 0 and not is_attacking and dodge_enabled:
		var skill = GameState.equipped_skills[0] if GameState.equipped_skills.size() > 0 else ""
		match skill:
			"dodge_roll":
				_start_dodge()
			"shadow_step":
				_use_shadow_step()
			_:
				_start_dodge()
		return
	
	# Attack input — tap = light, hold = heavy
	if Input.is_action_just_pressed("attack") and cooldown_timer <= 0 and not is_attacking:
		is_charging = true
		charge_time = 0.0
	
	if Input.is_action_just_released("attack") and is_charging:
		if charge_time >= CHARGE_MAX_TIME:
			_release_heavy_attack()
		else:
			is_charging = false
			_start_attack()
		return
	
	# Movement
	if not is_attacking:
		velocity = input * speed
	else:
		velocity = input * speed * 0.5
	
	move_and_slide()

func take_damage(amount: int):
	if is_dead or is_dodging:
		return
	
	health -= amount
	_update_label()
	show_damage_number(amount)
	
	if amount >= 8:
		ScreenShake.shake(3.0, 0.3)
		HitStop.trigger_heavy()
	elif amount >= 5:
		ScreenShake.shake(1.5, 0.2)
		HitStop.trigger_light()
	
	AudioManager.play_sfx("player_hurt")
	
	modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	if not is_dead:
		modulate = Color.WHITE
	
	if health <= 0:
		_die()

func apply_poison(damage: int, duration: float):
	poison_damage = damage
	poison_timer = duration
	poison_tick_timer = 1.0
	print("Poisoned! %d DMG/sec for %.1fs" % [damage, duration])

func _update_label():
	if label:
		var poison_str = " ☠" if poison_timer > 0 else ""
		var buff_str = " ⚡" if GameState.damage_buff_mult > 1.0 else ""
		var combo_str = ""
		if combo_active and combo_count > 0:
			combo_str = " ×%d" % (combo_count + 1)
		label.text = "JIN HP:%d/%d%s%s%s" % [health, max_health, poison_str, buff_str, combo_str]
	if health_bar:
		health_bar.update_health(health, max_health)
	GameState.saved_health = health
	GameState.saved_max_health = max_health

func heal(amount: int):
	if is_dead:
		return
	health = mini(health + amount, max_health)
	_update_label()
	show_damage_number(amount, true)
	AudioManager.play_sfx("ui_click")
	modulate = Color.GREEN
	await get_tree().create_timer(0.2).timeout
	if not is_dead:
		modulate = Color.WHITE

func merchant_heal(amount: int):
	heal(amount)

func show_damage_number(amount: int, is_heal := false):
	var dn = damage_number_scene.instantiate() as Node2D
	dn.global_position = global_position + Vector2(0, -24)
	get_tree().current_scene.add_child(dn)
	if is_heal:
		dn.setup_heal(amount)
	else:
		dn.setup(amount)

func _die():
	is_dead = true
	GameState.chapter_deaths += 1
	print("Player defeated! (deaths this chapter: %d)" % GameState.chapter_deaths)
	modulate = Color.DARK_BLUE
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	attack_hitbox.set_deferred("disabled", true)
	if label:
		label.text = "DEAD — Press R to restart"
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			get_tree().reload_current_scene()
		if event.keycode == KEY_Q:
			GameState.use_potion()
			heal(30)
		if event.keycode == KEY_2 and GameState.equipped_skills.size() > 1:
			var skill = GameState.equipped_skills[1]
			match skill:
				"whirlwind_slash":
					_use_whirlwind()
				"battle_cry":
					_use_battle_cry()
		if event.keycode == KEY_3 and GameState.equipped_skills.size() > 2:
			var skill = GameState.equipped_skills[2]
			match skill:
				"whirlwind_slash":
					_use_whirlwind()
				"battle_cry":
					_use_battle_cry()

# --- LIGHT ATTACK (with combo) ---
func _start_attack():
	# Advance combo if within window
	if combo_active and combo_window_timer > 0:
		combo_count = (combo_count + 1) % COMBO_MAX
	else:
		combo_count = 0
	
	combo_active = true
	combo_window_timer = COMBO_WINDOW
	
	is_attacking = true
	attack_timer = attack_duration
	# Combo hits have shorter cooldown (faster chaining)
	var cd_reduction = 1.0 - combo_count * 0.15  # 0%, 15%, 30% faster
	cooldown_timer = (attack_duration + attack_cooldown) * cd_reduction
	attack_hitbox.disabled = false
	sprite.play("attack")
	
	# Pitch rises with combo for audio feedback
	var pitch = 0.95 + combo_count * 0.1
	AudioManager.play_random_pitch("sword_swing", pitch, pitch + 0.05)
	
	var facing_right = sprite.scale.x >= 0
	var facing = Vector2.RIGHT if facing_right else Vector2.LEFT
	# Combo hits lunge further
	var lunge_mult = 2.0 + combo_count * 0.5
	velocity = facing * speed * lunge_mult
	modulate = Color.WHITE
	_update_label()

func _end_attack():
	is_attacking = false
	attack_hitbox.disabled = true
	velocity = Vector2.ZERO
	sprite.play("idle")

# --- CHARGED HEAVY ATTACK ---
func _release_heavy_attack():
	is_charging = false
	var charge_ratio = min(charge_time / CHARGE_MAX_TIME, 1.0)
	
	# Full charge guarantees a crit
	if charge_ratio >= 1.0:
		last_hit_was_crit = true
	
	var dmg = int(attack_damage * (1.0 + HEAVY_DAMAGE_MULT * charge_ratio) * GameState.damage_buff_mult)
	
	is_attacking = true
	attack_timer = attack_duration * 1.5
	cooldown_timer = attack_duration * 1.5 + attack_cooldown * 1.5
	attack_hitbox.disabled = false
	sprite.play("attack")
	
	# Store heavy DMG temporarily
	attack_damage = dmg
	await get_tree().create_timer(attack_duration * 1.5).timeout
	_apply_weapon()  # Restore normal damage
	
	AudioManager.play_random_pitch("captain_charge", 0.7, 1.0)
	ScreenShake.shake(5.0 * charge_ratio, 0.4)
	HitStop.trigger_heavy()
	
	var facing_right = sprite.scale.x >= 0
	var facing = Vector2.RIGHT if facing_right else Vector2.LEFT
	velocity = facing * speed * 1.5
	print("HEAVY ATTACK! %.0f%% charged → %d DMG" % [charge_ratio * 100, dmg])

# --- DODGE ROLL ---
func set_dodge_enabled(enabled: bool):
	"""Enable or disable dodge roll (used by daily challenge)."""
	dodge_enabled = enabled

func _start_dodge():
	is_dodging = true
	dodge_timer = DODGE_DURATION
	dodge_cooldown_timer = DODGE_COOLDOWN
	attack_hitbox.set_deferred("disabled", true)
	var facing_dir = Vector2.RIGHT if sprite.scale.x >= 0 else Vector2.LEFT
	velocity = facing_dir * speed * DODGE_SPEED_MULT
	modulate = Color(1, 1, 1, 0.5)
	AudioManager.play_sfx("dodge_roll")

func _end_dodge():
	is_dodging = false
	velocity = velocity * 0.3
	modulate = Color.WHITE

# --- WHIRLWIND SLASH ---
func _use_whirlwind():
	if whirlwind_cooldown_timer > 0:
		return
	is_whirlwinding = true
	whirlwind_timer = WHIRLWIND_DURATION
	whirlwind_cooldown_timer = WHIRLWIND_COOLDOWN
	attack_hitbox.disabled = false
	sprite.play("attack")
	AudioManager.play_random_pitch("sword_swing", 0.8, 1.0)
	_whirlwind_crit_triggered = false
	
	# Hit ALL enemies in radius
	var bodies = get_tree().get_nodes_in_group("enemies")
	for body in bodies:
		if body == self:
			continue
		var dist = global_position.distance_to(body.global_position)
		if dist <= WHIRLWIND_RADIUS:
			var is_crit = randf() < CRIT_BASE_CHANCE
			var dmg = int(attack_damage * GameState.get_skill_stats("whirlwind_slash").get("damage_mult", 1.5) * GameState.damage_buff_mult)
			if is_crit:
				dmg = int(dmg * CRIT_DAMAGE_MULT)
			if body.has_method("take_damage"):
				body.take_damage(dmg)
				HitStop.trigger_light()
			# Whirlwind knockback — push outward from player
			if body.has_method("apply_knockback"):
				var push_dir = (body.global_position - global_position).normalized()
				var kb_force = 120.0
				if is_crit:
					kb_force *= 1.5
				body.apply_knockback(push_dir, kb_force)
			# Cinematic crit on whirlwind (only on first crit target)
			if is_crit and not _whirlwind_crit_triggered:
				_whirlwind_crit_triggered = true
				CritEffect.trigger_crit(body.global_position)
	
	var tween = create_tween()
	tween.tween_property(sprite, "rotation", TAU, WHIRLWIND_DURATION)
	print("WHIRLWIND! Hit enemies within %dpx" % WHIRLWIND_RADIUS)

func _end_whirlwind():
	is_whirlwinding = false
	attack_hitbox.disabled = true
	sprite.rotation = 0
	sprite.play("idle")

# --- SHADOW STEP ---
func _use_shadow_step():
	if shadow_step_cooldown_timer > 0:
		return
	shadow_step_cooldown_timer = SHADOW_STEP_COOLDOWN
	
	# Find nearest enemy behind player
	var best_target = null
	var best_dist = INF
	var facing_dir = Vector2.RIGHT if sprite.scale.x >= 0 else Vector2.LEFT
	var behind_dir = -facing_dir
	
	for body in get_tree().get_nodes_in_group("enemies"):
		if body == self or body.is_dead:
			continue
		var to_body = body.global_position - global_position
		var dist = to_body.length()
		if dist < best_dist and to_body.dot(behind_dir) > 0:
			best_dist = dist
			best_target = body
	
	if best_target:
		# Teleport behind target
		var target_pos = best_target.global_position + behind_dir * 50
		global_position = target_pos
		modulate.a = 0.3
		await get_tree().create_timer(0.1).timeout
		modulate.a = 1.0
		
		# Stab
		var is_shadow_crit = randf() < CRIT_BASE_CHANCE * 2.0  # Shadow step has double crit chance (backstab)
		var stab_dmg = int(GameState.get_skill_stats("shadow_step").get("damage", 10) * GameState.damage_buff_mult)
		if is_shadow_crit:
			stab_dmg = int(stab_dmg * CRIT_DAMAGE_MULT)
		if best_target.has_method("take_damage"):
			best_target.take_damage(stab_dmg)
		AudioManager.play_sfx("sword_hit")
		if is_shadow_crit:
			CritEffect.trigger_crit(best_target.global_position)
		else:
			HitStop.trigger_heavy()
		print("SHADOW STEP! Behind %s → %d DMG%s" % [best_target.name, stab_dmg, " CRIT!" if is_shadow_crit else ""])
	else:
		# No target — dash forward
		var dash_pos = global_position + facing_dir * SHADOW_STEP_DISTANCE
		global_position = dash_pos
		print("SHADOW STEP — dash forward")

# --- BATTLE CRY ---
func _use_battle_cry():
	if battle_cry_cooldown_timer > 0:
		return
	battle_cry_cooldown_timer = BATTLE_CRY_COOLDOWN
	battle_cry_buff_timer = BATTLE_CRY_DURATION
	GameState.damage_buff_mult = 1.3
	
	var heal_amount = int(max_health * BATTLE_CRY_HEAL_PCT)
	heal(heal_amount)
	
	AudioManager.play_sfx("level_complete")
	ScreenShake.shake(2.0, 0.2)
	print("BATTLE CRY! +%.0f%% DMG for %.1fs, healed %d HP" % [30, BATTLE_CRY_DURATION, heal_amount])

func _on_attack_hitbox_body_entered(body):
	if body.has_method("take_damage"):
		# Combo damage multiplier
		var dmg_mult = COMBO_DAMAGE_MULT[combo_count] if combo_active and combo_count < COMBO_DAMAGE_MULT.size() else 1.0
		
		# Critical hit roll — higher chance with combo
		var crit_chance = CRIT_BASE_CHANCE
		if combo_active and combo_count < CRIT_COMBO_BONUS.size():
			crit_chance += CRIT_COMBO_BONUS[combo_count]
		# Full-charge heavy attacks guarantee crit (set in _release_heavy_attack)
		var is_crit = last_hit_was_crit if is_charging == false else last_hit_was_crit
		if not is_crit:
			is_crit = randf() < crit_chance
		last_hit_was_crit = is_crit
		
		var dmg: int
		if is_crit:
			dmg = int(attack_damage * dmg_mult * CRIT_DAMAGE_MULT * GameState.damage_buff_mult)
		else:
			dmg = int(attack_damage * dmg_mult * GameState.damage_buff_mult)
		
		body.take_damage(dmg)
		
		# Knockback — push enemy away from player
		if body.has_method("apply_knockback"):
			var knockback_force = COMBO_KNOCKBACK[combo_count] if combo_active and combo_count < COMBO_KNOCKBACK.size() else 80.0
			var dir = (body.global_position - global_position).normalized()
			# Crits get extra knockback
			if last_hit_was_crit:
				knockback_force *= 1.5
			body.apply_knockback(dir, knockback_force)
		
		if last_hit_was_crit:
			# CINEMATIC CRIT — slow-mo, zoom, sparks, flash
			CritEffect.trigger_crit(body.global_position)
			AudioManager.play_sfx("crit_hit")
			GameState.unlock_achievement("first_crit")
			GameState.record_crit()
			# Spawn golden crit damage number
			var crit_dn = damage_number_scene.instantiate() as Node2D
			crit_dn.global_position = body.global_position + Vector2(0, -24)
			get_tree().current_scene.add_child(crit_dn)
			crit_dn.setup_crit(dmg)
			# Crit counts as combo finisher juice too
			ScreenShake.shake(4.0, 0.2)
		else:
			AudioManager.play_random_pitch("sword_hit", 0.9, 1.1)
			HitStop.trigger_light()
		
		# Combo finisher (3rd hit) — extra juice
		if combo_active and combo_count == COMBO_MAX - 1:
			if not last_hit_was_crit:
				ScreenShake.shake(2.0, 0.15)
				HitStop.trigger_heavy()
			GameState.unlock_achievement("combo_master")
			GameState.unlock_achievement("combo_master")

func get_current_health() -> int:
	return health
