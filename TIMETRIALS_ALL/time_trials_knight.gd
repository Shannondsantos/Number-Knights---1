extends Control
signal failed_answer
@export var points: int = 20
@export var contact_damage: int = 1
@export var time_bonus := 5
@export var fly_time := 3.0
@export var travel_distance := 500.0
@export var fire_interval := 4.0
@export var triple_wait := 2.6
@export var attack_fade_in := 0.45
@export var attack_windup := 0.55
@export var shell_scene: PackedScene
@export var stormtrooper_scene: PackedScene
@export var trooper_min := 8.0
@export var trooper_max := 12.0
@export var trooper_flank := 280.0
@export var trooper_drop := 40.0
@export var hull_tex: Texture2D
@export var main_frames: Array[Texture2D] = []
@export var main_flip := 0.07
@export var hurt_wobble_move := 10.0
@export var hurt_wobble_rot := 0.07
@export var arrive_sound: AudioStream
@export var correct_sound: AudioStream
@export var wrong_sound: AudioStream
@export var windup_sound: AudioStream
@export var fire_sound: AudioStream
@export var heli_loop: AudioStream
@onready var hull: TextureRect = get_node_or_null("Hull")
@onready var led: Label = get_node_or_null("LED")
@onready var answers: Control = get_node_or_null("Answers")
@onready var nav_light: TextureRect = get_node_or_null("Attack_Indicator")
@onready var shield: TextureRect = get_node_or_null("Shield")
@onready var rotor_a: TextureRect = get_node_or_null("MainRotor")
@onready var rotor_b: TextureRect = get_node_or_null("MainRotor2")
var _alive := true
var _parked := false
var _correct := 0
var _park := Vector2.ZERO
var _park_global := Vector2.ZERO
var _sfx: AudioStreamPlayer
var _flash_left := 0.0
var _hull_mod := Color.WHITE
var _hull_home := Vector2.ZERO
var _hull_rot := 0.0
var _shield_tw: Tween
var _shield_up := false
var _seen: Array[String] = []
var _wave := 0
var _flip_t := 0.0
var _frame_a := 0
var _frame_b := 2
var _heli: AudioStreamPlayer
var _guns: Array[TextureRect] = []
var _firing: Array[int] = []
var _volley := 0
var _burst_all := false
var _fire_cd := 0.0
var _trooper_cd := 0.0
var _spawn_step := 0
var _easy_in := 0
var _phase := -1
var _phase_t := 0.0
func _ready() -> void:
	add_to_group("enemies")
	if hull:
		_hull_mod = hull.modulate
		_hull_home = hull.position
		_hull_rot = hull.rotation
		hull.pivot_offset = hull.size * 0.5
		if hull_tex == null:
			hull_tex = hull.texture
		if hull_tex:
			hull.texture = hull_tex
	_setup_rotor(rotor_a, 0)
	_setup_rotor(rotor_b, 2)
	_collect_rockets()
	_hide_shield()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if answers:
		answers.visible = false
		for i in 4:
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
func _collect_rockets() -> void:
	_guns.clear()
	for named in ["RocketIndicator1", "RocketIndicator2"]:
		var g := get_node_or_null(named)
		if g is TextureRect:
			var r := g as TextureRect
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			r.modulate.a = 0.0
			_guns.append(r)
func _setup_rotor(r: TextureRect, start: int) -> void:
	if r == null:
		return
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.pivot_offset = r.size * 0.5
	if main_frames.size() == 0:
		return
	var i := start % main_frames.size()
	if r == rotor_a:
		_frame_a = i
	else:
		_frame_b = i
	if main_frames[i]:
		r.texture = main_frames[i]
func _hide_shield() -> void:
	if shield == null:
		return
	shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shield.visible = false
	shield.modulate.a = 0.0
	_shield_up = false
func contains_point(screen_pos: Vector2) -> bool:
	if hull == null or not hull.get_global_rect().has_point(screen_pos):
		return false
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self or not is_instance_valid(e):
			continue
		if not e is CanvasItem:
			continue
		var c := e as CanvasItem
		if c.z_index <= z_index:
			continue
		if e.has_method("contains_point") and e.contains_point(screen_pos):
			return false
	return true
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
	_park = position
	_park_global = global_position
	position = _park - Vector2(travel_distance, 0.0)
	var tw := create_tween()
	tw.tween_property(self, "position", _park, fly_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_on_parked)
func _process(delta: float) -> void:
	if shield and not _shield_up:
		_hide_shield()
	if hull and _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			hull.modulate = _hull_mod
	if hull and _alive and _parked:
		var t := Time.get_ticks_msec() / 1000.0
		var fight := sin(t * 0.85) * 0.7 + sin(t * 1.35 + 1.4) * 0.3
		position = _park + Vector2(fight * 7.0, sin(t * 0.6) * 3.0)
		rotation = fight * 0.035
		hull.position = _hull_home
		hull.rotation = _hull_rot
	if nav_light and _alive:
		nav_light.modulate.a = 0.18 + 0.82 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 1.6))
	_spin_rotors(delta)
	if not _alive or not _parked:
		return
	_trooper_cd -= delta
	if _trooper_cd <= 0.0:
		_spawn_flank()
		_trooper_cd = randf_range(trooper_min, trooper_max)
	if _phase < 0:
		_fire_cd -= delta
		if _fire_cd <= 0.0:
			_start_fire()
	else:
		_run_fire(delta)
