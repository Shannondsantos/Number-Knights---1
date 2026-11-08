extends Control
signal parked
signal defeated
signal failed_answer
@export var max_hp: int = 20
@export var points: int = 25
@export var contact_damage: int = 1
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
@export var hull_tex_100: Texture2D
@export var hull_tex_75: Texture2D
@export var hull_tex_50: Texture2D
@export var hull_tex_25: Texture2D
@export var dead_texture: Texture2D
@export var death_effect: PackedScene
@export var main_frames: Array[Texture2D] = []
@export var main_flip := 0.07
@export var hurt_wobble_move := 10.0
@export var hurt_wobble_rot := 0.07
@export var arrive_sound: AudioStream
@export var correct_sound: AudioStream
@export var wrong_sound: AudioStream
@export var windup_sound: AudioStream
@export var fire_sound: AudioStream
@export var death_sound: AudioStream
@export var heli_loop: AudioStream
@export var panel_hp: int = 10
@onready var hull: TextureRect = get_node_or_null("Hull")
@onready var led: Label = get_node_or_null("LED")
@onready var answers: Control = get_node_or_null("Answers")
@onready var nav_light: TextureRect = get_node_or_null("Attack_Indicator")
@onready var shield: TextureRect = get_node_or_null("Shield")
@onready var rotor_a: TextureRect = get_node_or_null("MainRotor")
@onready var rotor_b: TextureRect = get_node_or_null("MainRotor2")
@onready var health_bar: Control = get_node_or_null("Health")
var hp: int = 20
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
var _phase := -1
var _phase_t := 0.0
var _health_full_w := 1.0
var _rotors_spinning := true
var _panels: Array[TextureRect] = []
var _panel_hp: Array[int] = []
var _panels_clear := false
func _ready() -> void:
	add_to_group("enemies")
	add_to_group("minibosses")
	hp = max_hp
	_collect_panels()
	if hull:
		_hull_mod = hull.modulate
		_hull_home = hull.position
		_hull_rot = hull.rotation
		hull.pivot_offset = hull.size * 0.5
	_apply_hull_tex()
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
	if health_bar:
		_health_full_w = health_bar.size.x
		_refresh_health_bar(false)
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
func _collect_panels() -> void:
	_panels.clear()
	_panel_hp.clear()
	for named in ["Panel1", "Panel2", "Panel3"]:
		var p := get_node_or_null(named) as TextureRect
		if p:
			p.mouse_filter = Control.MOUSE_FILTER_STOP
			_panels.append(p)
			_panel_hp.append(panel_hp)
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
	if not _panels_clear:
		for p in _panels:
			if p and is_instance_valid(p) and p.visible and p.get_global_rect().has_point(screen_pos):
				return true
	if hull and hull.get_global_rect().has_point(screen_pos):
		return true
	return false

func receive_shot() -> void:
	if not _panels_clear:
		_hit_panel()
		return
	_pulse_shield()
func _hit_panel() -> void:
	for i in _panels.size():
		var p := _panels[i]
		if p == null or not is_instance_valid(p) or not p.visible:
			continue
		_panel_hp[i] -= 1
		p.modulate = Color(2.4, 2.4, 2.4)
		var tw := p.create_tween()
		tw.tween_property(p, "modulate", Color.WHITE, 0.1)
		if _panel_hp[i] <= 0:
			_kill_panel(i)
		return
	_check_panels()
func _kill_panel(i: int) -> void:
	var p := _panels[i]
	if p == null:
		return
	var tw := p.create_tween()
	tw.set_parallel(true)
	tw.tween_property(p, "position", p.position + Vector2(randf_range(-40, 40), 120), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(p, "rotation", p.rotation + randf_range(-0.6, 0.6), 0.4)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(p):
			p.visible = false
			p.queue_free()
		_check_panels()
	)
func _check_panels() -> void:
	for p in _panels:
		if p and is_instance_valid(p) and p.visible:
			return
	_panels_clear = true
	if answers:
		answers.visible = true
		answers.mouse_filter = Control.MOUSE_FILTER_STOP
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
		var ratio := float(hp) / float(maxi(max_hp, 1))
		var erratic := lerpf(1.0, 2.4, 1.0 - ratio)
		var t := Time.get_ticks_msec() / 1000.0
		var fight := sin(t * 0.85) * 0.7 + sin(t * 1.35 + 1.4) * 0.3
		position = _park + Vector2(fight * 7.0 * erratic, sin(t * 0.6) * 3.0 * erratic)
		rotation = fight * 0.035 * erratic
		hull.position = _hull_home
		hull.rotation = _hull_rot
	if nav_light and _alive:
		nav_light.modulate.a = 0.18 + 0.82 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 1.6))
	if _rotors_spinning:
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
	_play(arrive_sound)
	_hide_shield()
	var hud := _hud()
	if hud and answers and answers.get_parent() != hud:
		var gpos := answers.global_position
		answers.reparent(hud)
		answers.global_position = gpos
	if answers:
		answers.visible = false
		answers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_new_question()
	parked.emit()
func _new_question() -> void:
	if randf() < 0.2:
		_q_mult()
		return
	if randf() < 0.15:
		_q_division()
		return
	if randi() % 3 == 0:
		_q_mixed()
	else:
		_q_add3()
func _diff() -> float:
	return 1.0 - clampf(float(hp) / float(maxi(max_hp, 1)), 0.0, 1.0)
func _q_add3() -> void:
	var d := _diff()
	var lo := int(lerpf(5, 60, d))
	var hi := int(lerpf(20, 250, d))
	var a := randi_range(lo, hi)
	var b := randi_range(lo, hi)
	var c := randi_range(lo, hi)
	var key := "%d+%d+%d" % [a, b, c]
	if _seen.has(key):
		_q_add3()
		return
	_seen.append(key)
	_correct = a + b + c
	if led:
		led.text = "%d + %d + %d = ?" % [a, b, c]
	_fill_answers(_correct)
