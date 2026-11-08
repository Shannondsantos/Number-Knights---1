extends TextureRect
@export var nurse_assault_idle: Array[Texture2D] = []
@export var nurse_assault_shoot: Array[Texture2D] = []
@export var nurse_heavy_idle: Array[Texture2D] = []
@export var nurse_heavy_shoot: Array[Texture2D] = []
@export var nurse_scout_idle: Array[Texture2D] = []
@export var nurse_scout_shoot: Array[Texture2D] = []
@export var armor_assault_idle: Array[Texture2D] = []
@export var armor_assault_shoot: Array[Texture2D] = []
@export var armor_heavy_idle: Array[Texture2D] = []
@export var armor_heavy_shoot: Array[Texture2D] = []
@export var armor_scout_idle: Array[Texture2D] = []
@export var armor_scout_shoot: Array[Texture2D] = []
@export var hunter_assault_idle: Array[Texture2D] = []
@export var hunter_assault_shoot: Array[Texture2D] = []
@export var hunter_heavy_idle: Array[Texture2D] = []
@export var hunter_heavy_shoot: Array[Texture2D] = []
@export var hunter_scout_idle: Array[Texture2D] = []
@export var hunter_scout_shoot: Array[Texture2D] = []
@export var assault_idle: Array[Texture2D] = []
@export var assault_shoot: Array[Texture2D] = []
@export var heavy_idle: Array[Texture2D] = []
@export var heavy_shoot: Array[Texture2D] = []
@export var scout_idle: Array[Texture2D] = []
@export var scout_shoot: Array[Texture2D] = []
@export var assault_puff: Texture2D
@export var heavy_puff: Texture2D
@export var scout_puff: Texture2D
@export var puff_time := 0.28
@export var assault_shots: Array[AudioStream] = []
@export var heavy_shots: Array[AudioStream] = []
@export var scout_shot: AudioStream
@export var shoot_hold := 1.5
@export var breathe_amount := 0.012
@export var breathe_speed := 1.6
@export var shot_pitch_min := 0.82
@export var shot_pitch_max := 0.95
@onready var muzzle_assault: Node = get_node_or_null("Muzzle_Assault")
@onready var muzzle_heavy: Node = get_node_or_null("Muzzle_Heavy")
@onready var muzzle_scout: Node = get_node_or_null("Muzzle_Scout")
var shot_sound: AudioStreamPlayer
var _scout_loop: AudioStream
var _assault_i := 0
var _heavy_i := 0
var _base_scale := Vector2.ONE
var _base_rot := 0.0
var _shooting := false
var _hold_left := 0.0
var _tween: Tween
var _cooldown := 0.0
var _holding := false
var _flash_left := 0.0
var _base_mod := Color.WHITE
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base_scale = scale
	_base_rot = rotation
	_base_mod = modulate
	pivot_offset = size * Vector2(0.5, 0.92)
	shot_sound = get_node_or_null("ShotSound")
	if shot_sound == null:
		shot_sound = AudioStreamPlayer.new()
		shot_sound.name = "ShotSound"
		add_child(shot_sound)
	_prepare_scout_loop()
	_show_idle()
	add_to_group("player")
func _prepare_scout_loop() -> void:
	if scout_shot == null:
		return
	_scout_loop = scout_shot.duplicate()
	if _scout_loop is AudioStreamWAV:
		_scout_loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif _scout_loop is AudioStreamOggVorbis:
		_scout_loop.loop = true
func _input(event: InputEvent) -> void:
	var hover := get_viewport().gui_get_hovered_control()
	if hover is BaseButton:
		if event is InputEventMouseButton and not event.pressed:
			_holding = false
			_stop_scout_loop()
		if event is InputEventScreenTouch and not event.pressed:
			_holding = false
			_stop_scout_loop()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_holding = event.pressed
		if event.pressed:
			_try_shot()
		else:
			_stop_scout_loop()
	if event is InputEventScreenTouch:
		_holding = event.pressed
		if event.pressed:
			_try_shot()
		else:
			_stop_scout_loop()
func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
	if PlayerData.current_class == "scout" and _holding and _cooldown <= 0.0:
		_try_shot()
	if _flash_left > 0.0:
		_flash_left -= delta
		modulate = Color(2.6, 2.6, 2.6)
	elif PlayerData.beacon_time > 0.0:
		var pulse: float = 0.82 + 0.18 * absf(sin(Time.get_ticks_msec() / 1000.0 * 6.0))
		modulate = Color(0.92, 0.75, 1.0) * pulse
	else:
		modulate = _base_mod
	if _shooting:
		_hold_left -= delta
		if _hold_left <= 0.0 and not (PlayerData.current_class == "scout" and _holding):
			_shooting = false
			_show_idle()
		return
	var b := sin(Time.get_ticks_msec() / 1000.0 * breathe_speed) * breathe_amount
	scale = _base_scale * Vector2(1.0 + b, 1.0 - b)
