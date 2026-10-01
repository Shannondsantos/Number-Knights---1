extends Node

@export var level_track: AudioStream
@export var boss_track: AudioStream
@export var boss_hold := 4.0

var _hold := 0.0
var _boss_on := false

func _ready() -> void:
	Music.play_level(level_track, true)

func _process(delta: float) -> void:
	if _boss_on_screen():
		_hold = boss_hold
		if not _boss_on:
			_boss_on = true
			Music.play_boss(boss_track)
		return
	if _hold > 0.0:
		_hold -= delta
		return
	if _boss_on:
		_boss_on = false
		Music.play_level(level_track, true)

func _boss_on_screen() -> bool:
	if get_tree().get_nodes_in_group("minibosses").size() > 0:
		return true
	if get_tree().get_nodes_in_group("bosses").size() > 0:
		return true
	return false