func _start_fire() -> void:
	if _guns.is_empty() or shell_scene == null:
		_fire_cd = fire_interval
		return
	_firing.clear()
	if _volley >= _guns.size():
		for i in _guns.size():
			_firing.append(i)
		_volley = 0
		_burst_all = true
	else:
		_firing.append(_volley)
		_volley += 1
		_burst_all = false
	_phase = 0
	_phase_t = 0.0
	_show_lights(0.0)
	_play(windup_sound)
func _run_fire(delta: float) -> void:
	_phase_t += delta
	if _phase == 0:
		_show_lights(clampf(_phase_t / attack_fade_in, 0.0, 1.0))
		if _phase_t >= attack_fade_in:
			_phase = 1
			_phase_t = 0.0
		return
	_show_lights(0.45 + 0.55 * sin(_phase_t * 28.0))
	if _phase_t < attack_windup:
		return
	_fire()
func _fire() -> void:
	_show_lights(0.0)
	_play(fire_sound)
	for i in _firing:
		_spawn_shell(_guns[i])
	var wait := fire_interval
	if not _burst_all and _volley >= _guns.size():
		wait = fire_interval + triple_wait
	_firing.clear()
	_phase = -1
	_phase_t = 0.0
	_fire_cd = wait
func _show_lights(a: float) -> void:
	for i in _guns.size():
		var m := _guns[i].modulate
		m.a = a if _firing.has(i) else 0.0
		_guns[i].modulate = m
func _spawn_shell(gun: Control) -> void:
	if shell_scene == null or gun == null:
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
func _spawn_flank() -> void:
	if stormtrooper_scene == null:
		return
	var origin := _park_global if _park_global != Vector2.ZERO else global_position
	match _spawn_step % 3:
		0:
			_launch(stormtrooper_scene, origin, origin + Vector2(-trooper_flank, trooper_drop), 0.55)
		1:
			_launch(stormtrooper_scene, origin, origin + Vector2(trooper_flank, trooper_drop), 0.55)
		_:
			_launch(stormtrooper_scene, origin, origin + Vector2(-trooper_flank, trooper_drop), 0.55)
			_launch(stormtrooper_scene, origin, origin + Vector2(trooper_flank, trooper_drop), 0.55)
	_spawn_step += 1
func _launch(packed: PackedScene, from_global: Vector2, dest_global: Vector2, t: float) -> void:
	var n := packed.instantiate()
	var host := get_parent()
	if host == null:
		host = get_tree().current_scene
	host.add_child(n)
	if n is CanvasItem:
		var c := n as CanvasItem
		c.z_as_relative = false
		c.z_index = 40
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
func _spin_rotors(delta: float) -> void:
	if main_frames.size() == 0:
		return
	_flip_t += delta
	if _flip_t < main_flip:
		return
	_flip_t = 0.0
	_frame_a = (_frame_a + 1) % main_frames.size()
	_frame_b = (_frame_b + 1) % main_frames.size()
	if rotor_a and main_frames[_frame_a]:
		rotor_a.texture = main_frames[_frame_a]
	if rotor_b and main_frames[_frame_b]:
		rotor_b.texture = main_frames[_frame_b]
func _on_parked() -> void:
	_parked = true
	_park = position
	_park_global = global_position
	_fire_cd = fire_interval
	_trooper_cd = randf_range(trooper_min, trooper_max)
	_easy_in = randi_range(5, 8)
	_play(arrive_sound)
	var hud := _hud()
	if hud and answers and answers.get_parent() != hud:
		var gpos := answers.global_position
		answers.reparent(hud)
		answers.global_position = gpos
	if answers:
		answers.visible = true
		answers.mouse_filter = Control.MOUSE_FILTER_STOP
	_new_question()
func _new_question() -> void:
	if _easy_in <= 0:
		_easy_in = randi_range(6, 10)
		_question_easy()
		return
	_easy_in -= 1
	_q_pemdas()

