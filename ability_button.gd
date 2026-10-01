extends TextureButton

@export var shield_cooldown := 20.0
@export var ammo_cooldown := 20.0
@export var beacon_cooldown := 15.0
@export var prompt: Control
@export var max_factor := 5
@export var locked_alpha := 0.2
@export var shield_icon: Texture2D
@export var ammo_icon: Texture2D
@export var beacon_icon: Texture2D

var _cd := 0.0
var _cd_max := 20.0
var _correct := 0
var _prompting := false
var _was_ready := true
var _flash_tw: Tween

func _ready() -> void:
	pressed.connect(_on_pressed)
	_cd = 0.0
	_apply_icon()
	if prompt:
		prompt.visible = false
		for i in 2:
			var btn := prompt.get_node_or_null("Answer%d" % i) as BaseButton
			if btn:
				var idx := i
				btn.pressed.connect(func() -> void: _pick(idx))
	_refresh()

func _process(delta: float) -> void:
	if PlayerData.ability_busy() or _prompting:
		_refresh()
		return
	if _cd > 0.0:
		_cd = maxf(0.0, _cd - delta)
		if _cd <= 0.0 and not _was_ready:
			_flash_ready()
	_refresh()

func _apply_icon() -> void:
	var tex: Texture2D = shield_icon
	match PlayerData.selected_ability:
		"ammo":
			tex = ammo_icon
		"beacon":
			tex = beacon_icon
		_:
			tex = shield_icon
	if tex:
		texture_normal = tex
		texture_pressed = tex
		texture_hover = tex
		texture_disabled = tex

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

func _on_pressed() -> void:
	if not _can_use():
		return
	_open_prompt()

func _open_prompt() -> void:
	_prompting = true
	_refresh()
	if prompt == null:
		_success()
		return
	var a := randi_range(1, max_factor)
	var b := randi_range(1, max_factor)
	_correct = a * b
	var q := prompt.get_node_or_null("Question") as Label
	if q:
		q.text = "%d × %d = ?" % [a, b]
	var opts: Array[int] = [_correct]
	while opts.size() < 2:
		var fake: int = _correct + randi_range(-4, 4)
		if fake < 1 or opts.has(fake):
			continue
		opts.append(fake)
	opts.shuffle()
	for i in 2:
		var btn := prompt.get_node_or_null("Answer%d" % i)
		if btn == null:
			continue
		var lbl := btn.get_node_or_null("Label") as Label
		if lbl:
			lbl.text = str(opts[i])
		btn.set_meta("value", opts[i])
	prompt.visible = true

func _pick(i: int) -> void:
	if not _prompting:
		return
	var btn := prompt.get_node_or_null("Answer%d" % i)
	if btn == null:
		return
	var val := int(btn.get_meta("value"))
	prompt.visible = false
	_prompting = false
	if val == _correct:
		_success()
	else:
		_fail()

func _success() -> void:
	print("deploy ", PlayerData.selected_ability)
	match PlayerData.selected_ability:
		"shield":
			PlayerData.spawn_shield()
		"beacon":
			PlayerData.spawn_beacon()
		"ammo":
			PlayerData.spawn_ammo()
	_start_cooldown()

func _fail() -> void:
	_start_cooldown()

func _start_cooldown() -> void:
	_cd_max = _cooldown_for(PlayerData.selected_ability)
	_cd = _cd_max
	_was_ready = false
	_refresh()

func _flash_ready() -> void:
	_was_ready = true
	if _flash_tw:
		_flash_tw.kill()
	modulate = Color.WHITE
	_flash_tw = create_tween()
	_flash_tw.tween_property(self, "modulate", Color(2.4, 2.4, 2.4), 0.08)
	_flash_tw.tween_property(self, "modulate", Color.WHITE, 0.10)
	_flash_tw.tween_property(self, "modulate", Color(2.4, 2.4, 2.4), 0.08)
	_flash_tw.tween_property(self, "modulate", Color.WHITE, 0.12)

func _refresh() -> void:
	_apply_icon()
	var is_ready := _can_use()
	disabled = not is_ready
	if is_ready:
		if _flash_tw == null or not _flash_tw.is_running():
			modulate = Color.WHITE
		return
	var u := 0.0
	if _cd_max > 0.0:
		u = 1.0 - clampf(_cd / _cd_max, 0.0, 1.0)
	var a := lerpf(locked_alpha, 1.0, u)
	if PlayerData.ability_busy() or _prompting:
		a = locked_alpha
	modulate = Color(1, 1, 1, a)
