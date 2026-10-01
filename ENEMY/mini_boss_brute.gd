extends Control

signal parked
signal defeated
signal failed_answer

@export var max_hp: int = 5
@export var points: int = 50
@export var contact_damage: int = 1
@export var fly_time := 7.0
@export var travel_distance := 500.0
@export var fire_interval := 3.2
@export var shell_scene: PackedScene
@export var death_effect: PackedScene

@export var hull_tex_100: Texture2D
@export var hull_tex_50: Texture2D
@export var hull_tex_25: Texture2D
@export var dead_texture: Texture2D

@export var prop_wiggle := 0.16
@export var prop_wiggle_speed := 3.5
@export var hurt_wobble_move := 8.0
@export var hurt_wobble_rot := 0.05
@export var attack_fade_in := 0.4
@export var attack_windup := 0.55

@export var missing_max := 12
@export var double_min := 10
@export var double_max := 30

@export var arrive_sound: AudioStream
@export var windup_sound: AudioStream
@export var fire_sound: AudioStream
@export var death_sound: AudioStream
@export var correct_sound: AudioStream
@export var wrong_sound: AudioStream

@onready var hull: TextureRect = get_node_or_null("Hull")
@onready var shield: TextureRect = get_node_or_null("Shield")
@onready var health_bar: Control = get_node_or_null("Health")
@onready var nav_light: TextureRect = get_node_or_null("Attack_Indicator")
@onready var led: Label = get_node_or_null("LED")
@onready var answers: Control = get_node_or_null("Answers")

var hp: int = 6
var _alive := true
var _parked := false
var _park := Vector2.ZERO
var _park_global := Vector2.ZERO
var _sfx: AudioStreamPlayer
var _phase := -1
var _phase_t := 0.0
var _fire_cd := 0.0
var _parked_time := 0.0
var _guns: Array[TextureRect] = []
var _firing: Array[int] = []
var _flash_left := 0.0
var _hull_mod := Color.WHITE
var _hull_home := Vector2.ZERO
var _hull_rot := 0.0
var _shield_tw: Tween
var _shield_up := false
var _hp_fill: Control
var _hp_fill_w := 0.0
var _correct := 0

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
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if hull:
		_hull_mod = hull.modulate
		_hull_home = hull.position
		_hull_rot = hull.rotation
		hull.pivot_offset = hull.size * 0.5
		if hull_tex_100 == null:
			hull_tex_100 = hull.texture
		hull.texture = hull_tex_100
	if answers:
		answers.visible = false
		for i in 3:
			var btn := answers.get_node_or_null("Answer%d" % i) as BaseButton
			if btn:
				var idx := i
				btn.pressed.connect(func() -> void: _pick(idx))
	_setup_health_bar()
	_hide_shield()
	_collect_props()
	_collect_rockets()
	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)
	call_deferred("_begin_approach")

func _begin_approach() -> void:
	if not _alive:
		return
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
	for n in [get_node_or_null("Propeller"), get_node_or_null("Propeller2"), get_node_or_null("Propeller3")]:
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

func _collect_rockets() -> void:
	_guns.clear()
	for c in find_children("*", "TextureRect", true, false):
		if String(c.name).begins_with("RocketIndi"):
			_guns.append(c)
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			c.modulate.a = 0.0
			if c.pivot_offset == Vector2.ZERO:
				c.pivot_offset = c.size * 0.5
	if nav_light:
		nav_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nav_light.modulate.a = 0.2
	print("brute rockets: ", _guns.size())

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
	var tw := _hp_fill.create_tween()
	tw.tween_property(_hp_fill, "size", target, 0.15).set_trans(Tween.TRANS_SINE)

func _hide_shield() -> void:
	if shield == null:
		return
	shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shield.visible = false
	shield.modulate.a = 0.0
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
	shield.modulate.a = 0.0
	_shield_tw = create_tween()
	_shield_tw.tween_property(shield, "modulate:a", 0.55, 0.08)
	_shield_tw.tween_property(shield, "modulate:a", 0.0, 0.35)
	_shield_tw.finished.connect(_hide_shield)

