extends Control

@export var pages: Array[Texture2D] = []
@export var next_level: String = ""
@export var bump := 1.06

@onready var page: TextureRect = $Page
@onready var next_button: BaseButton = $NextButton
@onready var skip_button: BaseButton = $SkipButton
@export var level_track: AudioStream

var _i := 0
var _base_scale := Vector2.ONE
var _tw: Tween

func _ready() -> void:
	_base_scale = page.scale
	page.pivot_offset = page.size * 0.5
	next_button.pressed.connect(_next)
	skip_button.pressed.connect(_go)
	_show(false)
	call_deferred("_play_music")

func _play_music() -> void:
	if level_track == null:
		push_error("Comic: Level Track is empty")
		return
	Music.play_level(level_track, true)

func _show(do_bump: bool) -> void:
	if _i >= pages.size():
		_go()
		return
	if _i < pages.size() and pages[_i]:
		page.texture = pages[_i]
	if not do_bump:
		return
	if _tw:
		_tw.kill()
	page.scale = _base_scale
	_tw = create_tween()
	_tw.tween_property(page, "scale", _base_scale * bump, 0.08)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_property(page, "scale", _base_scale, 0.12)\
		.set_trans(Tween.TRANS_SINE)

func _next() -> void:
	_i += 1
	_show(true)

func _go() -> void:
	if next_level == "":
		return
	get_tree().change_scene_to_file(next_level)
