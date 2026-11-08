extends CanvasLayer
@export var drop_from := -220.0
@export var drop_time := 0.55
@export var fade_time := 0.4
@export var wobble_amount := 0.035
@export var wobble_speed := 1.7
@export var lose_tex: Texture2D
@export var win_tex: Texture2D
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
	_set_points_visible(false)
func _find_points_label() -> Label:
	var direct := get_node_or_null("PointsLabel")
	if direct is Label:
		return direct
	var under := get_node_or_null("Splash/PointsLabel")
	if under is Label:
		return under
	var box := get_node_or_null("TextureRect/PointsLabel")
	if box is Label:
		return box
	for n in find_children("*", "Label", true, false):
		if "point" in String(n.name).to_lower():
			return n
	return null
func _points_ui() -> Array[CanvasItem]:
	var out: Array[CanvasItem] = []
	if points_label:
		out.append(points_label)
	for n in get_children():
		if n == splash:
			continue
		if n is TextureRect or n is Label:
			out.append(n)
	if splash:
		for n in splash.get_children():
			if n is TextureRect or n is Label:
				if "point" in String(n.name).to_lower() or n is TextureRect:
					if n not in out:
						out.append(n)
	return out
func _set_points_visible(on: bool) -> void:
	for n in _points_ui():
		n.visible = on
func _exit_tree() -> void:
	var t := get_tree()
	if t:
		t.paused = false
func _process(_delta: float) -> void:
	if not _shown or splash == null:
		return
	splash.rotation = _splash_rot + sin(Time.get_ticks_msec() / 1000.0 * wobble_speed) * wobble_amount
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_6:
			show_win()
func set_points(n: int) -> void:
	if points_label == null:
		points_label = _find_points_label()
	if points_label == null:
		return
	points_label.visible = true
	points_label.text = str(n) + " POINTS"
func _director() -> Node:
	var root := get_tree().current_scene
	if root == null:
		return null
	for n in root.find_children("*", "", true, false):
		if "wave" in n and "trial_id" in n:
			return n
	return null
func show_lose() -> void:
	var dir := _director()
	if dir and "trial_id" in dir:
		show_survival_end()
		return
	if splash and lose_tex:
		splash.texture = lose_tex
	_set_points_visible(false)
	Music.play_lose()
	show_game_over()
	PlayerData.discard_run()
func show_survival_end() -> void:
	if splash and lose_tex:
		splash.texture = lose_tex
	var waves := 0
	var dir := _director()
	if dir:
		waves = int(dir.get("wave"))
		var id := str(dir.get("trial_id"))
		PlayerData.record_survival(id, waves)
	_set_points_visible(true)
	if points_label == null:
		points_label = _find_points_label()
	if points_label:
		points_label.visible = true
		points_label.text = str(waves) + " WAVES"
		var box := points_label.get_parent()
		if box is CanvasItem:
			box.visible = true
	Music.play_lose()
	show_game_over()
	PlayerData.commit_run()
func show_win() -> void:
	if splash and win_tex:
		splash.texture = win_tex
	_set_points_visible(true)
	set_points(PlayerData.level_points())
	Music.play_win()
	show_game_over()
	PlayerData.commit_run()
	PlayerData.mark_cleared(PlayerData.current_level)
func show_game_over() -> void:
	if _shown:
		return
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
	tw.tween_method(_set_alpha, 0.0, 1.0, fade_time)\
		.set_trans(Tween.TRANS_SINE)
	if t:
		t.paused = true
func _set_alpha(a: float) -> void:
	for c in get_children():
		if c is CanvasItem:
			var m: Color = c.modulate
			m.a = a
			c.modulate = m
