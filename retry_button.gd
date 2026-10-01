extends TextureButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()      # retry
	# or change_scene_to_file("res://MidMenu.tscn")
