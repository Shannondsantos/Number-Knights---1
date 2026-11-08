extends Control
@onready var medal: TextureRect = $Medal
@export var blank: Texture2D
@export var bronze: Texture2D
@export var iron: Texture2D
@export var gold: Texture2D
@export var diamond: Texture2D
@export var upgrade_sound: AudioStream
@export var trial_id := "easy"
var _sfx: AudioStreamPlayer
var _last_rank := -1
func _ready() -> void:
	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)
	_refresh(false)
func _process(_delta: float) -> void:
	_refresh(true)
func _rank() -> int:
	var saved := PlayerData.survival_wave(trial_id)
	var now := PlayerData.survival_current
	var wave := maxi(saved, now)
	return PlayerData.medal_rank_for_wave(wave)
func _texture_for(rank: int) -> Texture2D:
	match rank:
		1: return bronze
		2: return iron
		3: return gold
		4: return diamond
		_: return blank
func _refresh(play_sound: bool) -> void:
	var rank := _rank()
	if rank == _last_rank:
		return
	if play_sound and rank > _last_rank:
		if upgrade_sound and _sfx:
			_sfx.stream = upgrade_sound
			_sfx.play()
		_flash_and_shake()
	_last_rank = rank
	if medal:
		medal.texture = _texture_for(rank)
func _flash_and_shake() -> void:
	if medal == null:
		return
	var base_pos := medal.position
	var base_mod := medal.modulate
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(medal, "modulate", Color(2.8, 2.8, 2.8), 0.06)
	tw.tween_property(medal, "position", base_pos + Vector2(-6, 2), 0.04)
	tw.chain().tween_property(medal, "modulate", base_mod, 0.08)
	tw.tween_property(medal, "position", base_pos + Vector2(5, -2), 0.04)
	tw.tween_property(medal, "position", base_pos + Vector2(-3, 1), 0.04)
	tw.tween_property(medal, "position", base_pos, 0.05)
