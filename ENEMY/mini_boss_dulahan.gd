extends Control

signal parked
signal defeated
signal failed_answer
@export var heli_loop: AudioStream
@export var max_hp: int = 20
@export var points: int = 40
@export var contact_damage: int = 1
@export var fly_time := 7.0
@export var travel_distance := 500.0
@export var stormtrooper_scene: PackedScene
@export var spawn_min := 10.0
@export var spawn_max := 15.0
@export var regen_time := 2.0
@export var trooper_distance := 160.0
@export var hull_tex_100: Texture2D
@export var hull_tex_75: Texture2D
@export var hull_tex_50: Texture2D
@export var hull_tex_25: Texture2D
@export var hull_tex_10: Texture2D
@export var dead_texture: Texture2D
@export var death_effect: PackedScene
@export var main_frames: Array[Texture2D] = []
@export var main_flip := 0.07
@export var rear_spin := 14.0
@export var hurt_wobble_move := 10.0
@export var hurt_wobble_rot := 0.07
@export var arrive_sound: AudioStream
@export var correct_sound: AudioStream
@export var wrong_sound: AudioStream
@export var death_sound: AudioStream

@onready var hull: TextureRect = get_node_or_null("Hull")
@onready var led: Label = get_node_or_null("LED")
@onready var answers: Control = get_node_or_null("Answers")
@onready var nav_light: TextureRect = get_node_or_null("Attack_Indicator")
@onready var shield: TextureRect = get_node_or_null("Shield")
@onready var health_bar: Control = get_node_or_null("Health")
@onready var main_rotor: TextureRect = get_node_or_null("MainRotor")
@onready var rear_rotor: TextureRect = get_node_or_null("RearRotor")
var _heli: AudioStreamPlayer
var hp: int = 15
var _alive := true
var _parked := false
var _correct := ">"
var _park := Vector2.ZERO
var _park_global := Vector2.ZERO
var _sfx: AudioStreamPlayer
var _flash_left := 0.0
var _hull_mod := Color.WHITE
var _hull_home := Vector2.ZERO
var _hull_rot := 0.0
var _spawn_cd := 0.0
var _regen_cd := 2.0
var _slot := 0
var _shield_tw: Tween
var _shield_up := false
var _hp_fill: Control
var _hp_fill_w := 0.0
var _hp_tw: Tween
var _seen: Array[String] = []
var _flip_t := 0.0
var _frame := 0

func _ready() -> void:
	add_to_group("minibosses")
	add_to_group("enemies")
	hp = max_hp
	if hull:
		_hull_mod = hull.modulate
		_hull_home = hull.position
		_hull_rot = hull.rotation
		hull.pivot_offset = hull.size * 0.5
		if hull_tex_100 == null:
			hull_tex_100 = hull.texture
		hull.texture = hull_tex_100
	if main_rotor:
		main_rotor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		main_rotor.pivot_offset = main_rotor.size * 0.5
		if main_frames.size() > 0 and main_frames[0]:
			main_rotor.texture = main_frames[0]
	if rear_rotor:
		rear_rotor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rear_rotor.pivot_offset = rear_rotor.size * 0.5
	_setup_health_bar()
	_hide_shield()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if answers:
		answers.visible = false
		for i in 3:
			var btn := answers.get_node_or_null("Answer%d" % i) as BaseButton
			if btn:
				var idx := i
				btn.pressed.connect(func() -> void: _pick(idx))
	if nav_light:
		nav_light.modulate.a = 0.2
	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)
	_heli = AudioStreamPlayer.new()
	_heli.name = "HeliLoop"
	add_child(_heli)
	if heli_loop:
		if heli_loop is AudioStreamWAV:
			heli_loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_heli.stream = heli_loop
		_heli.play()
	call_deferred("_begin_approach")

func _setup_health_bar() -> void:
	if health_bar == null:
		return
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := health_bar.get_node_or_null("Fill")
	_hp_fill = fill if fill is Control else health_bar
	_hp_fill_w = _hp_fill.size.x
	_refresh_health_bar(false)

func _refresh_health_bar(animate: bool = true) -> void:
	if _hp_fill == null:
		return
	var ratio := clampf(float(hp) / float(maxi(max_hp, 1)), 0.0, 1.0)
	var target := Vector2(_hp_fill_w * ratio, _hp_fill.size.y)
	if not animate:
		_hp_fill.size = target
		return
	if _hp_tw:
		_hp_tw.kill()
	_hp_tw = _hp_fill.create_tween()
	_hp_tw.tween_property(_hp_fill, "size", target, 0.15).set_trans(Tween.TRANS_SINE)

func _hide_shield() -> void:
	if shield == null:
		return
	shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shield.visible = false
	shield.modulate.a = 0.0
	_shield_up = false

func contains_point(screen_pos: Vector2) -> bool:
	return hull != null and hull.get_global_rect().has_point(screen_pos)

