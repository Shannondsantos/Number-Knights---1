extends TextureRect

signal time_out

@export var start_time := 50
@export var popup_time := 0.7

var time_left := 30.0
var _timer: Label
var _up: Label
var _done := false
var _up_left := 0.0

func _ready() -> void:
	time_left = start_time
	_timer = get_node_or_null("Timer") as Label
	_up = get_node_or_null("TimerUp") as Label
	if _up:
		_up.modulate.a = 0.0
		_up.text = ""
	_paint()

func _process(delta: float) -> void:
	if _up and _up_left > 0.0:
		_up_left = maxf(0.0, _up_left - delta)
		_up.modulate.a = clampf(_up_left / popup_time, 0.0, 1.0)
	if _done:
		return
	time_left = maxf(0.0, time_left - delta)
	_paint()
	if time_left <= 0.0:
		_done = true
		time_left = 0.0
		_paint()
		time_out.emit()

func is_out() -> bool:
	return _done

func add_time(seconds: float) -> void:
	if _done:
		return
	time_left += seconds
	_paint()
	if _up:
		_up.text = "+%d" % ceili(seconds)
		_up.modulate.a = 1.0
		_up_left = popup_time

func _paint() -> void:
	if _timer == null:
		return
	var s := ceili(time_left)
	var mins := int(float(s) / 60.0)
	var secs := s - mins * 60
	_timer.text = "%d:%02d" % [mins, secs]
