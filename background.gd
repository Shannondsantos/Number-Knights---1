extends TextureRect

@export var scroll_speed := 100.0

@onready var background2 = get_parent().get_node("Background2")

var offset := 0.0

func _process(delta):
	offset += scroll_speed * delta
	
	position.y = offset
	background2.position.y = offset - size.y
	
	if offset >= size.y:
		offset -= size.y