func receive_shot() -> void:
	_pulse_shield()

func _pulse_shield() -> void:
	if shield == null:
		return
	if _shield_tw:
		_shield_tw.kill()
	_shield_up = true
	shield.visible = true
	shield.modulate.a = 0.0
	_shield_tw = create_tween()
	_shield_tw.tween_property(shield, "modulate:a", 0.55, 0.08)
	_shield_tw.tween_property(shield, "modulate:a", 0.0, 0.35)
	_shield_tw.finished.connect(_hide_shield)

func _begin_approach() -> void:
	if not _alive:
		return
	_park = position
	_park_global = global_position
	position = _park - Vector2(travel_distance, 0.0)
	_fly_in()

func _hurt_t() -> float:
	return 1.0 - float(hp) / float(maxi(max_hp, 1))

func _process(delta: float) -> void:
	if shield and not _shield_up:
		_hide_shield()
	if hull and _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			hull.modulate = _hull_mod
	if hull and _alive:
		var u := _hurt_t()
		var t := Time.get_ticks_msec() / 1000.0
		var m := u * u
		hull.position = _hull_home + Vector2(sin(t * 0.7) * hurt_wobble_move * m, sin(t * 0.5) * hurt_wobble_move * 0.6 * m)
		hull.rotation = _hull_rot + sin(t * 0.45) * hurt_wobble_rot * m
	if nav_light and _alive:
		nav_light.modulate.a = 0.18 + 0.82 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 1.6))
	_spin_rotors(delta)
	if not _alive or not _parked:
		return
	_regen_cd -= delta
	if _regen_cd <= 0.0:
		_regen_cd = regen_time
		if hp < max_hp:
			hp += 1
			_apply_hull_tex()
			_refresh_health_bar(true)
	_spawn_cd -= delta
	if _spawn_cd <= 0.0:
		_spawn_one()
		_spawn_cd = randf_range(spawn_min, spawn_max)

func _spin_rotors(delta: float) -> void:
	if not _alive:
		return
	if main_rotor and main_frames.size() > 0:
		_flip_t += delta
		if _flip_t >= main_flip:
			_flip_t = 0.0
			_frame = (_frame + 1) % main_frames.size()
			if main_frames[_frame]:
				main_rotor.texture = main_frames[_frame]
	if rear_rotor:
		rear_rotor.rotation += rear_spin * delta

func _apply_hull_tex() -> void:
	if hull == null:
		return
	var ratio := float(hp) / float(maxi(max_hp, 1))
	var tex := hull_tex_10
	if ratio > 0.75:
		tex = hull_tex_100
	elif ratio > 0.5:
		tex = hull_tex_75
	elif ratio > 0.25:
		tex = hull_tex_50
	elif ratio > 0.1:
		tex = hull_tex_25
	if tex:
		hull.texture = tex

func _fly_in() -> void:
	_parked = false
	_hide_shield()
	if led:
		led.text = ""
	var tw := create_tween()
	tw.tween_property(self, "position", _park, fly_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_on_parked)

func _on_parked() -> void:
	if not _alive:
		return
	_parked = true
	_hide_shield()
	_park = position
	_park_global = global_position
	_spawn_cd = randf_range(spawn_min, spawn_max)
	_regen_cd = regen_time
	_play_sfx(arrive_sound)
	var hud := _hud()
	if hud and answers and answers.get_parent() != hud:
		var gpos := answers.global_position
		answers.reparent(hud)
		answers.global_position = gpos
	if answers:
		answers.visible = true
		answers.mouse_filter = Control.MOUSE_FILTER_STOP
	_new_question()
	parked.emit()

func _slot_offset(i: int) -> Vector2:
	match i % 4:
		0:
			return Vector2(0, -trooper_distance)
		1:
			return Vector2(-trooper_distance, 0)
		2:
			return Vector2(0, trooper_distance)
		_:
			return Vector2(trooper_distance, 0)

func _spawn_one() -> void:
	if stormtrooper_scene == null:
		return
	_launch(stormtrooper_scene, _park_global, _park_global + _slot_offset(_slot), 0.45)
	_slot += 1

func _new_question() -> void:
	var hard := hp * 2 <= maxi(max_hp, 1)
	var lo := 0
	var hi := 9
	if hp <= 1:
		lo = 100
		hi = 180
	elif hard:
		lo = 10
		hi = 30
	var a := lo
	var b := lo
	var key := ""
	var found := false
	for _try in 40:
		a = randi_range(lo, hi)
		b = randi_range(lo, hi)
		if randf() < 0.28:
			b = a
		key = "%d_%d" % [a, b]
		if _seen.has(key):
			continue
		found = true
		break
	if not found:
		_seen.clear()
		a = randi_range(lo, hi)
		b = randi_range(lo, hi)
		key = "%d_%d" % [a, b]
	_seen.append(key)
	_correct = "="
	if a > b:
		_correct = ">"
	elif a < b:
		_correct = "<"
	if led:
		led.text = "%d _ %d" % [a, b]
	var opts: Array[String] = [">", "=", "<"]
	for i in 3:
		var btn := answers.get_node_or_null("Answer%d" % i)
		var lbl := answers.get_node_or_null("Answer%d/Label" % i) as Label
		if lbl:
			lbl.text = opts[i]
		if btn:
			btn.set_meta("value", opts[i])

