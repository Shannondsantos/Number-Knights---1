extends TextureButton
@export var next_scene: String = "res://MENUS/UpgradeMenu.tscn"
@export var flash_level := 2
var _base := Color.WHITE
var _flashing := false
var _wait := 0.6
func _ready() -> void:
	_base = modulate
	_flashing = PlayerData.is_unlocked(flash_level) and not _level_cleared(flash_level)
func _level_cleared(id: int) -> bool:
	for n in PlayerData.cleared_levels:
		if int(n) == id:
			return true
	return false
func _process(delta: float) -> void:
	if not _flashing:
		modulate = _base
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
	if next_scene.is_empty():
		return
	get_tree().change_scene_to_file(next_scene)
