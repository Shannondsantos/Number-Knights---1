extends TextureButton

func _pressed() -> void:
	var hud := get_tree().current_scene
	if hud != null and hud.has_method("request_reload"):
		hud.request_reload()
