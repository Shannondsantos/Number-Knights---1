extends Node

# Per-level brain. Copy this file, rename it, change ONLY _run().
# Markers live in the scene: Spawn1, SpawnOfficer1, SpawnTank1, SpawnMiniBoss1
# Packed scenes are assigned on this node in the Inspector.

@export var fodder: PackedScene
@export var officer: PackedScene
@export var tank: PackedScene
@export var mini_boss: PackedScene
@export var heal: PackedScene
@export var carrier: PackedScene
@export var boat: PackedScene
@export var brute: PackedScene
@export var zipper: PackedScene
@export var far_fade_time := 2.5
func _ready() -> void:
	_run()

func _alive_dir() -> bool:
	# False after win/lose/retry so awaits don't run on a dead scene
	return is_inside_tree() and get_tree() != null

# ---------------------------------------------------------------------------
# LEVEL BEAT SHEET — this is what you rewrite per level
# await timer          = wait seconds
# _spawn(scene, name)  = instance that enemy on that marker
# await _cleared()     = wait until no living "enemies"
# await _boss_dead()   = wait until no minibosses/bosses
# _fade_under(...)     = fade one TextureRect under Far/Mid/Near
# ---------------------------------------------------------------------------
func _run() -> void:
	if not _alive_dir():
		return
	# chef is already in the scene
	await get_tree().create_timer(0.4).timeout
	await _cleared()
	if not _alive_dir():
		return

	# beat 1 — Spawn1, Spawn2, Spawn3 together
	_spawn(fodder, "Spawn1")
	_spawn(fodder, "Spawn2")
	_spawn(fodder, "Spawn3")
	await _cleared()
	if not _alive_dir():
		return

	# beat 2 — carrier and boat
	_spawn(carrier, "SpawnCarrier1")
	_spawn(boat, "SpawnBoat1")
	_spawn(zipper, "SpawnAPC3")
	await _cleared()
	if not _alive_dir():
		return

	# beat 3 — both carriers
	_spawn(carrier, "SpawnCarrier1")
	_spawn(carrier, "SpawnCarrier2")
	_spawn(zipper, "SpawnAPC3")
	await _cleared()
	if not _alive_dir():
		return
	
	_spawn(zipper, "SpawnAPC1")
	_spawn(zipper, "SpawnAPC2")
	_spawn(zipper, "SpawnAPC3")

	await _cleared()
	if not _alive_dir():
		return
		
	# beat 4 — baby boss, then 2 seconds
	_spawn(mini_boss, "SpawnMiniBoss1")
	await _boss_dead()
	await _cleared()
	if not _alive_dir():
		return
	await get_tree().create_timer(2.0).timeout
	if not _alive_dir():
		return

	# beat 5 — brute, then 2 seconds and win
	_spawn(brute, "SpawnMiniBossBrute1")
	await _boss_dead()
	await _cleared()
	if not _alive_dir():
		return
	await get_tree().create_timer(2.0).timeout
	if not _alive_dir():
		return
	var go := get_tree().current_scene.get_node_or_null("GameOverLayer")
	if go and go.has_method("show_win"):
		go.show_win()

# Fade one child under a shake layer. Example:
#   _fade_under("Far", "Background", 0.0, 2.5)   hide the normal sky
#   _fade_under("Far", "Background2", 1.0, 1.0)  bring the boss plate in
#   _fade_under("Mid", "Smoke", 0.4, 1.0)
func _fade_under(layer_name: String, child_name: String, to_alpha: float, t: float = 1.5) -> void:
	var layer := _find(layer_name)
	if layer == null:
		push_error("Director: no layer " + layer_name)
		return
	var child := layer.find_child(child_name, true, false)
	if child == null:
		push_error("Director: no " + child_name + " under " + layer_name)
		return
	var tw := child.create_tween()
	tw.tween_method(func(a: float) -> void:
		if is_instance_valid(child):
			_paint_alpha(child, a)
	, _read_alpha(child), to_alpha, t).set_trans(Tween.TRANS_SINE)

func _read_alpha(n: Node) -> float:
	if n is CanvasItem:
		return (n as CanvasItem).modulate.a
	for c in n.get_children():
		if c is CanvasItem:
			return (c as CanvasItem).modulate.a
	return 1.0

func _find(named: String) -> Node:
	if not _alive_dir():
		return null
	var root := get_tree().current_scene
	if root == null:
		return null
	if String(root.name) == named:
		return root
	return root.find_child(named, true, false)

# Drop a packed scene on a marker. Marker can sit under Mid or Director.
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
	# Enemy scripts stash home pos in _ready BEFORE we move them — fix that
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
	if String(n.name) == "Hull" or String(n.name) == "Waves" or String(n.name) == "Tracks":
		return
	if n is CanvasItem:
		var m: Color = n.modulate
		m.a = a
		n.modulate = m
	for c in n.get_children():
		_paint_alpha(c, a)

# How many clickable living enemies are on screen (includes blimp if it's in "enemies")
func _living() -> int:
	if not _alive_dir():
		return 0
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and bool(e.get("_alive")):
			n += 1
	return n

# Wait until every living enemy is gone (timeout heal copters count as gone)
func _cleared() -> void:
	if not _alive_dir():
		return
	await get_tree().process_frame
	while _alive_dir() and _living() > 0:
		await get_tree().process_frame

# Wait until no miniboss/boss nodes exist
func _boss_dead() -> void:
	if not _alive_dir():
		return
	await get_tree().process_frame
	while _alive_dir():
		var st := get_tree()
		if st.get_nodes_in_group("minibosses").size() == 0 \
		and st.get_nodes_in_group("bosses").size() == 0:
			break
		await st.process_frame
