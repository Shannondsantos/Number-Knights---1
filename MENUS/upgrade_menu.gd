extends Control

@onready var gun: TextureRect = get_node_or_null("AssaultGun")
@onready var price_label: Label = $AssaultUpgradeButton/PriceLabel
@onready var upgrade_button: TextureButton = $AssaultUpgradeButton
@onready var prev_btn: TextureButton = $PrevClassButton
@onready var next_btn: TextureButton = $NextClassButton
@onready var class_label: Label = get_node_or_null("ClassNameLabel")
@onready var player_preview: TextureRect = $PlayerClassDisplay/PlayerPreview

@export var assault_textures: Array[Texture2D] = []
@export var heavy_textures: Array[Texture2D] = []
@export var scout_textures: Array[Texture2D] = []

@export var assault_idle: Array[Texture2D] = []
@export var heavy_idle: Array[Texture2D] = []
@export var scout_idle: Array[Texture2D] = []

var _base_gun_scale := Vector2.ONE
var _base_gun_rot := 0.0
var _tween: Tween

func _ready() -> void:
	if gun == null:
		gun = find_child("AssaultGun", true, false) as TextureRect
	Music.play_hub()
	_base_gun_scale = gun.scale
	_base_gun_rot = gun.rotation
	gun.pivot_offset = gun.size * 0.5
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	prev_btn.pressed.connect(func() -> void: _swap_class(-1))
	next_btn.pressed.connect(func() -> void: _swap_class(1))
	_refresh()

func _textures_for(id: String) -> Array[Texture2D]:
	match id:
		"heavy":
			return heavy_textures
		"scout":
			return scout_textures
		_:
			return assault_textures

func _player_for(id: String) -> Array[Texture2D]:
	match id:
		"heavy":
			return heavy_idle
		"scout":
			return scout_idle
		_:
			return assault_idle

func _refresh() -> void:
	var id := PlayerData.current_class
	var lvl := PlayerData.class_level(id)
	var texs := _textures_for(id)
	if texs.size() >= lvl and texs[lvl - 1] != null:
		gun.texture = texs[lvl - 1]
	var poses := _player_for(id)
	if player_preview and poses.size() >= lvl and poses[lvl - 1] != null:
		player_preview.texture = poses[lvl - 1]
	if class_label:
		class_label.text = id.to_upper()
	if lvl >= PlayerData.CLASS_MAX:
		price_label.text = "MAX"
		upgrade_button.disabled = true
	else:
		price_label.text = str(PlayerData.upgrade_cost(id))
		upgrade_button.disabled = false

func _swap_class(dir: int) -> void:
	PlayerData.cycle_class(dir)
	_refresh()

func _on_upgrade_pressed() -> void:
	var ok := PlayerData.try_upgrade_current()
	if not ok:
		_shake_no()
		return

	$UpgradeSound.play()
	_refresh()
	_flex_gun()

func _flex_gun() -> void:
	if _tween:
		_tween.kill()
	gun.scale = _base_gun_scale
	gun.rotation = _base_gun_rot
	gun.modulate = Color.WHITE
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(gun, "scale", _base_gun_scale * 1.35, 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(gun, "scale", _base_gun_scale, 0.22)\
		.set_delay(0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(gun, "rotation", _base_gun_rot + 0.18, 0.08)
	_tween.tween_property(gun, "rotation", _base_gun_rot - 0.18, 0.10).set_delay(0.08)
	_tween.tween_property(gun, "rotation", _base_gun_rot + 0.10, 0.10).set_delay(0.18)
	_tween.tween_property(gun, "rotation", _base_gun_rot, 0.14).set_delay(0.28)
	_tween.tween_property(gun, "modulate", Color(1.4, 1.25, 0.55), 0.08)
	_tween.tween_property(gun, "modulate", Color.WHITE, 0.28).set_delay(0.08)

func _shake_no() -> void:
	if _tween:
		_tween.kill()
	var start_x := gun.position.x
	_tween = create_tween()
	_tween.tween_property(gun, "position:x", start_x - 10.0, 0.05)
	_tween.tween_property(gun, "position:x", start_x + 10.0, 0.05)
	_tween.tween_property(gun, "position:x", start_x, 0.05)
	
