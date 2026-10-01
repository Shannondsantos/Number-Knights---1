extends TextureButton

func _pressed() -> void:
	PlayerData.reset_to_default()
	get_tree().change_scene_to_file("res://MENUS/MainMenu.tscn")
