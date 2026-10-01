extends Control

@onready var slider: HSlider = $MusicSlider
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
	if confirm:
		confirm.visible = false
	get_tree().paused = false
	Music.play_hub()   # or play_main_menu() if this menu uses that track

func _on_vol(v: float) -> void:
	Music.set_volume(v)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://MainMenu.tscn")
