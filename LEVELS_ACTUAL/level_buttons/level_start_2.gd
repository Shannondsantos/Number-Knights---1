extends TextureButton

@export var level_id := 2
@export var next_scene: String = ""

@onready var lock_icon: CanvasItem = get_node_or_null("level_lock")

func _ready() -> void:
	_apply_lock()

func _apply_lock() -> void:
	var open := PlayerData.is_unlocked(level_id)
	if lock_icon:
		lock_icon.visible = not open
	disabled = not open
	modulate.a = 1.0 if open else 0.55

func _pressed() -> void:
	if not PlayerData.is_unlocked(level_id):
		return
	if next_scene == "":
		return
	PlayerData.current_level = level_id
	get_tree().change_scene_to_file(next_scene)
