extends TextureRect
signal died
@export var max_hp: int = 4
@export var death_effect: PackedScene
@export var hit_radius := 55.0
var hp: int = 12
var _alive := true
var _base_mod := Color.WHITE
func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp
	_base_mod = modulate
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if pivot_offset == Vector2.ZERO:
		pivot_offset = size * 0.5
func contains_point(screen_pos: Vector2) -> bool:
	if not _alive:
		return false
	# Center of the texture in world space, works under Marker2D
	var center: Vector2 = get_global_transform() * pivot_offset
	return center.distance_to(screen_pos) <= hit_radius
func receive_shot() -> void:
	if not _alive:
		return
	hp -= PlayerData.current_damage()
	modulate = Color(6, 6, 6)
	var tw := create_tween()
	tw.tween_property(self, "modulate", _base_mod, 0.1)
	if hp <= 0:
		_die()
func _die() -> void:
	if not _alive:
		return
	_alive = false
	_spawn_death_effect()
	visible = false
	died.emit()
	queue_free()
func _spawn_death_effect() -> void:
	if death_effect == null:
		return
	var fx := death_effect.instantiate()
	var host := get_parent()
	if host == null:
		host = get_tree().current_scene
	if get_parent() and get_parent().get_parent():
		host = get_parent().get_parent()
	host.add_child(fx)
	if fx.has_method("setup"):
		fx.setup(global_position)
	else:
		fx.global_position = global_position
