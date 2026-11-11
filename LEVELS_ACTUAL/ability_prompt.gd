extends Control
@export var shield_cooldown := 20.0
@export var ammo_cooldown := 20.0
@export var beacon_cooldown := 15.0
@export var max_factor := 5
@export var locked_alpha := 0.5
@export var shield_icon: Texture2D
@export var ammo_icon: Texture2D
@export var beacon_icon: Texture2D
@export var nag_every := 2.2
@export var reload_right_lock := 2.0
@export var reload_wrong_lock := 2
@onready var ability_button: TextureButton = get_node_or_null("AbilityButton")
@onready var reload_button: TextureButton = get_node_or_null("ReloadButton")
@onready var question: Label = get_node_or_null("Question")
@onready var question_box: CanvasItem = get_node_or_null("QuestionBox")
var _cd := 0.0
var _cd_max := 20.0
var _correct := 0
var _prompting := false
var _was_ready := true
var _flash_tw: Tween
var _reload_flash: Tween
var _nag_t := 0.8
var _base_rot := 0.0
var _mode := "ability"
var _reload_lock := 0.0
var _reload_was_locked := false
func _ready() -> void:
	if question:
		question.visible = false
	if question_box:
		question_box.visible = false
	for i in 2:
		var ans := get_node_or_null("Answer%d" % i)
		if ans:
			ans.visible = false
	if ability_button:
		ability_button.pressed.connect(_on_ability_pressed)
		_base_rot = ability_button.rotation
	if reload_button:
		reload_button.pressed.connect(_on_reload_pressed)
	for i in 2:
		var btn := get_node_or_null("Answer%d" % i) as BaseButton
		if btn:
			var idx := i
			btn.pressed.connect(func() -> void: _pick(idx))
	_apply_icon()
	_refresh()
func _process(delta: float) -> void:
	if _reload_lock > 0.0:
		_reload_lock = maxf(0.0, _reload_lock - delta)
		_reload_was_locked = true
	elif _reload_was_locked:
		_reload_was_locked = false
		_flash_reload()
	if PlayerData.ability_busy():
		_nag_t = nag_every
		_refresh()
		return
	if _cd > 0.0:
		_cd = maxf(0.0, _cd - delta)
		if _cd <= 0.0 and not _was_ready:
			_flash_ready()
	elif _can_use():
		_nag_t -= delta
		if _nag_t <= 0.0:
			_nag_t = nag_every
			_flash_ready()
	_refresh()
func _apply_icon() -> void:
	if ability_button == null:
		return
	var tex: Texture2D = shield_icon
	match PlayerData.selected_ability:
		"ammo":
			tex = ammo_icon
		"beacon":
			tex = beacon_icon
		_:
			tex = shield_icon
	if tex:
		ability_button.texture_normal = tex
		ability_button.texture_pressed = tex
		ability_button.texture_hover = tex
		ability_button.texture_disabled = tex
func _cooldown_for(id: String) -> float:
	match id:
		"ammo":
			return ammo_cooldown
		"beacon":
			return beacon_cooldown
		_:
			return shield_cooldown
func _can_use() -> bool:
	return _cd <= 0.0 and not PlayerData.ability_busy() and not _prompting
func _on_ability_pressed() -> void:
	if _prompting:
		_cancel()
		return
	if not _can_use():
		return
	_mode = "ability"
	_open_prompt()
func _on_reload_pressed() -> void:
	if _prompting:
		_cancel()
		return
	if _reload_lock > 0.0:
		return
	_mode = "reload"
	_open_prompt()
func _cancel() -> void:
	_hide_prompt()
	_prompting = false
	if _mode == "ability":
		_fail()
	else:
		_do_wrong_reload()
func _open_prompt() -> void:
	_prompting = true
	_refresh()
	var a := randi_range(1, max_factor)
	var b := randi_range(1, max_factor)
	if _mode == "reload":
		_correct = a + b
		if question:
			question.text = "%d + %d = ?" % [a, b]
	else:
		_correct = a * b
		if question:
			question.text = "%d × %d = ?" % [a, b]
	var opts: Array[int] = [_correct]
	while opts.size() < 2:
		var fake: int = _correct + randi_range(-4, 4)
		if fake < 1 or opts.has(fake):
			continue
		opts.append(fake)
	opts.shuffle()
	for i in 2:
		var btn := get_node_or_null("Answer%d" % i)
		if btn == null:
			continue
		var lbl := btn.get_node_or_null("Label") as Label
		if lbl:
			lbl.text = str(opts[i])
		btn.set_meta("value", opts[i])
	_show_prompt()
	_dim_other()
func _show_prompt() -> void:
	if question:
		question.visible = true
	if question_box:
		question_box.visible = true
	for i in 2:
		var ans := get_node_or_null("Answer%d" % i)
		if ans:
			ans.visible = true
func _hide_prompt() -> void:
	if question:
		question.visible = false
	if question_box:
		question_box.visible = false
	for i in 2:
		var ans := get_node_or_null("Answer%d" % i)
		if ans:
			ans.visible = false
	_undim()
