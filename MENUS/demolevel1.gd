extends TextureButton

@export var wobble_amount := 0.04
@export var wobble_speed := 2.0
@export var next_scene: String = "res://MENUS/StoryModeMenu.tscn"

var start_rotation := 2.0

func _ready():
	start_rotation = rotation

func _process(_delta):
	rotation = start_rotation + sin(Time.get_ticks_msec() / 1000.0 * wobble_speed) * wobble_amount

func _pressed() -> void:
	get_tree().change_scene_to_file(next_scene)
