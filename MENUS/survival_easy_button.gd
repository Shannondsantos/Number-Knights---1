extends TextureButton
@export var next_scene: String = ""
@export var trial_id := "easy"
@export var bronze_at := 10
@export var iron_at := 20
@export var gold_at := 40
@export var diamond_at := 50
@onready var bronze: CanvasItem = get_node_or_null("Bronze")
@onready var iron: CanvasItem = get_node_or_null("Iron")
@onready var gold: CanvasItem = get_node_or_null("Gold")
@onready var diamond: CanvasItem = get_node_or_null("Diamond")
var _base := Color.WHITE
var _flashing := false
var _wait := 0.6
func _ready() -> void:
	_base = modulate
	_apply_medals()
func _apply_medals() -> void:
	var wave := PlayerData.survival_wave(trial_id)
	if bronze:
		bronze.visible = wave >= bronze_at
	if iron:
		iron.visible = wave >= iron_at
	if gold:
		gold.visible = wave >= gold_at
	if diamond:
		diamond.visible = wave >= diamond_at
func _process(delta: float) -> void:
	if not _flashing or disabled:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_pulse()
func _pulse() -> void:
	_wait = 1.4
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(2.6, 2.6, 2.6, _base.a), 0.07)
	tw.tween_property(self, "modulate", _base, 0.09)
	tw.tween_property(self, "modulate", Color(2.6, 2.6, 2.6, _base.a), 0.07)
	tw.tween_property(self, "modulate", _base, 0.12)
func _pressed() -> void:
	if next_scene == "":
		return
	get_tree().change_scene_to_file(next_scene)
