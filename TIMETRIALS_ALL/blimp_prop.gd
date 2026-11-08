extends TextureRect

@export var bob := 4.0
@export var speed := 1.2

var _home := 0.0
var _phase := 0.0

func _ready() -> void:
	_home = position.y
	_phase = randf() * TAU

func _process(_delta: float) -> void:
	position.y = _home + sin(Time.get_ticks_msec() / 1000.0 * speed + _phase) * bob