func _fly_in() -> void:
	_parked = false
	_hide_shield()
	if led:
		led.text = ""
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position", _park, fly_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for i in _props.size():
		_props[i].rotation = _prop_base_rot[i]
		tw.tween_property(_props[i], "rotation", _prop_park_rot[i], fly_time).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(_on_parked)

func _on_parked() -> void:
	if not _alive:
		return
	_parked = true
	_parked_time = 0.0
	_park = position
	_park_global = global_position
	_fire_cd = 1.2 + randf_range(0.3, 0.8)
	_play(arrive_sound)
	var hud := _hud()
	if hud and answers and answers.get_parent() != hud:
		var gpos := answers.global_position
		answers.reparent(hud)
		answers.global_position = gpos
	if answers:
		answers.visible = true
		answers.mouse_filter = Control.MOUSE_FILTER_STOP
		for i in 3:
			var btn := answers.get_node_or_null("Answer%d" % i) as Control
			if btn:
				btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_new_question()
	parked.emit()

func _new_question() -> void:
	if randf() < 0.5:
		_question_missing()
	else:
		_question_double()

func _question_missing() -> void:
	var a := randi_range(1, missing_max)
	var b := randi_range(1, missing_max)
	_correct = b
	if led:
		led.text = "%d + _ = %d" % [a, a + b]
	_fill_answers(_correct)

func _question_double() -> void:
	var a := randi_range(double_min, double_max)
	var b := randi_range(double_min, double_max)
	_correct = a + b
	if led:
		led.text = "%d + %d = ?" % [a, b]
	_fill_answers(_correct)

func _fill_answers(right: int) -> void:
	if answers == null:
		return
	var opts: Array[int] = [right]
	while opts.size() < 3:
		var fake: int = right + randi_range(-8, 8)
		if fake < 1 or fake == right or opts.has(fake):
			continue
		opts.append(fake)
	opts.shuffle()
	for i in 3:
		var btn := answers.get_node_or_null("Answer%d" % i)
		if btn == null:
			continue
		var lbl := btn.get_node_or_null("Label") as Label
		if lbl:
			lbl.text = str(opts[i])
		btn.set_meta("value", opts[i])

func _pick(i: int) -> void:
	if not _alive or not _parked or answers == null:
		return
	var btn := answers.get_node_or_null("Answer%d" % i)
	if btn == null:
		return
	var val := int(btn.get_meta("value"))
	if val == _correct:
		_play(correct_sound)
		take_hit()
		if _alive:
			_new_question()
	else:
		_play(wrong_sound)
		failed_answer.emit()
		var hud := _hud()
		if hud != null and hud.has_method("apply_damage"):
			hud.apply_damage(contact_damage)
		_new_question()

func _process(delta: float) -> void:
	if shield and not _shield_up:
		_hide_shield()
	if hull and _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			hull.modulate = _hull_mod
	if nav_light and _alive:
		var a := 0.15 + 0.85 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 1.6))
		var mcol := nav_light.modulate
		mcol.a = a
		nav_light.modulate = mcol
	if hull and _alive and _parked:
		var u := 1.0 - float(hp) / float(maxi(max_hp, 1))
		var t := Time.get_ticks_msec() / 1000.0
		var m := u * u
		hull.position = _hull_home + Vector2(sin(t * 0.7) * hurt_wobble_move * m, sin(t * 0.5) * hurt_wobble_move * 0.6 * m)
		hull.rotation = _hull_rot + sin(t * 0.45) * hurt_wobble_rot * m
	if not (_alive and _parked):
		_force_rockets_off()
		return
	_parked_time += delta
	_wiggle_props()
	if _phase < 0:
		_force_rockets_off()
		_fire_cd -= delta
		if _fire_cd <= 0.0 and _guns.size() > 0:
			_pick_guns()
			_phase = 0
			_phase_t = 0.0
			_play(windup_sound)
		return
	_phase_t += delta
	if _phase == 0:
		_show_lights(clampf(_phase_t / attack_fade_in, 0.0, 1.0))
		if _phase_t >= attack_fade_in:
			_phase = 1
			_phase_t = 0.0
	elif _phase == 1:
		var wind := clampf(_phase_t / attack_windup, 0.0, 1.0)
		var freq := lerpf(4.0, 14.0, wind * wind)
		_show_lights(0.45 + 0.55 * sin(_phase_t * freq * TAU))
		if _phase_t >= attack_windup:
			_fire()

