extends TextureButton

@export var wobble_amount := 0.01
@export var wobble_speed := 2.0
@export var next_scene: String = "res://MENUS/TimeTrialsMenu.tscn"
@export var unlock_after := 3

var start_rotation := 0.0
var _open := false

@onready var lock_icon: CanvasItem = get_node_or_null("level_lock")

func _ready() -> void:
	start_rotation = rotation
	_open = _level_cleared(unlock_after)
	disabled = not _open
	modulate.a = 1.0 if _open else 0.55
	if lock_icon:
		lock_icon.visible = not _open
	if not _open:
		rotation = start_rotation

func _level_cleared(id: int) -> bool:
	for n in PlayerData.cleared_levels:
		if int(n) == id:
			return true
	return false

func _process(_delta: float) -> void:
	if not _open:
		return
	rotation = start_rotation + sin(Time.get_ticks_msec() / 1000.0 * wobble_speed) * wobble_amount

func _pressed() -> void:
	if not _open or next_scene.is_empty():
		return
	get_tree().change_scene_to_file(next_scene)
