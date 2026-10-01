extends CanvasLayer

@export var drop_from := -220.0
@export var drop_time := 0.45
@export var fade_time := 0.3
@export var wobble_amount := 0.035
@export var wobble_speed := 1.7
@export var pause_tex: Texture2D

@onready var splash: CanvasItem = get_node_or_null("Splash")

var _splash_rot := 0.0
var _shown := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if splash:
		_splash_rot = splash.rotation
		if pause_tex:
			splash.texture = pause_tex

func _process(_delta: float) -> void:
	if not _shown or splash == null:
		return
	splash.rotation = _splash_rot + sin(Time.get_ticks_msec() / 1000.0 * wobble_speed) * wobble_amount

func show_pause() -> void:
	if _shown:
		return
	_shown = true
	visible = true
	var hud := get_tree().current_scene
	if hud != null and hud.has_method("hide_play_ui"):
		hud.hide_play_ui()
	offset = Vector2(0.0, drop_from)
	_set_alpha(0.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "offset", Vector2.ZERO, drop_time)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(_set_alpha, 0.0, 1.0, fade_time)
	get_tree().paused = true

func hide_pause() -> void:
	_shown = false
	visible = false
	offset = Vector2.ZERO
	get_tree().paused = false
	var hud := get_tree().current_scene
	if hud != null and hud.has_method("show_play_ui"):
		hud.show_play_ui()

func _set_alpha(a: float) -> void:
	for c in get_children():
		if c is CanvasItem:
			var m: Color = c.modulate
			m.a = a
			c.modulate = m
