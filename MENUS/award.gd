extends TextureRect
func _ready() -> void:
	visible = PlayerData.cleared_levels.has(10)
	modulate.a = 1.0 if visible else 0.0
func _process(_delta: float) -> void:
	var open := PlayerData.cleared_levels.has(10)
	if open != visible:
		visible = open
		modulate.a = 1.0 if open else 0.0
