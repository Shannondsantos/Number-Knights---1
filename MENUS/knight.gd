extends TextureButton

@export var level_id := 1
@export var next_scene: String = ""
@export var trial_id := "knight"
@export var bronze_at := 10
@export var iron_at := 25
@export var gold_at := 40
@export var diamond_at := 50

@onready var lock_icon: CanvasItem = get_node_or_null("level_lock")
@onready var bronze: CanvasItem = get_node_or_null("Bronze")
@onready var iron: CanvasItem = get_node_or_null("Iron")
@onready var gold: CanvasItem = get_node_or_null("Gold")
@onready var diamond: CanvasItem = get_node_or_null("Diamond")

func _ready() -> void:
	_apply_lock()
	_apply_medals()

func _apply_lock() -> void:
	var open := PlayerData.is_unlocked(level_id)
	if lock_icon:
		lock_icon.visible = not open
	disabled = not open
	modulate.a = 1.0 if open else 0.55

func _apply_medals() -> void:
	var wave := 0
	if PlayerData.has_method("time_trial_wave"):
		wave = PlayerData.time_trial_wave(trial_id)
	if bronze:
		bronze.visible = wave >= bronze_at
	if iron:
		iron.visible = wave >= iron_at
	if gold:
		gold.visible = wave >= gold_at
	if diamond:
		diamond.visible = wave >= diamond_at

func _pressed() -> void:
	if not PlayerData.is_unlocked(level_id):
		return
	if next_scene == "":
		return
	PlayerData.current_level = level_id
	get_tree().change_scene_to_file(next_scene)
