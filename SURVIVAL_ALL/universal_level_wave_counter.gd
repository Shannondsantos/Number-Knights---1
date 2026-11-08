extends TextureRect
@onready var label: Label = get_node_or_null("Label")
var _director: Node
func _ready() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	for n in root.find_children("*", "", true, false):
		if "wave" in n:
			_director = n
			break
	_refresh()
func _process(_delta: float) -> void:
	_refresh()
func _refresh() -> void:
	if label == null or _director == null:
		return
	label.text = str(int(_director.wave))