func _fire_delay() -> float:
	var lvl := clampi(PlayerData.class_level(), 1, 5)
	match PlayerData.current_class:
		"heavy":
			return maxf(0.22, 0.50 - float(lvl - 1) * 0.06)
		"scout":
			return maxf(0.045, 0.09 - float(lvl - 1) * 0.01)
		_:
			return maxf(0.05, 0.14 - float(lvl - 1) * 0.018)
func _mk_index() -> int:
	return clampi(PlayerData.class_level(), 1, 5) - 1
func _idle_tex() -> Texture2D:
	var costume := PlayerData.equipped_costume
	var cls := PlayerData.current_class
	var lvl := _mk_index()
	if costume != "":
		var arr := _costume_idle(costume, cls)
		if arr.size() > lvl and arr[lvl]:
			return arr[lvl]
		if arr.size() > 0 and arr[0]:
			return arr[0]
	var normal := _normal_idle(cls)
	if normal.size() > lvl and normal[lvl]:
		return normal[lvl]
	return null
func _shoot_tex() -> Texture2D:
	var costume := PlayerData.equipped_costume
	var cls := PlayerData.current_class
	var lvl := _mk_index()
	if costume != "":
		var arr := _costume_shoot(costume, cls)
		if arr.size() > lvl and arr[lvl]:
			return arr[lvl]
		if arr.size() > 0 and arr[0]:
			return arr[0]
	var normal := _normal_shoot(cls)
	if normal.size() > lvl and normal[lvl]:
		return normal[lvl]
	return null
func _costume_idle(costume: String, cls: String) -> Array[Texture2D]:
	match costume:
		"nurse":
			match cls:
				"heavy": return nurse_heavy_idle
				"scout": return nurse_scout_idle
				_: return nurse_assault_idle
		"armor":
			match cls:
				"heavy": return armor_heavy_idle
				"scout": return armor_scout_idle
				_: return armor_assault_idle
		"hunter":
			match cls:
				"heavy": return hunter_heavy_idle
				"scout": return hunter_scout_idle
				_: return hunter_assault_idle
	return []
func _costume_shoot(costume: String, cls: String) -> Array[Texture2D]:
	match costume:
		"nurse":
			match cls:
				"heavy": return nurse_heavy_shoot
				"scout": return nurse_scout_shoot
				_: return nurse_assault_shoot
		"armor":
			match cls:
				"heavy": return armor_heavy_shoot
				"scout": return armor_scout_shoot
				_: return armor_assault_shoot
		"hunter":
			match cls:
				"heavy": return hunter_heavy_shoot
				"scout": return hunter_scout_shoot
				_: return hunter_assault_shoot
	return []
func _normal_idle(cls: String) -> Array[Texture2D]:
	match cls:
		"heavy": return heavy_idle
		"scout": return scout_idle
		_: return assault_idle
func _normal_shoot(cls: String) -> Array[Texture2D]:
	match cls:
		"heavy": return heavy_shoot
		"scout": return scout_shoot
		_: return assault_shoot
func _show_idle() -> void:
	var tex := _idle_tex()
	if tex:
		texture = tex
	scale = _base_scale
	rotation = _base_rot
func _show_shoot() -> void:
	var tex := _shoot_tex()
	if tex:
		texture = tex
func _hud() -> Node:
	var n := get_tree().current_scene
	if n != null and n.has_method("try_fire"):
		return n
	return get_tree().root.get_node_or_null("Game")
func _hits(e: Node, screen_pos: Vector2) -> bool:
	if not (e is Control) or not bool(e.get("_alive")):
		return false
	if e.has_method("contains_point"):
		return e.contains_point(screen_pos)
	return e.get_global_rect().has_point(screen_pos)
func _enemy_at(screen_pos: Vector2) -> Node:
	for e in get_tree().get_nodes_in_group("projectiles"):
		if _hits(e, screen_pos):
			return e
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_in_group("projectiles"):
			continue
		if e.is_in_group("minibosses") or e.is_in_group("bosses"):
			continue
		if _hits(e, screen_pos):
			return e
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_in_group("minibosses") or e.is_in_group("bosses"):
			if _hits(e, screen_pos):
				return e
	return null
func _try_shot() -> void:
	if _cooldown > 0.0:
		return
	var hud := _hud()
	if hud != null and hud.has_method("try_fire"):
		if not hud.try_fire():
			_stop_scout_loop()
			return
	_cooldown = _fire_delay()
	_shooting = true
	_hold_left = shoot_hold
	_show_shoot()
	_play_shot()
	_recoil()
	_spawn_muzzle_puff()
	_hit_all_under(get_global_mouse_position())
func _muzzle_for() -> Node:
	match PlayerData.current_class:
		"heavy":
			return muzzle_heavy
		"scout":
			return muzzle_scout
		_:
			return muzzle_assault
func _puff_tex_for() -> Texture2D:
	match PlayerData.current_class:
		"heavy":
			return heavy_puff
		"scout":
			return scout_puff
		_:
			return assault_puff
