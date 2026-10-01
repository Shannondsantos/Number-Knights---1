extends TextureRect

@export var move_amount := 6.0
@export var rot_amount := 0.050
@export var speed := 0.45

var _base_pos := Vector2.ZERO
var _base_rot := 0.0
var _phase := 0.0

func _ready() -> void:
	_base_pos = position
	_base_rot = rotation
	_phase = randf() * TAU
	pivot_offset = size * 0.5

func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0 * speed + _phase
	position = _base_pos + Vector2(sin(t * 0.7) * move_amount, cos(t * 0.55) * move_amount * 0.65)
	rotation = _base_rot + sin(t * 0.4) * rot_amount
