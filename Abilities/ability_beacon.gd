extends TextureRect

@export var light_off: Texture2D
@export var light_on: Texture2D
@export var blink := 0.18

var _base_pos := Vector2.ZERO
var _was_up := false
var _leaving := false
var _blink_t := 0.0
var _on := false
var _life := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base_pos = position
	visible = false
	modulate = Color.WHITE
	if light_off:
		texture = light_off

func _process(delta: float) -> void:
	var up := PlayerData.beacon_time > 0.0
	if up and not _was_up and not _leaving:
		_drop_in()
	_was_up = up or _life > 0.0
	if _life > 0.0 and not _leaving:
		_life -= delta
		_blink_t += delta
		if _blink_t >= blink:
			_blink_t = 0.0
			_on = not _on
			if _on and light_on:
				texture = light_on
			elif light_off:
				texture = light_off
		if _life <= 0.0:
			_jump_away()

func _drop_in() -> void:
	_life = PlayerData.BEACON_DURATION
	_leaving = false
	visible = true
	modulate = Color.WHITE
	position = _base_pos + Vector2(0, -80)
	scale = Vector2(0.6, 0.6)
	if light_off:
		texture = light_off
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position", _base_pos, 0.28)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.28)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _jump_away() -> void:
	if _leaving:
		return
	_leaving = true
	_life = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position", _base_pos + Vector2(0, -46), 0.16)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(1.08, 0.92), 0.16)
	tw.chain().set_parallel(true)
	tw.tween_property(self, "position", _base_pos + Vector2(18, 30), 0.28)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 0.0, 0.28)
	tw.chain().tween_callback(func() -> void:
		visible = false
		modulate = Color.WHITE
		position = _base_pos
		scale = Vector2.ONE
		_leaving = false
		_was_up = false
)
