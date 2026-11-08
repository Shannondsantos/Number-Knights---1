extends TextureButton


@export var next_scene: String = "res://MENUS/MiniGamesMenu.tscn"

var start_rotation := 2.0

func _ready():
	start_rotation = rotation



func _pressed() -> void:
	get_tree().change_scene_to_file(next_scene)
