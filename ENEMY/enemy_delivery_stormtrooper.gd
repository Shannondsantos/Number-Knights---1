extends Control

signal left

@export var stormtrooper_scene: PackedScene
@export var full_texture: Texture2D
@export var empty_texture: Texture2D
@export var fly_time := 2.4
@export var leave_time := 2.2
@export var travel_distance := 520.0
@export var flank := 150.0
@export var drop_time := 0.55
@export var hold := 0.15
@export var drop_gap := 0.5

@onready var body: TextureRect = get_node_or_null("Body")

var hp: int = 99999
var _alive := true
var _park := Vector2.ZERO
var _park_global := Vector2.ZERO
var _base_rot := 0.0
var _base_mod := Color.WHITE
var _flash := 0.0

func _ready() -> void:
	add_to_group("enemies")
	hp = 99999
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	_base_rot = rotation
	if body:
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_base_mod = body.modulate
		if full_texture == null:
			full_texture = body.texture
		body.texture = full_texture
	call_deferred("_begin_approach")

func _begin_approach() -> void:
	if not _alive:
		return
	_park_global = global_position
	_park = position
	_base_rot = rotation
	global_position = _park_global - Vector2(travel_distance, 0.0)
	modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(self, "global_position", _park_global, fly_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_settle)

func _settle() -> void:
	if not _alive:
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position", _park + Vector2(22, 12), 0.12)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "rotation", _base_rot + 0.07, 0.12)
	tw.chain().set_parallel(true)
	tw.tween_property(self, "position", _park + Vector2(-10, -6), 0.16)\
		.set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "rotation", _base_rot - 0.045, 0.16)
	tw.chain().set_parallel(true)
	tw.tween_property(self, "position", _park, 0.18)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "rotation", _base_rot, 0.18)
	tw.chain().tween_interval(hold)
	tw.tween_callback(_drop_troopers)

func _drop_troopers() -> void:
	if not _alive:
		return
	if body and empty_texture:
		body.texture = empty_texture
	var origin := _gizmo()
	var slots := [
		Vector2(0, -flank),
		Vector2(-flank, 0),
		Vector2(0, flank),
		Vector2(flank, 0),
		Vector2(0, -flank),
		Vector2(-flank, 0),
		Vector2(0, flank),
		Vector2(flank, 0)
	
	]
	for i in slots.size():
		if not _alive:
			return
		_launch(origin, origin + slots[i])
		if i < slots.size() - 1:
			await get_tree().create_timer(drop_gap).timeout
	await get_tree().create_timer(0.35).timeout
	if _alive:
		_fly_off()

func _gizmo() -> Vector2:
	var mark := get_node_or_null("Gizmo")
	if mark is Node2D or mark is Control:
		return mark.global_position
	if body:
		return body.get_global_transform() * body.pivot_offset
	return get_global_transform() * pivot_offset

func _launch(from_global: Vector2, dest_global: Vector2) -> void:
	if stormtrooper_scene == null:
		return
	var n := stormtrooper_scene.instantiate()
	var host := get_parent()
	if host == null:
		host = get_tree().current_scene
	host.add_child(n)
	if not n is Control:
		return
	n.global_position = from_global
	n.set("_base_pos", n.position)
	if n.has_method("begin_travel"):
		n.begin_travel()
	var tw := n.create_tween()
	tw.tween_property(n, "global_position", dest_global, drop_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void:
		if not is_instance_valid(n):
			return
		if n.has_method("finish_travel"):
			n.finish_travel(n.position)
		else:
			n.set("_base_pos", n.position)
	)

func _fly_off() -> void:
	if not _alive:
		return
	_alive = false
	left.emit()
	var tw := create_tween()
	tw.tween_property(self, "global_position", _park_global + Vector2(travel_distance, -20.0), leave_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)

func _process(delta: float) -> void:
	if _flash <= 0.0 or body == null:
		return
	_flash -= delta
	if _flash <= 0.0:
		body.modulate = _base_mod

func contains_point(_screen_pos: Vector2) -> bool:
	return false

func receive_shot() -> void:
	return

func begin_travel() -> void:
	pass

func finish_travel(_dest: Vector2) -> void:
	pass
