extends Node
@export var level_track: AudioStream
@export var boss_track: AudioStream
@export var elite_track: AudioStream
@export var time_trial_track: AudioStream
@export var survival_track: AudioStream
@export var boss_hold := 4.0
var _hold := 0.0
var _mode := ""
func _ready() -> void:
	_play_base()
func _process(delta: float) -> void:
	var mode := _wanted()
	if mode != "":
		_hold = boss_hold
		if mode != _mode:
			_mode = mode
			if mode == "elite" and elite_track:
				Music.play_boss(elite_track)
			else:
				Music.play_boss(boss_track)
		return
	if _hold > 0.0:
		_hold -= delta
		return
	if _mode != "":
		_mode = ""
		_play_base()
func _play_base() -> void:
	if _is_survival() and survival_track:
		Music.play_level(survival_track, true)
	elif _is_time_trial() and time_trial_track:
		Music.play_level(time_trial_track, true)
	else:
		Music.play_level(level_track, true)
func _is_time_trial() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	return scene.scene_file_path.contains("Time_Trials_")
func _is_survival() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	return scene.scene_file_path.contains("Survival_")
func _wanted() -> String:
	if get_tree().get_nodes_in_group("elites").size() > 0:
		return "elite"
	if get_tree().get_nodes_in_group("minibosses").size() > 0:
		return "boss"
	if get_tree().get_nodes_in_group("bosses").size() > 0:
		return "boss"
	return ""
