extends Node

var main_menu: AudioStream = preload("res://Music_/Music_studiokolomna-risk-136788.mp3")
var hub: AudioStream = preload("res://Music_/Music_harumachimusic-faded-letter-127022.mp3")
var win_theme: AudioStream = preload("res://Music_/Music_cyreljayvillaro-victory-gold-star-award-267259.mp3")
var lose_theme: AudioStream = preload("res://Music_/Music_keyframe_audio-lose-track-134355.mp3")

var _player: AudioStreamPlayer
var _lock := false

func _ready() -> void:
	_ensure_player()

func play_main_menu() -> void:
	_lock = false
	_play(main_menu)

func play_hub() -> void:
	_lock = false
	_play(hub)

func play_level(stream: AudioStream, force: bool = false) -> void:
	if _lock and not force:
		return
	if force:
		_lock = false
	_play(stream)

func play_boss(stream: AudioStream) -> void:
	if _lock:
		return
	_play(stream)

func play_win() -> void:
	_lock = false
	_play(win_theme)
	_lock = true

func play_lose() -> void:
	_lock = false
	_play(lose_theme)
	_lock = true

func _ensure_player() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _player != null:
		return
	_player = AudioStreamPlayer.new()
	_player.name = "MusicPlayer"
	_player.bus = "Master"
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)
	_apply_volume()

func _play(stream: AudioStream) -> void:
	_ensure_player()
	if stream == null:
		push_error("Music stream is null — check preload paths")
		return
	_apply_volume()
	if _player.stream == stream and _player.playing:
		return
	_player.stream = stream
	_player.play()
	_player.bus = "Music"

func stop() -> void:
	_ensure_player()
	if _player.playing:
		_player.stop()
	_lock = false

func _apply_volume() -> void:
	_ensure_player()
	var v := 1.0
	if "music_volume" in PlayerData:
		v = clampf(float(PlayerData.music_volume), 0.0, 1.0)
	if v <= 0.001:
		_player.volume_db = -80.0
	else:
		_player.volume_db = linear_to_db(v)

func set_volume(linear: float) -> void:
	PlayerData.music_volume = clampf(linear, 0.0, 1.0)
	_apply_volume()
