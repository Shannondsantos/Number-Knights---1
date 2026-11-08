extends Node

@export var boss: PackedScene
@export var spawn_at := "SpawnMiniBoss1"
@export var fade_time := 0.7

var _ended := false

func _ready() -> void:
	_run()

func _alive_dir() -> bool:
	return is_inside_tree() and get_tree() != null

func _run() -> void:
	if not _alive_dir():
		return
	await get_tree().create_timer(1.0).timeout
	if not _alive_dir():
		return
	_spawn(boss, spawn_at)
	var timer := _timer()
	if timer and timer.has_signal("time_out"):
		timer.time_out.connect(_end)
	while _alive_dir() and not _ended:
		if timer and timer.has_method("is_out") and timer.is_out():
			_end()
			return
		if PlayerData.hp <= 0:
			_end()
			return
		await get_tree().process_frame

func _timer() -> Node:
	return _find("LevelTimer")

func _end() -> void:
	if _ended or not _alive_dir():
		return
	_ended = true
	var over := _find("TimeTrialOver")
	if over and over.has_method("show_over"):
		over.show_over()
		return
	push_error("Time trial: no TimeTrialOver with show_over()")

func _find(named: String) -> Node:
	if not _alive_dir():
		return null
	var root := get_tree().current_scene
	if root == null:
		return null
	if String(root.name) == named:
		return root
	return root.find_child(named, true, false)

func _spawn(packed: PackedScene, at: String) -> Node:
	if not _alive_dir() or packed == null:
		if packed == null:
			push_error("Time trial: no boss assigned")
		return null
	var mark := _find(at)
	if mark == null:
		push_error("Time trial: no marker " + at)
		return null
	var host := mark.get_parent()
	if host == null:
		host = get_tree().current_scene
	var n := packed.instantiate()
	host.add_child(n)
	if n is Node2D or n is Control:
		n.global_position = mark.global_position
	if "_base_pos" in n:
		n.set("_base_pos", n.position)
	if n.has_method("finish_travel"):
		n.finish_travel(n.position)
	if "_park" in n:
		n.set("_park", n.position)
		n.set("_park_global", n.global_position)
	_fade_in_deferred(n, fade_time)
	return n

func _fade_in_deferred(n: Node, t: float) -> void:
	if n == null:
		return
	_paint_alpha(n, 0.0)
	if not _alive_dir():
		return
	await get_tree().process_frame
	if n == null or not is_instance_valid(n):
		return
	_paint_alpha(n, 0.0)
	var tw := n.create_tween()
	tw.tween_method(func(a: float) -> void:
		if is_instance_valid(n):
			_paint_alpha(n, a)
	, 0.0, 1.0, t).set_trans(Tween.TRANS_SINE)

func _paint_alpha(n: Node, a: float) -> void:
	if String(n.name) == "Shield":
		return
	if n is CanvasItem:
		var m: Color = n.modulate
		m.a = a
		n.modulate = m
	for c in n.get_children():
		_paint_alpha(c, a)
