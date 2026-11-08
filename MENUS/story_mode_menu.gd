extends Control
@onready var time_trials_trophy: TextureRect = get_node_or_null("TimeTrialsTrophy")
@onready var survival_trophy: TextureRect = get_node_or_null("SurvivalTrophy")
@export var time_trials_blank: Texture2D
@export var time_trials_diamond: Texture2D
@export var survival_blank: Texture2D
@export var survival_diamond: Texture2D
func _ready() -> void:
	Music.play_hub()
	_refresh()
func _refresh() -> void:
	var tt_ids: Array[String] = ["easy", "normal", "hard", "expert", "knight"]
	var tt_all := true
	for id in tt_ids:
		if int(PlayerData.time_trial_best.get(id, 0)) < 50:
			tt_all = false
			break
	if time_trials_trophy:
		time_trials_trophy.texture = time_trials_diamond if tt_all else time_trials_blank
	var sv_ids: Array[String] = ["easy", "normal", "knight"]
	var sv_all := true
	for id in sv_ids:
		if int(PlayerData.survival_best.get(id, 0)) < 50:
			sv_all = false
			break
	if survival_trophy:
		survival_trophy.texture = survival_diamond if sv_all else survival_blank
