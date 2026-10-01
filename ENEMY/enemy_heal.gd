extends Control

signal died

@export var max_hp: int = 1
@export var points: int = 1
@export var heal_amount: int = 1
@export var lifetime := 5
@export var drift_speed := 500
@export var wobble_move := 4.0
@export var wobble_rot := 0.05
@export var wobble_speed := 1.6
@export var blimp_dead: Texture2D
@export var death_effect: PackedScene
@export var death_sound: AudioStream

@onready var blimp: TextureRect = $Blimp
@onready var crate: TextureRect = $Crate

var hp: int = 1
var _alive := true
var _base_pos := Vector2.ZERO
var _base_rot := 0.0
var _life := 0.0
var _wphase := 0.0
var _sfx: AudioStreamPlayer

func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp
	_base_pos = position
	_base_rot = rotation
	_life = lifetime
	_wphase = randf() * TAU
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = size * 0.5
	if blimp:
		blimp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blimp.pivot_offset = blimp.size * 0.5
	if crate:
		crate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crate.pivot_offset = crate.size * 0.5
	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)


func _process(delta: float) -> void:
	if not _alive:
		return
	_life -= delta
	if _life <= 0.0:
		_despawn()
		return
	position.x += drift_speed * delta
	_base_pos = position
	var t := Time.get_ticks_msec() / 1000.0 * wobble_speed + _wphase
	if blimp:
		blimp.rotation = sin(t) * wobble_rot
		blimp.position.y = sin(t * 0.7) * wobble_move
	rotation = _base_rot + sin(t * 0.45) * wobble_rot * 0.35

func receive_shot() -> void:
	if not _alive:
		return
	hp -= PlayerData.current_damage()
	if hp <= 0:
		_die()

func _heal_player() -> void:
	var hud := get_tree().current_scene
	if hud != null and hud.has_method("apply_heal"):
		hud.apply_heal(heal_amount)
	elif PlayerData.has_method("heal"):
		PlayerData.heal(heal_amount)

func _die() -> void:
	if not _alive:
		return
	_alive = false
	_heal_player()
	PlayerData.currency += points
	PlayerData.save()
	died.emit()
	if _sfx and death_sound:
		_sfx.stream = death_sound
		_sfx.play()
	if blimp and blimp_dead:
		blimp.texture = blimp_dead
	if death_effect:
		var fx := death_effect.instantiate()
		var host := get_parent()
		if host:
			host.add_child(fx)
		if fx.has_method("setup"):
			fx.setup(global_position)
		else:
			fx.global_position = global_position
	_drop_crate()
	_sink_blimp()

func _drop_crate() -> void:
	if crate == null:
		return
	var host := get_parent()
	if host == null:
		host = get_tree().current_scene
	var keep: Vector2 = crate.global_position
	var keep_rot: float = crate.get_global_transform().get_rotation()
	crate.reparent(host)
	crate.global_position = keep
	crate.rotation = keep_rot
	var tw := crate.create_tween()
	tw.set_parallel(true)
	tw.tween_property(crate, "position", crate.position + Vector2(randf_range(-40.0, 80.0), randf_range(420.0, 640.0)), 0.85)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(crate, "rotation", keep_rot + randf_range(0.6, 1.4), 0.85)
	tw.tween_property(crate, "modulate:a", 0.0, 0.85)
	tw.chain().tween_callback(crate.queue_free)

func _sink_blimp() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position", position + Vector2(randf_range(-30.0, 50.0), 80.0), 0.7)\
		.set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "rotation", rotation + randf_range(-0.4, 0.4), 0.7)
	tw.tween_property(self, "modulate:a", 0.0, 0.7)
	tw.chain().tween_callback(queue_free)
	
func contains_point(screen_pos: Vector2) -> bool:
	if blimp and blimp.get_global_rect().has_point(screen_pos):
		return true
	if crate and crate.get_global_rect().has_point(screen_pos):
		return true
	return false
func _despawn() -> void:
	_alive = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)
