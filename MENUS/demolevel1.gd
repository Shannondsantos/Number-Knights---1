extends TextureButton

@export var wobble_amount := 0.035
@export var wobble_speed := 1.7
@export var next_scene: String = "res://MENUS/StoryModeMenu.tscn"
@export var stop_after_level := 1

var start_rotation := 0.0
var _base_mod := Color.WHITE
var _flashing := true
var _wait := 0.8

func _ready() -> void:
	start_rotation = rotation
	_base_mod = modulate
	_flashing = not _level_cleared(stop_after_level)
	_apply_stars()

func _level_cleared(id: int) -> bool:
	for n in PlayerData.cleared_levels:
		if int(n) == id:
			return true
	return false

func _apply_stars() -> void:
	_set_star("Star1", _level_cleared(3))
	_set_star("Star2", _level_cleared(6))
	_set_star("Star3", _level_cleared(10))

func _set_star(node_name: String, on: bool) -> void:
	var star := get_node_or_null(node_name) as CanvasItem
	if star:
		star.visible = on

func _process(delta: float) -> void:
	rotation = start_rotation + sin(Time.get_ticks_msec() / 1000.0 * wobble_speed) * wobble_amount
	if not _flashing:
		modulate = _base_mod
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_pulse()

func _pulse() -> void:
	_wait = 1.4
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(2.6, 2.6, 2.6, _base_mod.a), 0.07)
	tw.tween_property(self, "modulate", _base_mod, 0.09)
	tw.tween_property(self, "modulate", Color(2.6, 2.6, 2.6, _base_mod.a), 0.07)
	tw.tween_property(self, "modulate", _base_mod, 0.12)

func _pressed() -> void:
	if next_scene.is_empty():
		return
	get_tree().change_scene_to_file(next_scene)
