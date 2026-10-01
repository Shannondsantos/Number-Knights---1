extends TextureButton
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
func _pressed() -> void:
	var p := get_parent()
	while p and not p.has_method("hide_pause"):
		p = p.get_parent()
	if p:
		p.hide_pause()
