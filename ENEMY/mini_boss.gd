extends Control

signal parked
signal defeated
signal failed_answer

@export var max_hp: int = 10
@export var points: int = 30
@export var contact_damage: int = 1
@export var max_addend := 9
@export var fly_time := 7.0
@export var travel_distance := 500.0

@export var officer_scene: PackedScene
@export var drone_scene: PackedScene
@export var escort_spread := 90.0
@export var escort_travel := 0.7
@export var drone_distance := 180.0
@export var drone_interval_min := 3.0
@export var drone_interval_max := 4.0

@export var hull_tex_100: Texture2D
@export var hull_tex_50: Texture2D
@export var hull_tex_25: Texture2D

@export var prop_wiggle := 0.16
@export var prop_wiggle_speed := 3.5
@export var hurt_wobble_move := 10.0
@export var hurt_wobble_rot := 0.07

@export var death_effect: PackedScene
@export var dead_texture: Texture2D
@export var arrive_sound: AudioStream
@export var correct_sound: AudioStream
@export var wrong_sound: AudioStream
@export var death_sound: AudioStream
@export var hit_sound: AudioStream

@onready var hull: TextureRect = $Hull
@onready var led: Label = $LED
@onready var answers: Control = $Answers
@onready var nav_light: TextureRect = get_node_or_null("Attack_Indicator")
@onready var shield: TextureRect = get_node_or_null("Shield")
@onready var health_bar: Control = get_node_or_null("Health")

var hp: int = 4
var _alive := true
var _parked := false
var _invincible := true
var _correct := 0
var _park := Vector2.ZERO
var _park_global := Vector2.ZERO
var _sfx: AudioStreamPlayer
var _flash_left := 0.0
var _hull_mod := Color.WHITE
var _hull_home := Vector2.ZERO
var _hull_rot := 0.0
var _drone_cd := 0.0
var _drone_slot := 0
var _parked_time := 0.0
var _shield_tw: Tween
var _shield_up := false
var _hp_fill: Control
var _hp_fill_w := 0.0
var _hp_tw: Tween
var _seen: Array[String] = []
var _props: Array[TextureRect] = []
var _prop_base_rot: Array[float] = []
var _prop_park_rot: Array[float] = []
var _prop_phase: Array[float] = []
var _prop_spd: Array[float] = []
var _prop_amp: Array[float] = []
var _prop_home: Array[Vector2] = []

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
	_setup_health_bar()
	_hide_shield()
	_collect_props()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if answers:
		answers.visible = false
	if nav_light:
		nav_light.modulate.a = 0.2
	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)
	if answers:
		for i in 3:
			var btn := answers.get_node("Answer%d" % i) as BaseButton
			var idx := i
			btn.pressed.connect(func() -> void: _pick(idx))
	call_deferred("_begin_approach")

func _setup_health_bar() -> void:
	if health_bar == null:
		return
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := health_bar.get_node_or_null("Fill")
	if fill is Control:
		_hp_fill = fill
	else:
		_hp_fill = health_bar
	_hp_fill_w = _hp_fill.size.x
	_refresh_health_bar(false)

func _refresh_health_bar(animate: bool = true) -> void:
	if _hp_fill == null:
		return
	var cap := maxi(max_hp, 1)
	var ratio := clampf(float(hp) / float(cap), 0.0, 1.0)
	var target := Vector2(_hp_fill_w * ratio, _hp_fill.size.y)
	if not animate:
		_hp_fill.size = target
		return
	if _hp_tw:
		_hp_tw.kill()
	_hp_tw = _hp_fill.create_tween()
	_hp_tw.tween_property(_hp_fill, "size", target, 0.15)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _hide_shield() -> void:
	if shield == null:
		shield = get_node_or_null("Shield")
	if shield == null:
		return
	shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shield.visible = false
	var sm := shield.modulate
	sm.a = 0.0
	shield.modulate = sm
	_shield_up = false

func contains_point(screen_pos: Vector2) -> bool:
	if hull and hull.get_global_rect().has_point(screen_pos):
		return true
	return false

func receive_shot() -> void:
	_pulse_shield()

func _pulse_shield() -> void:
	if shield == null:
		return
	if _shield_tw:
		_shield_tw.kill()
	_shield_up = true
	shield.visible = true
	var m := shield.modulate
	m.a = 0.0
	shield.modulate = m
	_shield_tw = create_tween()
	_shield_tw.tween_property(shield, "modulate:a", 0.55, 0.08)\
		.set_trans(Tween.TRANS_SINE)
	_shield_tw.tween_property(shield, "modulate:a", 0.0, 0.35)\
		.set_trans(Tween.TRANS_SINE)
	_shield_tw.finished.connect(_hide_shield)