func _dim_other() -> void:
	if _mode == "ability" and reload_button:
		reload_button.modulate = Color(1, 1, 1, locked_alpha)
	elif _mode == "reload" and ability_button:
		ability_button.modulate = Color(1, 1, 1, locked_alpha)
func _undim() -> void:
	if reload_button and _reload_lock <= 0.0:
		reload_button.modulate = Color.WHITE
	if ability_button and not (_flash_tw and _flash_tw.is_running()):
		ability_button.modulate = Color.WHITE
func _pick(i: int) -> void:
	if not _prompting:
		return
	var btn := get_node_or_null("Answer%d" % i)
	if btn == null:
		return
	var val := int(btn.get_meta("value"))
	_hide_prompt()
	_prompting = false
	if val == _correct:
		_success()
	else:
		_fail()
func _success() -> void:
	if _mode == "ability":
		print("deploy ", PlayerData.selected_ability)
		match PlayerData.selected_ability:
			"shield":
				PlayerData.spawn_shield()
			"beacon":
				PlayerData.spawn_beacon()
			"ammo":
				PlayerData.spawn_ammo()
		_start_cooldown()
	else:
		_do_right_reload()
func _fail() -> void:
	if _mode == "ability":
		_wrong_fx()
		_start_cooldown()
	else:
		_do_wrong_reload()
func _do_right_reload() -> void:
	_reload_lock = reload_right_lock
	if reload_button:
		reload_button.modulate = Color(1, 1, 1, locked_alpha)
	var hud := get_tree().current_scene
	if hud != null and hud.has_method("request_reload"):
		hud.request_reload()
func _do_wrong_reload() -> void:
	_reload_lock = reload_wrong_lock
	_reload_wrong_fx()
func _reload_wrong_fx() -> void:
	if reload_button == null:
		return
	if _reload_flash:
		_reload_flash.kill()
	reload_button.rotation = 0.0
	reload_button.modulate = Color(1.0, 0.25, 0.25)
	_reload_flash = create_tween()
	_reload_flash.tween_property(reload_button, "rotation", 0.08, 0.05)
	_reload_flash.tween_property(reload_button, "rotation", -0.08, 0.06)
	_reload_flash.tween_property(reload_button, "rotation", 0.05, 0.05)
	_reload_flash.tween_property(reload_button, "rotation", 0.0, 0.06)
	_reload_flash.parallel().tween_property(reload_button, "modulate", Color(1, 1, 1, locked_alpha), 0.22)
func _wrong_fx() -> void:
	if ability_button == null:
		return
	if _flash_tw:
		_flash_tw.kill()
	ability_button.rotation = _base_rot
	ability_button.modulate = Color(1.0, 0.25, 0.25)
	_flash_tw = create_tween()
	_flash_tw.tween_property(ability_button, "rotation", _base_rot + 0.08, 0.05)
	_flash_tw.tween_property(ability_button, "rotation", _base_rot - 0.08, 0.06)
	_flash_tw.tween_property(ability_button, "rotation", _base_rot + 0.05, 0.05)
	_flash_tw.tween_property(ability_button, "rotation", _base_rot, 0.06)
	_flash_tw.parallel().tween_property(ability_button, "modulate", Color(1, 1, 1, locked_alpha), 0.22)
func _start_cooldown() -> void:
	_cd_max = _cooldown_for(PlayerData.selected_ability)
	_cd = _cd_max
	_was_ready = false
	_nag_t = nag_every
	_refresh()
func _flash_ready() -> void:
	_was_ready = true
	if ability_button == null:
		return
	if _flash_tw:
		_flash_tw.kill()
	ability_button.modulate = Color.WHITE
	_flash_tw = create_tween()
	_flash_tw.tween_property(ability_button, "modulate", Color(2.4, 2.4, 2.4), 0.08)
	_flash_tw.tween_property(ability_button, "modulate", Color.WHITE, 0.10)
	_flash_tw.tween_property(ability_button, "modulate", Color(2.4, 2.4, 2.4), 0.08)
	_flash_tw.tween_property(ability_button, "modulate", Color.WHITE, 0.12)
func _flash_reload() -> void:
	if reload_button == null:
		return
	if _reload_flash:
		_reload_flash.kill()
	reload_button.modulate = Color.WHITE
	_reload_flash = create_tween()
	_reload_flash.tween_property(reload_button, "modulate", Color(2.4, 2.4, 2.4), 0.07)
	_reload_flash.tween_property(reload_button, "modulate", Color.WHITE, 0.10)
func _refresh() -> void:
	_apply_icon()
	if ability_button == null:
		return
	var is_ready := _can_use()
	ability_button.disabled = not is_ready and not _prompting
	if reload_button:
		reload_button.disabled = _reload_lock > 0.0 or _prompting
	if _flash_tw and _flash_tw.is_running():
		return
	if is_ready or _prompting:
		if not (_mode == "reload" and _prompting):
			ability_button.modulate = Color.WHITE
		return
	var u := 0.0
	if _cd_max > 0.0:
		u = 1.0 - clampf(_cd / _cd_max, 0.0, 1.0)
	var a := lerpf(locked_alpha, 1.0, u)
	if PlayerData.ability_busy():
		a = locked_alpha
	ability_button.modulate = Color(1, 1, 1, a)
