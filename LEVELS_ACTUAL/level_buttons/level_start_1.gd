extends TextureButton
@export var level_id := 1
@export var next_scene: String = ""
@onready var lock_icon: CanvasItem = get_node_or_null("level_lock")
var _base := Color.WHITE
var _flashing := false
var _wait := 0.6
func _ready() -> void:
	_base = modulate
	_apply_lock()
	_flashing = PlayerData.cleared_levels.is_empty() and PlayerData.is_unlocked(level_id)
func _apply_lock() -> void:
	var open := PlayerData.is_unlocked(level_id)
	if lock_icon:
		lock_icon.visible = not open
	disabled = not open
	modulate.a = 1.0 if open else 0.55
	_base = modulate
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
	if not PlayerData.is_unlocked(level_id):
		return
	if next_scene == "":
		return
	PlayerData.current_level = level_id
	get_tree().change_scene_to_file(next_scene)
