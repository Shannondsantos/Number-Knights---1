extends TextureRect

@export var light_off: Texture2D
@export var light_on: Texture2D
@export var blink := 0.35
@export var wobble_move := 6.0
@export var wobble_rot := 0.08
@export var wobble_speed := 3.0

var _base_pos := Vector2.ZERO
var _base_rot := 0.0
var _phase := 0.0
var _spd := 1.0
var _xmul := 1.0
var _ymul := 1.0
var _blink_t := 0.0
var _on := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base_pos = position
	_base_rot = rotation
	pivot_offset = size * 0.5
	_phase = randf() * TAU
	_spd = randf_range(0.75, 1.25)
	_xmul = randf_range(0.7, 1.3)
	_ymul = randf_range(0.7, 1.3)
	if light_off == null:
		light_off = texture
	if light_off:
		texture = light_off

func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0 * wobble_speed * _spd + _phase
	position = _base_pos + Vector2(sin(t) * wobble_move * _xmul, cos(t * 0.8) * wobble_move * _ymul)
	rotation = _base_rot + sin(t * 0.7) * wobble_rot
	if light_on == null:
		return
	_blink_t += delta
	if _blink_t < blink:
		return
	_blink_t = 0.0
	_on = not _on
	texture = light_on if _on else light_off