func _begin_approach() -> void:
	if not _alive:
		return
	_hide_shield()
	_park = position
	_park_global = global_position
	position = _park - Vector2(travel_distance, 0.0)
	_fly_in()

func _collect_props() -> void:
	_props.clear()
	_prop_base_rot.clear()
	_prop_park_rot.clear()
	_prop_phase.clear()
	_prop_spd.clear()
	_prop_amp.clear()
	_prop_home.clear()
	for n in [get_node_or_null("Propeller"), get_node_or_null("Propeller2")]:
		if n is TextureRect:
			var p := n as TextureRect
			p.pivot_offset = p.size * 0.5
			p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_props.append(p)
			_prop_base_rot.append(p.rotation)
			_prop_park_rot.append(p.rotation - PI * 0.5)
			_prop_phase.append(randf() * TAU)
			_prop_spd.append(randf_range(0.7, 1.4))
			_prop_amp.append(randf_range(0.65, 1.35))
			_prop_home.append(p.position)

func _hurt_t() -> float:
	if max_hp <= 1:
		return 0.0
	return 1.0 - float(hp) / float(max_hp)

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
		hull.position = _hull_home + Vector2(
			sin(t * (0.55 + 0.35 * u)) * hurt_wobble_move * m,
			sin(t * (0.4 + 0.25 * u) + 1.2) * hurt_wobble_move * 0.7 * m
		)
		hull.rotation = _hull_rot + sin(t * (0.45 + 0.2 * u)) * hurt_wobble_rot * m
	if nav_light and _alive:
		var a := 0.18 + 0.82 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 1.6))
		var mcol := nav_light.modulate
		mcol.a = a
		nav_light.modulate = mcol
	if _alive and _parked:
		_parked_time += delta
		_wiggle_props()
		_drone_cd -= delta
		if _drone_cd <= 0.0:
			_spawn_fodder_wave()
			_drone_cd = randf_range(drone_interval_min, drone_interval_max)

func _wave_count() -> int:
	if _parked_time >= 30.0 and randf() < 0.5:
		return 2
	return 1

func _wiggle_props() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var panic := 1.0 + _hurt_t() * 0.7
	for i in _props.size():
		var p := _props[i]
		if p == null or not is_instance_valid(p):
			continue
		var ph := _prop_phase[i]
		var sp := _prop_spd[i] * panic
		var am := _prop_amp[i] * panic
		var w := sin(t * prop_wiggle_speed * sp + ph) * prop_wiggle * am
		w += sin(t * prop_wiggle_speed * sp * 1.9 + ph * 2.1) * prop_wiggle * 0.4 * am
		w += sin(t * 0.7 * sp + ph) * 0.03
		p.rotation = _prop_park_rot[i] + w
		var jx := sin(t * 2.3 * sp + ph) * 2.5 * am
		var jy := cos(t * 1.8 * sp + ph * 1.3) * 2.0 * am
		p.position = _prop_home[i] + Vector2(jx, jy)

func _apply_hull_tex() -> void:
	if hull == null:
		return
	var ratio := float(hp) / float(maxi(max_hp, 1))
	if ratio > 0.5:
		if hull_tex_100:
			hull.texture = hull_tex_100
	elif ratio > 0.25:
		if hull_tex_50:
			hull.texture = hull_tex_50
	else:
		if hull_tex_25:
			hull.texture = hull_tex_25

func _fly_in() -> void:
	_invincible = true
	_parked = false
	_hide_shield()
	if led:
		led.text = ""
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position", _park, fly_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for i in _props.size():
		_props[i].rotation = _prop_base_rot[i]
		tw.tween_property(_props[i], "rotation", _prop_park_rot[i], fly_time)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_callback(_on_parked)

func _on_parked() -> void:
	if not _alive:
		return
	_parked = true
	_invincible = true
	_hide_shield()
	_parked_time = 0.0
	_park = position
	_park_global = global_position
	_drone_cd = randf_range(drone_interval_min, drone_interval_max)
	_play_sfx(arrive_sound)
	var hud := _hud()
	if hud and answers and answers.get_parent() != hud:
		var gpos := answers.global_position
		answers.reparent(hud)
		answers.global_position = gpos
	if answers:
		answers.visible = true
		answers.mouse_filter = Control.MOUSE_FILTER_STOP
		for i in 3:
			var btn := answers.get_node("Answer%d" % i) as Control
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_new_question()
	parked.emit()

func _slot(i: int, dist: float) -> Vector2:
	match i % 4:
		0:
			return Vector2(0, -dist)
		1:
			return Vector2(-dist, 0)
		2:
			return Vector2(0, dist)
		_:
			return Vector2(dist, 0)

