extends TextureButton
@onready var credits: CanvasItem = get_node_or_null("Credits")
func _ready() -> void:
	if credits:
		credits.visible = false
	pressed.connect(_toggle)
func _toggle() -> void:
	if credits == null:
		return
	credits.visible = not credits.visible