func _pick(i: int) -> void:
	if not _alive or not _parked or answers == null:
		return
	var btn := answers.get_node_or_null("Answer%d" % i)
	if btn == null:
		return
	if str(btn.get_meta("value")) == _correct:
		_hit_boss()
	else:
		_wrong()

func _hit_boss() -> void:
	hp -= 1
	_play_sfx(correct_sound)
	_flash()
	_apply_hull_tex()
	_refresh_health_bar(true)
	_spawn_death_effect()
	if hp <= 0:
		_die()
		return
	_new_question()

func _wrong() -> void:
	_play_sfx(wrong_sound)
	failed_answer.emit()
	var hud := _hud()
	if hud and hud.has_method("apply_damage"):
		hud.apply_damage(contact_damage)
	_new_question()

func _flash() -> void:
	if hull == null:
		return
	_flash_left = 0.1
	hull.modulate = Color(2.4, 2.4, 2.4)

func _die() -> void:
	if _heli and _heli.playing:
		_heli.stop()
	if not _alive:
		return
	_alive = false
	_hide_shield()
	if health_bar:
		health_bar.visible = false
	if nav_light:
		nav_light.modulate.a = 0.0
	if answers:
		answers.visible = false
		answers.queue_free()
	_play_sfx(death_sound)
	PlayerData.currency += points
	PlayerData.save()
	defeated.emit()
	if hull and dead_texture:
		hull.texture = dead_texture
	for i in 3:
		_spawn_death_effect()
	_drop_rotors()
	_spawn_three()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", position.y + 1100.0, 4.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "rotation", rotation + 0.55, 4.2)
	tw.tween_property(self, "modulate:a", 0.0, 4.2)
	tw.chain().tween_callback(queue_free)

func _spawn_three() -> void:
	if stormtrooper_scene == null:
		return
	var origin := _park_global if _park_global != Vector2.ZERO else global_position
	_launch(stormtrooper_scene, origin, origin + Vector2(-140, 10), 0.6)
	_launch(stormtrooper_scene, origin, origin + Vector2(0, -20), 0.6)
	_launch(stormtrooper_scene, origin, origin + Vector2(140, 10), 0.6)

func _drop_rotors() -> void:
	var host := get_parent()
	if host == null:
		return
	for p in [main_rotor, rear_rotor]:
		if p == null or not is_instance_valid(p):
			continue
		var rotor := p as TextureRect
		var keep_pos: Vector2 = rotor.global_position
		var keep_rot: float = rotor.rotation
		rotor.reparent(host)
		rotor.global_position = keep_pos
		var drop: Tween = rotor.create_tween()
		drop.set_parallel(true)
		drop.tween_property(rotor, "position", rotor.position + Vector2(randf_range(-90, 90), 480), 1.3)
		drop.tween_property(rotor, "rotation", keep_rot + randf_range(-2.0, 2.0), 1.3)
		drop.tween_property(rotor, "modulate:a", 0.0, 1.3)
		drop.chain().tween_callback(rotor.queue_free)

func _launch(packed: PackedScene, from_global: Vector2, dest_global: Vector2, t: float) -> void:
	var n := packed.instantiate()
	var host := get_parent()
	if host == null:
		host = get_tree().current_scene
	host.add_child(n)
	if not n is Control:
		return
	n.global_position = from_global
	n.set("_base_pos", n.position)
	if n.has_method("begin_travel"):
		n.begin_travel()
	var tw := n.create_tween()
	tw.tween_property(n, "global_position", dest_global, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void:
		if is_instance_valid(n) and n.has_method("finish_travel"):
			n.finish_travel(n.position)
	)

func _spawn_death_effect() -> void:
	if death_effect == null:
		return
	var fx := death_effect.instantiate()
	var host := get_parent()
	if host == null:
		return
	host.add_child(fx)
	var mid := _park_global + Vector2(randf_range(-50, 50), randf_range(-30, 30))
	if fx.has_method("setup"):
		fx.setup(mid)
	else:
		fx.global_position = mid

func _play_sfx(stream: AudioStream) -> void:
	if _sfx == null or stream == null:
		return
	_sfx.stream = stream
	_sfx.play()

func _hud() -> Node:
	var n := get_tree().current_scene
	if n != null and n.has_method("apply_damage"):
		return n
	return null