func _q_mixed() -> void:
	var d := _diff()
	var lo := int(lerpf(5, 40, d))
	var hi := int(lerpf(15, 160, d))
	var a := randi_range(lo + 10, hi + 30)
	var b := randi_range(lo, mini(a - 1, hi))
	var c := randi_range(lo, hi)
	var key := "%d-%d+%d" % [a, b, c]
	if _seen.has(key):
		_q_mixed()
		return
	_seen.append(key)
	_correct = a - b + c
	if led:
		led.text = "%d - %d + %d = ?" % [a, b, c]
	_fill_answers(_correct)
func _q_mult() -> void:
	var d := _diff()
	var a := randi_range(2, int(lerpf(6, 15, d)))
	var b := randi_range(2, int(lerpf(6, 12, d)))
	var key := "%d*%d" % [a, b]
	if _seen.has(key):
		_q_mult()
		return
	_seen.append(key)
	_correct = a * b
	if led:
		led.text = "%d × %d = ?" % [a, b]
	_fill_answers(_correct)
func _q_division() -> void:
	var d := _diff()
	var b := randi_range(2, int(lerpf(6, 12, d)))
	var quot := randi_range(int(lerpf(4, 12, d)), int(lerpf(15, 50, d)))
	var a := b * quot
	var key := "%d/%d" % [a, b]
	if _seen.has(key):
		_q_division()
		return
	_seen.append(key)
	_correct = quot
	if led:
		led.text = "%d ÷ %d = ?" % [a, b]
	_fill_answers(_correct)
func _fill_answers(right: int) -> void:
	if answers == null:
		return
	var opts: Array[int] = [right]
	var bag: Array[int] = [right + 2, maxi(right - 2, 0), right + 5, maxi(right - 5, 0), right + 10, right + 1, maxi(right - 1, 0)]
	bag.shuffle()
	for fake in bag:
		if opts.size() >= 4:
			break
		if fake < 0 or fake == right or opts.has(fake):
			continue
		opts.append(fake)
	while opts.size() < 4:
		var fake := right + randi_range(-15, 15)
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
	if not _parked or not _panels_clear or answers == null:
		return
	var btn := answers.get_node_or_null("Answer%d" % i)
	if btn == null:
		return
	if int(btn.get_meta("value")) == _correct:
		_right()
	else:
		_wrong()
func _right() -> void:
	hp -= 1
	_play(correct_sound)
	_flash()
	_spawn_death_effect()
	_apply_hull_tex()
	_refresh_health_bar(true)
	if hp <= 0:
		_die()
		return
	_new_question()
func _wrong() -> void:
	_play(wrong_sound)
	failed_answer.emit()
	var hud := _hud()
	if hud and hud.has_method("apply_damage"):
		hud.apply_damage(contact_damage)
	_new_question()
func _apply_hull_tex() -> void:
	if hull == null:
		return
	var ratio := float(hp) / float(maxi(max_hp, 1))
	var tex := hull_tex_100
	if ratio <= 0.25:
		tex = hull_tex_25
	elif ratio <= 0.5:
		tex = hull_tex_50
	elif ratio <= 0.75:
		tex = hull_tex_75
	if tex:
		hull.texture = tex
func _refresh_health_bar(animate: bool) -> void:
	if health_bar == null:
		return
	var ratio := float(hp) / float(maxi(max_hp, 1))
	var target := Vector2(_health_full_w * clampf(ratio, 0.0, 1.0), health_bar.size.y)
	if not animate:
		health_bar.size = target
		return
	var tw := health_bar.create_tween()
	tw.tween_property(health_bar, "size", target, 0.12).set_trans(Tween.TRANS_SINE)
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
	mid += Vector2(randf_range(-40.0, 40.0), randf_range(-20.0, 20.0))
	if fx.has_method("setup"):
		fx.setup(mid)
	else:
		fx.global_position = mid
func _drop_rotors() -> void:
	_rotors_spinning = false
	_drop_one(rotor_a)
	_drop_one(rotor_b)
func _drop_one(r: TextureRect) -> void:
	if r == null:
		return
	var keep_pos: Vector2 = r.global_position
	var keep_rot: float = r.rotation
	var host := get_parent()
	if host == null:
		host = get_tree().current_scene
	r.reparent(host)
	r.global_position = keep_pos
	r.rotation = keep_rot
	var tw := r.create_tween()
	tw.set_parallel(true)
	tw.tween_property(r, "position", r.position + Vector2(randf_range(-80, 80), randf_range(180, 320)), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(r, "rotation", r.rotation + randf_range(-1.2, 1.2), 0.7)
	tw.tween_property(r, "modulate:a", 0.0, 0.7)
	tw.chain().tween_callback(r.queue_free)
func _die() -> void:
	if not _alive:
		return
	_alive = false
	_parked = false
	_hide_shield()
	if health_bar:
		health_bar.visible = false
	if nav_light:
		nav_light.modulate.a = 0.0
	if answers:
		answers.visible = false
		answers.queue_free()
	if _heli and _heli.playing:
		_heli.stop()
	_drop_rotors()
	_play(death_sound)
	_spawn_death_effect()
	_spawn_death_effect()
	if hull and dead_texture:
		hull.texture = dead_texture
	PlayerData.currency += points
	PlayerData.save()
	defeated.emit()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", position.y + 700.0, 2.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 0.0, 2.8)
	tw.chain().tween_callback(queue_free)
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
