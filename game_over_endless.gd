extends CanvasLayer

@export var drop_from := -220.0
@export var drop_time := 0.55
@export var fade_time := 0.4
@export var wobble_amount := 0.035
@export var wobble_speed := 1.7
@export var lose_tex: Texture2D

@onready var splash: CanvasItem = get_node_or_null("Splash")

var _splash_rot := 0.0
var _shown := false
var points_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if splash:
		_splash_rot = splash.rotation
	points_label = _find_points_label()
	offset = Vector2.ZERO

func _find_points_label() -> Label:
	var direct := get_node_or_null("PointsLabel")
	if direct is Label:
		return direct
	for n in find_children("*", "Label", true, false):
		if "point" in String(n.name).to_lower():
			return n
	return null

func _exit_tree() -> void:
	var t := get_tree()
	if t:
		t.paused = false

func _process(_delta: float) -> void:
	if not _shown or splash == null:
		return
	splash.rotation = _splash_rot + sin(Time.get_ticks_msec() / 1000.0 * wobble_speed) * wobble_amount

func show_lose() -> void:
	if _shown:
		return
	if splash and lose_tex:
		splash.texture = lose_tex
	if points_label == null:
		points_label = _find_points_label()
	if points_label:
		points_label.visible = true
		points_label.text = str(PlayerData.level_points()) + " POINTS"
	PlayerData.commit_run()
	Music.play_lose()
	_shown = true
	visible = true
	var t := get_tree()
	if t:
		var hud := t.current_scene
		if hud != null and hud.has_method("hide_play_ui"):
			hud.hide_play_ui()
	offset = Vector2(0.0, drop_from)
	_set_alpha(0.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "offset", Vector2.ZERO, drop_time)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(_set_alpha, 0.0, 1.0, fade_time)
	if t:
		t.paused = true

func _set_alpha(a: float) -> void:
	for c in get_children():
		if c is CanvasItem:
			var m: Color = c.modulate
			m.a = a
			c.modulate = m
