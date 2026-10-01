extends TextureButton

func _pressed() -> void:
	var box := get_parent().get_node_or_null("ResetConfirm")
	if box:
		box.visible = true
