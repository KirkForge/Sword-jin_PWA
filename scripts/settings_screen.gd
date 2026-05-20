extends Control
## Settings screen — volume, shake, damage numbers, text speed.
## Toggled from pause menu or title screen. Saved to GameState.settings.

@onready var master_slider = $VBoxContainer/MasterVolume/HSlider
@onready var sfx_slider = $VBoxContainer/SFXVolume/HSlider
@onready var bgm_slider = $VBoxContainer/BGMVolume/HSlider
@onready var shake_check = $VBoxContainer/ScreenShake/CheckButton
@onready var hitstop_check = $VBoxContainer/HitStop/CheckButton
@onready var dmg_check = $VBoxContainer/DamageNumbers/CheckButton
@onready var autoaim_check = $VBoxContainer/AutoAim/CheckButton
@onready var text_speed_slider = $VBoxContainer/TextSpeed/HSlider
@onready var close_btn = $CloseButton

func _ready():
	_load_from_settings()
	close_btn.pressed.connect(_on_close)
	
	master_slider.value_changed.connect(_on_master_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	bgm_slider.value_changed.connect(_on_bgm_changed)
	shake_check.toggled.connect(_on_shake_toggled)
	hitstop_check.toggled.connect(_on_hitstop_toggled)
	dmg_check.toggled.connect(_on_dmg_toggled)
	autoaim_check.toggled.connect(_on_autoaim_toggled)
	text_speed_slider.value_changed.connect(_on_text_speed_changed)

func _load_from_settings():
	var s = GameState.settings
	master_slider.value = s.master_volume
	sfx_slider.value = s.sfx_volume
	bgm_slider.value = s.bgm_volume
	shake_check.button_pressed = s.screen_shake
	hitstop_check.button_pressed = s.hit_stop
	dmg_check.button_pressed = s.show_damage_numbers
	autoaim_check.button_pressed = s.auto_aim
	text_speed_slider.value = s.text_speed

func _save_and_apply():
	GameState.save_game()
	GameState.apply_settings()

func _on_master_changed(value: float):
	GameState.settings["master_volume"] = value
	_save_and_apply()

func _on_sfx_changed(value: float):
	GameState.settings["sfx_volume"] = value
	_save_and_apply()

func _on_bgm_changed(value: float):
	GameState.settings["bgm_volume"] = value
	_save_and_apply()

func _on_shake_toggled(on: bool):
	GameState.settings["screen_shake"] = on
	_save_and_apply()

func _on_hitstop_toggled(on: bool):
	GameState.settings["hit_stop"] = on
	_save_and_apply()

func _on_dmg_toggled(on: bool):
	GameState.settings["show_damage_numbers"] = on
	_save_and_apply()

func _on_autoaim_toggled(on: bool):
	GameState.settings["auto_aim"] = on
	_save_and_apply()

func _on_text_speed_changed(value: float):
	GameState.settings["text_speed"] = value
	_save_and_apply()

func _on_close():
	queue_free()
