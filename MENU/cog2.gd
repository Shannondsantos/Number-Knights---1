extends TextureRect

@export var spin_speed := -0.6

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = size * 0.5

func _process(delta: float) -> void:
	rotation += spin_speed * delta
