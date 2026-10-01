extends Control

@onready var far_layer: Control = $Far
@onready var mid_layer: Control = $Mid
@onready var near_layer: Control = $Near

# --- overall handheld motion (shared by Far / Mid / Near) ---

@export var move_amount := 7.0
# How many pixels the shake wanders. Higher = more bounce.

@export var rot_amount := 0.012
# How much the layers tilt, in radians. 0.012 is a tiny handheld roll.

@export var speed_a := 0.7
# Slow wave speed. The lazy left-right drift.

@export var speed_b := 1.15
# Faster wave speed. Mixes with speed_a so it doesn’t look like a metronome.

@export var max_offset := 36.0
# Hard clamp in pixels. Must stay smaller than the extra background border
# or you’ll see empty edges.

# --- Far layer (background, “way in the back”) ---

@export var far_move := 0.4
# Share of move_amount the bg gets. 0.22 = bg barely drifts (looks distant).

@export var far_rot := 0.2
# Share of rot_amount the bg gets. Keep low so the horizon doesn’t rock.

# --- Mid layer (enemies, level props) ---

@export var mid_move := 0.7
# Enemies sit between bg and player. 0.55 = half the full shake.

@export var mid_rot := 0.5
# Mid tilt. A bit more than Far, less than Near.

# --- Near layer (player, rubble, “in your face”) ---

@export var near_move := 1.3
# 1.0 = full move_amount. This is the layer glued to the “camera.”

@export var near_rot := 1.0
# 1.0 = full rot_amount. Player / cover rock with the handheld cam.

var _t_far := Vector2.ZERO
var _t_mid := Vector2.ZERO
var _t_near := Vector2.ZERO
var _r_far := 0.0
var _r_mid := 0.0
var _r_near := 0.0

func _ready() -> void:
	_t_far = far_layer.position
	_t_mid = mid_layer.position
	_t_near = near_layer.position
	_r_far = far_layer.rotation
	_r_mid = mid_layer.rotation
	_r_near = near_layer.rotation
	var pivot := Vector2(360, 640)
	far_layer.pivot_offset = pivot
	mid_layer.pivot_offset = pivot
	near_layer.pivot_offset = pivot

func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var x := sin(t * speed_a) * move_amount + sin(t * speed_b * 1.7) * (move_amount * 0.35)
	var y := cos(t * speed_b) * move_amount + sin(t * speed_a * 1.3) * (move_amount * 0.35)
	x = clampf(x, -max_offset, max_offset)
	y = clampf(y, -max_offset, max_offset)
	var rot := sin(t * 0.55) * rot_amount
	far_layer.position = _t_far + Vector2(x, y) * far_move
	far_layer.rotation = _r_far + rot * far_rot
	mid_layer.position = _t_mid + Vector2(x, y) * mid_move
	mid_layer.rotation = _r_mid + rot * mid_rot
	near_layer.position = _t_near + Vector2(x, y) * near_move
	near_layer.rotation = _r_near + rot * near_rot
