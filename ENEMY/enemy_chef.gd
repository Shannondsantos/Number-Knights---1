extends Control

signal left

@export var stay_time := 4.5
@export var giggle_move := 10.0
@export var giggle_rot := 0.08
@export var giggle_speed := 7.5
@export var hook_swing := 0.22
@export var fly_time := 0.7

@onready var hook: TextureRect = get_node_or_null("ChefHook")

var hp: int = 99999
var _alive := true
var _base_pos := Vector2.ZERO
var _base_rot := 0.0
var _hook_rot := 0.0
var _phase := 0.0
var _life := 0.0
var _leaving := false

func _ready() -> void:
	add_to_group("enemies")
	hp = 99999
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base_pos = position
	_base_rot = rotation
	_phase = randf() * TAU
	_life = stay_time + randf_range(0.0, 0.6)
	if hook:
		hook.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hook.pivot_offset = Vector2(hook.size.x * 0.5, 8.0)
		_hook_rot = hook.rotation

func _process(delta: float) -> void:
	if _leaving:
		return
	_life -= delta
	var t := Time.get_ticks_msec() / 1000.0 * giggle_speed + _phase
	# little bounce-laugh, not a smooth hover
	var hop := absf(sin(t))
	position = _base_pos + Vector2(sin(t * 1.7) * giggle_move * 0.45, -hop * giggle_move)
	rotation = _base_rot + sin(t * 2.1) * giggle_rot
	if hook:
		hook.rotation = _hook_rot + sin(t * 1.35 + 0.4) * hook_swing
	if _life <= 0.0:
		_fly_off()

func _fly_off() -> void:
	if _leaving:
		return
	_leaving = true
	_alive = false
	left.emit()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position", position + Vector2(randf_range(-40.0, 40.0), -900.0), fly_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "rotation", rotation + randf_range(-0.4, 0.4), fly_time)
	if hook:
		tw.tween_property(hook, "rotation", _hook_rot + randf_range(-0.8, 0.8), fly_time)
	tw.chain().tween_callback(queue_free)

func receive_shot() -> void:
	return

func contains_point(_screen_pos: Vector2) -> bool:
	return false
