extends TextureButton

@export var wobble_amount := 0.035
@export var wobble_speed := 1.7
@export var next_scene: String = "res://MENUS/UpgradeMenu.tscn"

var start_rotation := 0.0

func _ready():
	start_rotation = rotation

func _process(_delta):
	rotation = start_rotation + sin(Time.get_ticks_msec() / 1000.0 * wobble_speed) * wobble_amount

func _pressed() -> void:
	if next_scene.is_empty():
		return
	get_tree().change_scene_to_file(next_scene)
