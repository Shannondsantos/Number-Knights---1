extends TextureButton
func _pressed() -> void:
	var p := get_tree().current_scene.get_node_or_null("PauseLayer")
	if p and p.has_method("show_pause"):
		p.show_pause()
