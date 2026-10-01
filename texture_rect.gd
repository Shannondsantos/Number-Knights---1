extends TextureRect
@export var wobble_amount := 0.035
@export var wobble_speed := 0.5

var start_rotation := 0.0

func _ready():
	start_rotation = rotation

func _process(_delta):
	rotation = start_rotation + sin(Time.get_ticks_msec() / 1000.0 * wobble_speed) * wobble_amount