func _q_pemdas() -> void:
	var kind := randi() % 3
	var key := ""
	var found := false
	var hi_a := _a_cap()
	var hi_b := _b_cap()
	for _try in 30:
		kind = randi() % 3
		if kind == 0:
			var a := randi_range(1, hi_a)
			var b := randi_range(2, hi_b)
			var c := randi_range(2, hi_b)
			key = "%d+%dx%d" % [a, b, c]
			if _seen.has(key):
				continue
			_seen.append(key)
			_correct = a + b * c
			if led:
				led.text = "%d + %d × %d = ?" % [a, b, c]
			found = true
		elif kind == 1:
			var b2 := randi_range(2, hi_b)
			var c2 := randi_range(2, hi_b)
			var a2 := b2 * c2 + randi_range(1, hi_a)
			key = "%d-%dx%d" % [a2, b2, c2]
			if _seen.has(key):
				continue
			_seen.append(key)
			_correct = a2 - b2 * c2
			if led:
				led.text = "%d - %d × %d = ?" % [a2, b2, c2]
			found = true
		else:
			var b3 := randi_range(2, hi_b)
			var c3 := randi_range(2, hi_b)
			var a3 := b3 + randi_range(1, hi_a)
			var top := b3 * c3
			key = "%d-%d/%d" % [a3, top, c3]
			if _seen.has(key):
				continue
			_seen.append(key)
			_correct = a3 - b3
			if led:
				led.text = "%d - %d ÷ %d = ?" % [a3, top, c3]
			found = true
		if found:
			break
	if not found:
		_seen.clear()
		_correct = 2 + 2 * 2
		if led:
			led.text = "2 + 2 × 2 = ?"
	_fill_answers(_correct)

func _a_cap() -> int:
	var w := maxi(_wave, 0)
	if w < 10:
		return 6
	if w < 20:
		return 6 + (w - 9)
	if w < 30:
		return 12 + (w - 19)
	if w < 40:
		return 18 + (w - 29)
	return mini(40, 25 + (w - 39))

func _b_cap() -> int:
	var w := maxi(_wave, 0)
	if w < 10:
		return 4
	if w < 20:
		return 4 + int((w - 9) * 0.5)
	if w < 30:
		return 6 + int((w - 19) * 0.4)
	if w < 40:
		return 8 + int((w - 29) * 0.3)
	return mini(15, 10 + int((w - 39) * 0.2))

func _question_easy() -> void:
	var picks := [
		[1, 1, "+"],
		[2, 1, "+"],
		[2, 2, "+"],
		[3, 1, "+"],
		[1, 1, "x"],
		[2, 1, "x"],
		[2, 2, "x"],
		[3, 1, "x"],
		[2, 1, "-"],
		[3, 1, "-"],
		[4, 2, "-"],
		[2, 1, "/"],
		[4, 2, "/"],
		[3, 1, "/"]
	]
	var pick: Array = picks[randi() % picks.size()]
	var a: int = pick[0]
	var b: int = pick[1]
	var op: String = pick[2]
	if op == "/":
		_correct = a
		if led:
			led.text = "%d ÷ %d = ?" % [a * b, b]
	elif op == "+":
		_correct = a + b
		if led:
			led.text = "%d + %d = ?" % [a, b]
	elif op == "-":
		_correct = a - b
		if led:
			led.text = "%d - %d = ?" % [a, b]
	else:
		_correct = a * b
		if led:
			led.text = "%d x %d = ?" % [a, b]
	_fill_answers(_correct)

func _fill_answers(right: int) -> void:
	if answers == null:
		return
	var opts: Array[int] = [right]
	var bag: Array[int] = [right + 1, maxi(right - 1, 0), right + 2, maxi(right - 2, 0), right + 3, right * 2, right + 4, right + 5]
	bag.shuffle()
	for fake in bag:
		if opts.size() >= 4:
			break
		if fake < 0 or fake == right or opts.has(fake):
			continue
		opts.append(fake)
	while opts.size() < 4:
		var fake := right + randi_range(-8, 8)
		if fake < 0 or fake == right or opts.has(fake):
			continue
		opts.append(fake)
	opts.shuffle()
	for i in 4:
		var btn := answers.get_node_or_null("Answer%d" % i)
		if btn == null:
			continue
		var lbl := btn.get_node_or_null("Label") as Label
		if lbl:
			lbl.text = str(opts[i])
		btn.set_meta("value", opts[i])
func _pick(i: int) -> void:
	if not _parked or answers == null:
		return
	var btn := answers.get_node_or_null("Answer%d" % i)
	if btn == null:
		return
	if int(btn.get_meta("value")) == _correct:
		_right()
	else:
		_wrong()
func _right() -> void:
	_play(correct_sound)
	PlayerData.currency += points
	PlayerData.save()
	_wave += 1
	PlayerData.set_time_trial_wave("knight", _wave)
	_add_time(time_bonus)
	_flash()
	_new_question()
func _wrong() -> void:
	_play(wrong_sound)
	failed_answer.emit()
	var hud := _hud()
	if hud and hud.has_method("apply_damage"):
		hud.apply_damage(contact_damage)
	_new_question()
func _add_time(seconds: float) -> void:
	var timer := get_tree().current_scene.find_child("LevelTimer", true, false)
	if timer and timer.has_method("add_time"):
		timer.add_time(seconds)
func _flash() -> void:
	if hull == null:
		return
	_flash_left = 0.1
	hull.modulate = Color(2.4, 2.4, 2.4)
func _play(stream: AudioStream) -> void:
	if _sfx == null or stream == null:
		return
	_sfx.stream = stream
	_sfx.play()
func _hud() -> Node:
	var n := get_tree().current_scene
	if n != null and n.has_method("apply_damage"):
		return n
	return null