func _spawn_fodder_wave() -> void:
	if drone_scene == null:
		return
	var n := _wave_count()
	for k in n:
		_launch_unit(
			drone_scene,
			_park_global,
			_park_global + _slot(_drone_slot, drone_distance),
			0.45
		)
		_drone_slot += 1

func _new_question() -> void:
	var hard := hp * 2 <= maxi(max_hp, 1)
	var lo := 1
	var hi := 9
	if hard:
		lo = 10
		hi = 19
	var a := 1
	var b := 1
	var key := ""
	var found := false
	for _try in 50:
		a = randi_range(lo, hi)
		b = randi_range(lo, hi)
		if a == b:
			continue
		key = "%d+%d" % [a, b]
		if _seen.has(key):
			continue
		found = true
		break
	if not found:
		_seen.clear()
		a = randi_range(lo, hi)
		b = randi_range(lo, hi)
		if a == b:
			b = mini(hi, b + 1)
		key = "%d+%d" % [a, b]
	_seen.append(key)
	_correct = a + b
	if led:
		led.text = "%d + %d = ?" % [a, b]
	var opts: Array[int] = [_correct]
	while opts.size() < 3:
		var fake: int = _correct + randi_range(-6, 6)
		if fake < 2 or fake == _correct or opts.has(fake):
			continue
		opts.append(fake)
	opts.shuffle()
	for i in 3:
		var lbl := answers.get_node("Answer%d/Label" % i) as Label
		lbl.text = str(opts[i])
		answers.get_node("Answer%d" % i).set_meta("value", opts[i])

func _pick(i: int) -> void:
	if not _alive or not _parked:
		return
	var val := int(answers.get_node("Answer%d" % i).get_meta("value"))
	if val == _correct:
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
		_win()
		return
	_new_question()

func _wrong() -> void:
	_play_sfx(wrong_sound)
	failed_answer.emit()
	var hud := _hud()
	if hud != null and hud.has_method("apply_damage"):
		hud.apply_damage(contact_damage)
	_new_question()

func _flash() -> void:
	if hull == null:
		return
	_flash_left = 0.1
	hull.modulate = Color(2.4, 2.4, 2.4)

func _drop_props() -> void:
	var host := get_parent()
	if host == null:
		host = get_tree().current_scene
	for p in _props:
		if p == null or not is_instance_valid(p):
			continue
		var keep_pos: Vector2 = p.global_position
		var keep_rot: float = p.get_global_transform().get_rotation()
		p.reparent(host)
		p.global_position = keep_pos
		p.rotation = keep_rot
		var tw := p.create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "position", p.position + Vector2(randf_range(-90.0, 90.0), randf_range(420.0, 560.0)), randf_range(1.1, 1.6))\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(p, "rotation", keep_rot + randf_range(-2.2, 2.2), 1.4)
		tw.tween_property(p, "modulate:a", 0.0, 1.4)
		tw.chain().tween_callback(p.queue_free)
	_props.clear()

func _win() -> void:
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
	for i in 4:
		_spawn_death_effect()
	_drop_props()
	_spawn_wreck_crew()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", position.y + 1100.0, 4.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "rotation", rotation + 0.55, 4.2)
	tw.tween_property(self, "modulate:a", 0.0, 4.2)
	tw.chain().tween_callback(queue_free)

func _spawn_wreck_crew() -> void:
	var origin := _park_global
	if origin == Vector2.ZERO:
		origin = global_position
	if officer_scene:
		_launch_unit(officer_scene, origin, origin + Vector2(0, 30.0), escort_travel)
	if drone_scene:
		_launch_unit(drone_scene, origin, origin + Vector2(-escort_spread, 20.0), escort_travel)
		_launch_unit(drone_scene, origin, origin + Vector2(escort_spread, 20.0), escort_travel)

func _launch_unit(packed: PackedScene, from_global: Vector2, dest_global: Vector2, t: float) -> void:
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
	tw.tween_property(n, "global_position", dest_global, t)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void:
		if not is_instance_valid(n):
			return
		if n.has_method("finish_travel"):
			n.finish_travel(n.position)
		else:
			n.set("_base_pos", n.position)
	)

func _spawn_death_effect() -> void:
	if death_effect == null:
		return
	var fx := death_effect.instantiate()
	var host := get_parent()
	if host == null:
		host = get_tree().current_scene
	host.add_child(fx)
	var mid := _park_global
	if mid == Vector2.ZERO:
		mid = global_position
	mid += Vector2(randf_range(-50.0, 50.0), randf_range(-30.0, 30.0))
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
	return get_tree().root.get_node_or_null("Game")