func _force_rockets_off() -> void:
	for g in _guns:
		if g == null:
			continue
		var m := g.modulate
		m.a = 0.0
		g.modulate = m

func _wiggle_props() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in _props.size():
		var p := _props[i]
		if p == null:
			continue
		var w := sin(t * prop_wiggle_speed * _prop_spd[i] + _prop_phase[i]) * prop_wiggle * _prop_amp[i]
		p.rotation = _prop_park_rot[i] + w
		p.position = _prop_home[i] + Vector2(sin(t * 2.0 + _prop_phase[i]) * 2.0, cos(t * 1.6 + _prop_phase[i]) * 1.5)

func _rocket_count() -> int:
	if _parked_time >= 30.0:
		return 2
	return 1

func _pick_guns() -> void:
	_firing.clear()
	var count := mini(_rocket_count(), _guns.size())
	var bag: Array[int] = []
	for i in _guns.size():
		bag.append(i)
	bag.shuffle()
	for i in count:
		_firing.append(bag[i])

func _show_lights(a: float) -> void:
	for i in _guns.size():
		var m := _guns[i].modulate
		m.a = a if _firing.has(i) else 0.0
		_guns[i].modulate = m

func _fire() -> void:
	_show_lights(0.0)
	_play(fire_sound)
	for i in _firing:
		_spawn_shell(_guns[i])
	_firing.clear()
	_phase = -1
	_fire_cd = fire_interval + randf_range(0.4, 1.0)

func _spawn_shell(gun: Control) -> void:
	if shell_scene == null:
		return
	var sh := shell_scene.instantiate() as Control
	if sh == null:
		return
	gun.add_child(sh)
	if sh.texture:
		sh.size = sh.texture.get_size()
	if sh.pivot_offset == Vector2.ZERO:
		sh.pivot_offset = sh.size * 0.5
	sh.position = gun.pivot_offset - sh.pivot_offset
	var keep: Vector2 = sh.global_position
	var host := get_parent()
	if host == null:
		host = get_tree().current_scene
	sh.reparent(host)
	sh.global_position = keep
	sh.set("_base", sh.position)

func _apply_hull_tex() -> void:
	if hull == null:
		return
	var ratio := float(hp) / float(maxi(max_hp, 1))
	var tex := hull_tex_100
	if ratio <= 0.25:
		tex = hull_tex_25
	elif ratio <= 0.5:
		tex = hull_tex_50
	if tex:
		hull.texture = tex

func take_hit() -> void:
	if not _alive:
		return
	hp -= 1
	_flash_left = 0.1
	if hull:
		hull.modulate = Color(2.4, 2.4, 2.4)
	_apply_hull_tex()
	_refresh_health_bar(true)
	if hp <= 0:
		_die()

func _die() -> void:
	if not _alive:
		return
	_alive = false
	_hide_shield()
	if health_bar:
		health_bar.visible = false
	if nav_light:
		nav_light.modulate.a = 0.0
	_force_rockets_off()
	if answers:
		answers.visible = false
		answers.queue_free()
	_play(death_sound)
	PlayerData.currency += points
	PlayerData.save()
	defeated.emit()
	if hull and dead_texture:
		hull.texture = dead_texture
	if death_effect:
		var fx := death_effect.instantiate()
		var host := get_parent()
		if host:
			host.add_child(fx)
		if fx.has_method("setup"):
			fx.setup(global_position)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", position.y + 900.0, 3.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "rotation", rotation + 0.4, 3.4)
	tw.tween_property(self, "modulate:a", 0.0, 3.4)
	tw.chain().tween_callback(queue_free)

func _play(stream: AudioStream) -> void:
	if _sfx == null or stream == null:
		return
	_sfx.stream = stream
	_sfx.play()

func _hud() -> Node:
	var n := get_tree().current_scene
	if n != null and n.has_method("apply_damage"):
		return n
	return get_tree().root.get_node_or_null("Game")