func _spawn_muzzle_puff() -> void:
	var tex := _puff_tex_for()
	if tex == null:
		return
	var host: Node = get_parent()
	if host == null:
		host = self
	var puff := TextureRect.new()
	puff.texture = tex
	puff.mouse_filter = Control.MOUSE_FILTER_IGNORE
	puff.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	puff.size = tex.get_size()
	puff.pivot_offset = puff.size * 0.5
	host.add_child(puff)
	var pos := global_position
	var mz := _muzzle_for()
	if mz:
		if mz is Node2D:
			pos = (mz as Node2D).global_position
		elif mz is Control:
			pos = (mz as Control).global_position
	puff.global_position = pos - puff.pivot_offset
	puff.rotation = randf_range(-PI, PI)
	puff.scale = Vector2(0.25, 0.25)
	puff.modulate.a = 0.95
	var tw := puff.create_tween()
	tw.set_parallel(true)
	tw.tween_property(puff, "scale", Vector2(1.15, 1.15), puff_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(puff, "modulate:a", 0.0, puff_time)
	tw.tween_property(puff, "rotation", puff.rotation + randf_range(-0.4, 0.4), puff_time)
	tw.chain().tween_callback(puff.queue_free)
func _cycle(list: Array[AudioStream], idx: int) -> Array:
	if list.is_empty():
		return [null, idx]
	var i := idx % list.size()
	var s: AudioStream = list[i]
	while s == null and list.size() > 1:
		i = (i + 1) % list.size()
		s = list[i]
		if i == idx % list.size():
			break
	return [s, (i + 1) % list.size()]
func _play_shot() -> void:
	if shot_sound == null:
		return
	match PlayerData.current_class:
		"heavy":
			var pack: Array = _cycle(heavy_shots, _heavy_i)
			if pack[0] == null:
				return
			_heavy_i = pack[1]
			shot_sound.stream = pack[0]
			shot_sound.pitch_scale = randf_range(shot_pitch_min, shot_pitch_max)
			shot_sound.play()
		"scout":
			if _scout_loop == null:
				return
			if shot_sound.stream != _scout_loop or not shot_sound.playing:
				shot_sound.stream = _scout_loop
				shot_sound.pitch_scale = 1.0
				shot_sound.play()
		_:
			var pack: Array = _cycle(assault_shots, _assault_i)
			if pack[0] == null:
				return
			_assault_i = pack[1]
			shot_sound.stream = pack[0]
			shot_sound.pitch_scale = randf_range(shot_pitch_min, shot_pitch_max)
			shot_sound.play()
func _stop_scout_loop() -> void:
	if shot_sound != null and shot_sound.playing and PlayerData.current_class == "scout":
		shot_sound.stop()
func _recoil() -> void:
	if _tween:
		_tween.kill()
	scale = _base_scale
	rotation = _base_rot
	_tween = create_tween()
	_tween.set_parallel(true)
	match PlayerData.current_class:
		"heavy":
			_recoil_heavy()
		"scout":
			_recoil_scout()
		_:
			_recoil_assault()
func _recoil_assault() -> void:
	_tween.tween_property(self, "scale", _base_scale * Vector2(1.03, 0.97), 0.05)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", _base_scale, 0.12)\
		.set_delay(0.05).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "rotation", _base_rot - 0.03, 0.05)
	_tween.tween_property(self, "rotation", _base_rot + 0.015, 0.08).set_delay(0.05)
	_tween.tween_property(self, "rotation", _base_rot, 0.12).set_delay(0.13)
func _recoil_heavy() -> void:
	_tween.tween_property(self, "scale", _base_scale * Vector2(1.10, 0.88), 0.07)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", _base_scale, 0.20)\
		.set_delay(0.07).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "rotation", _base_rot - 0.09, 0.07)
	_tween.tween_property(self, "rotation", _base_rot + 0.04, 0.10).set_delay(0.07)
	_tween.tween_property(self, "rotation", _base_rot, 0.16).set_delay(0.17)
func _recoil_scout() -> void:
	_tween.tween_property(self, "scale", _base_scale * Vector2(0.99, 1.05), 0.04)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", _base_scale * Vector2(1.01, 0.98), 0.05).set_delay(0.04)
	_tween.tween_property(self, "scale", _base_scale, 0.06).set_delay(0.09)
	_tween.tween_property(self, "rotation", _base_rot + 0.012, 0.04)
	_tween.tween_property(self, "rotation", _base_rot - 0.008, 0.05).set_delay(0.04)
	_tween.tween_property(self, "rotation", _base_rot, 0.06).set_delay(0.09)
func flash_hit() -> void:
	_flash_left = 0.12
	modulate = Color(2.6, 2.6, 2.6)
func _hit_all_under(screen_pos: Vector2) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if not bool(e.get("_alive")):
			continue
		if not _hits(e, screen_pos):
			continue
		if e.has_method("receive_shot"):
			e.receive_shot()
