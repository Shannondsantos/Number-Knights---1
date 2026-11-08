extends TextureButton


@export var next_scene: String = "res://MENUS/TimeTrialsMenu.tscn"

var start_rotation := 2.0

func _ready():
	start_rotation = rotation



func _pressed() -> void:
	PlayerData.discard_run()
	get_tree().change_scene_to_file(next_scene)
