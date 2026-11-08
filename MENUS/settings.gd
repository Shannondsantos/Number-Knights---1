extends Control
@onready var slider: HSlider = $MusicSlider
@onready var volume_slider: HSlider = $VolumeSlider
@onready var confirm: Control = $ResetConfirm
func _ready() -> void:
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	var v := 1.0
	if "music_volume" in PlayerData:
		v = clampf(float(PlayerData.music_volume), 0.0, 1.0)
	slider.value = v
	slider.value_changed.connect(_on_vol)
	Music.set_volume(v)
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.01
	volume_slider.value = PlayerData.sfx_volume
	volume_slider.value_changed.connect(_on_sfx)
	if confirm:
		confirm.visible = false
	get_tree().paused = false
	Music.play_hub()
func _on_vol(v: float) -> void:
	Music.set_volume(v)
func _on_sfx(v: float) -> void:
	PlayerData.set_sfx_volume(v)
func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://MainMenu.tscn")
