extends Node
@export var fodder: PackedScene
@export var apc: PackedScene
@export var tank: PackedScene
@export var nemesis: PackedScene
@export var storm_carrier: PackedScene
@export var mastermind: PackedScene
@export var far_fade_time := 2.5
@export var trial_id := "easy"
var wave := 0
var _last_beat := -1
func _ready() -> void:
	_run()
func _alive_dir() -> bool:
	return is_inside_tree() and get_tree() != null
func _run() -> void:
	if not _alive_dir():
		return
	await get_tree().create_timer(0.6).timeout
	while _alive_dir():
		if PlayerData.hp <= 0:
			_end()
			return
		for i in 4:
			if not _alive_dir() or PlayerData.hp <= 0:
				_end()
				return
			await _random_beat()
		if not _alive_dir() or PlayerData.hp <= 0:
			_end()
			return
		await _nemesis_wave()
func _end() -> void:
	if not _alive_dir():
		return
	var over := _find("GameOverLayer")
	if over and over.has_method("show_survival_end"):
		over.show_survival_end()
func _random_beat() -> void:
	var beat := randi() % 5
	if beat == _last_beat:
		beat = (beat + 1) % 5
	_last_beat = beat
	match beat:
		0:
			await _beat_fodder_tank()
		1:
			await _beat_apc()
		2:
			await _beat_apc_fodder()
		3:
			await _beat_storm_carrier()
		4:
			await _beat_mastermind()
	_wave_done()
func _wave_done() -> void:
	if not _alive_dir():
		return
	wave += 1
	PlayerData.set_survival_current(wave)
func _beat_fodder_tank() -> void:
	_spawn(fodder, "Spawn1")
	await get_tree().create_timer(0.4).timeout
	if not _alive_dir():
		return
	_spawn(fodder, "Spawn2")
	await get_tree().create_timer(0.4).timeout
	if not _alive_dir():
		return
	_spawn(fodder, "Spawn3")
	await get_tree().create_timer(1.0).timeout
	if not _alive_dir():
		return
	_spawn(fodder, "Spawn4")
	await get_tree().create_timer(0.4).timeout
	if not _alive_dir():
		return
	_spawn(fodder, "Spawn5")
	await get_tree().create_timer(0.4).timeout
	if not _alive_dir():
		return
	_spawn(fodder, "Spawn6")
	await get_tree().create_timer(1.0).timeout
	if not _alive_dir():
		return
	await _cleared()
func _beat_apc() -> void:
	_spawn(apc, "SpawnAPC1")
	await get_tree().create_timer(0.5).timeout
	if not _alive_dir():
		return
	_spawn(apc, "SpawnAPC2")
	await get_tree().create_timer(0.5).timeout
	if not _alive_dir():
		return
	_spawn(apc, "SpawnAPC3")
	await _cleared()
func _beat_apc_fodder() -> void:
	_spawn(apc, "SpawnAPC1")
	await get_tree().create_timer(0.4).timeout
	if not _alive_dir():
		return
	_spawn(fodder, "Spawn1")
	await get_tree().create_timer(0.4).timeout
	if not _alive_dir():
		return
	_spawn(fodder, "Spawn2")
	await get_tree().create_timer(0.4).timeout
	if not _alive_dir():
		return
	_spawn(fodder, "Spawn3")
	await _cleared()
	if not _alive_dir():
		return
	_spawn(tank, "SpawnTank1")
	if not _alive_dir():
		return
	_spawn(tank, "SpawnTank2")
	await _cleared()
func _beat_storm_carrier() -> void:
	_spawn(storm_carrier, "SpawnStormCarrier1")
	_spawn(storm_carrier, "SpawnStormCarrier2")
	await _cleared()
func _beat_mastermind() -> void:
	_spawn(mastermind, "SpawnMasterMind1")
	await get_tree().create_timer(0.5).timeout
	if not _alive_dir():
		return
	await _cleared()
func _nemesis_wave() -> void:
	_spawn(nemesis, "SpawnNemesis1")
	await _cleared()
	_wave_done()
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
	if not _alive_dir():
		return null
	if packed == null:
		push_error("Director: missing packed scene for " + at)
		return null
	var mark := _find(at)
	if mark == null:
		push_error("Director: no marker named " + at)
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
	_fade_in_deferred(n, 0.7)
	return n
func _fade_in_deferred(n: Node, t: float = 0.7) -> void:
	if n == null:
		return
	_paint_alpha(n, 0.0)
	if "_base_mod" in n:
		n.set("_base_mod", Color(1, 1, 1, 0))
	if not _alive_dir():
		return
	await get_tree().process_frame
	if n == null or not is_instance_valid(n):
		return
	_paint_alpha(n, 0.0)
	var tw := n.create_tween()
	tw.tween_method(func(a: float) -> void:
		if not is_instance_valid(n):
			return
		_paint_alpha(n, a)
		if "_base_mod" in n:
			n.set("_base_mod", Color(1, 1, 1, a))
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
func _living() -> int:
	if not _alive_dir():
		return 0
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and bool(e.get("_alive")):
			n += 1
	return n
func _cleared() -> void:
	if not _alive_dir():
		return
	await get_tree().process_frame
	while _alive_dir() and _living() > 0:
		if PlayerData.hp <= 0:
			_end()
			return
		await get_tree().process_frame
func _wait(sec: float) -> bool:
	var left := sec
	while left > 0.0 and _alive_dir():
		if PlayerData.hp <= 0:
			_end()
			return false
		await get_tree().process_frame
		left -= get_process_delta_time()
	return _alive_dir() and PlayerData.hp > 0
