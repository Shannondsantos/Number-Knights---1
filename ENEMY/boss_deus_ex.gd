extends Control
signal parked
signal defeated
signal failed_answer
@export var max_hp: int = 30
@export var points: int = 1500
@export var contact_damage: int = 1
@export var heal_on_wrong: int = 1
@export var fly_time := 8.0
@export var travel_distance := 500.0
@export var trooper_scene: PackedScene
@export var shell_scene: PackedScene
@export var trooper_drop := 190.0
@export var trooper_spread := 130.0
@export var trooper_interval := 15.0
@export var rocket_interval := 10.0
@export var both_rocket_chance := 0.35
@export var hull_tex_100: Texture2D
@export var hull_tex_50: Texture2D
@export var hull_tex_25: Texture2D
@export var dead_texture: Texture2D
@export var death_effect: PackedScene
@export var prop_wiggle := 0.08
@export var prop_wiggle_speed := 1.6
@export var lumber_move := 12.0
@export var lumber_rot := 0.025
@export var attack_fade_in := 0.4
@export var attack_windup := 0.55
@export var arrive_sound: AudioStream
@export var correct_sound: AudioStream
@export var wrong_sound: AudioStream
@export var death_sound: AudioStream
@export var windup_sound: AudioStream
@export var fire_sound: AudioStream
@onready var hull: TextureRect = get_node_or_null("Hull")
@onready var led: Label = get_node_or_null("LED")
@onready var answers: Control = get_node_or_null("Answers")
@onready var nav_light: TextureRect = get_node_or_null("Attack_Indicator")
@onready var shield: TextureRect = get_node_or_null("Shield")
@onready var health_bar: Control = get_node_or_null("Health")
var hp: int = 30
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
var _trooper_cd := 15.0
var _rocket_cd := 10.0
var _slot := 0
var _shield_tw: Tween
var _shield_up := false
var _hp_fill: Control
var _hp_fill_w := 0.0
var _hp_tw: Tween
var _prop: TextureRect
var _prop_base := 0.0
var _prop_park := 0.0
var _prop_home := Vector2.ZERO
var _guns: Array[TextureRect] = []
var _firing: Array[int] = []
var _phase := -1
var _phase_t := 0.0
var _prop_gone := false
var _spark_cd := 0.0
func _ready() -> void:
	add_to_group("minibosses")
	add_to_group("enemies")
	add_to_group("elites")
	hp = max_hp
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	if hull:
		_hull_mod = hull.modulate
		_hull_home = hull.position
		_hull_rot = hull.rotation
		hull.pivot_offset = hull.size * 0.5
		if hull_tex_100 == null:
			hull_tex_100 = hull.texture
		hull.texture = hull_tex_100
	_prop = get_node_or_null("Propeller")
	if _prop:
		_prop.pivot_offset = _prop.size * 0.5
		_prop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_prop_base = _prop.rotation
		_prop_park = _prop.rotation - PI * 0.5
		_prop_home = _prop.position
	_setup_health_bar()
	_hide_shield()
	_collect_rockets()
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
	call_deferred("_begin_approach")
func _collect_rockets() -> void:
	_guns.clear()
	for c in find_children("*", "TextureRect", true, false):
		if String(c.name).begins_with("RocketIndi"):
			_guns.append(c)
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			c.modulate.a = 0.0
			if c.pivot_offset == Vector2.ZERO:
				c.pivot_offset = c.size * 0.5
func _stage() -> int:
	if hp > 20:
		return 1
	if hp > 10:
		return 2
	return 3
func _near_end_of_phase() -> bool:
	if _stage() == 1 and hp <= 23:
		return true
	if _stage() == 2 and hp <= 13:
		return true
	return false
func _is_desperate() -> bool:
	return hp <= 3
func _begin_approach() -> void:
	if not _alive:
		return
	_hide_shield()
	_park_global = global_position
	_park = position
	global_position = _park_global - Vector2(travel_distance, 0.0)
	modulate.a = 1.0
	_fly_in()
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
	tw.tween_property(self, "global_position", _park_global, fly_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _prop and not _prop_gone:
		_prop.rotation = _prop_base
		tw.tween_property(_prop, "rotation", _prop_park, fly_time).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(_on_parked)
func _on_parked() -> void:
	if not _alive:
		return
	_parked = true
	_park_global = global_position
	_park = position
	_trooper_cd = trooper_interval
	_rocket_cd = rocket_interval
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
	if _near_end_of_phase() and randf() < 0.55:
		_q_three()
		return
	match _stage():
		1:
			if randf() < 0.5:
				_q_add()
			else:
				_q_sub()
		2:
			if randf() < 0.5:
				_q_mul()
			else:
				_q_div()
		_:
			_q_pemdas()
func _q_three() -> void:
	var a := randi_range(2, 9)
	var b := randi_range(1, 6)
	var c := randi_range(1, 6)
	if randi() % 2 == 0:
		_correct = a + b - c
		if led:
			led.text = "%d + %d - %d = ?" % [a, b, c]
	else:
		_correct = a - b + c
		if led:
			led.text = "%d - %d + %d = ?" % [a, b, c]
	_fill_answers(_correct)
func _q_add() -> void:
	var a := randi_range(1, 9)
	var b := randi_range(1, 9)
	_correct = a + b
	if led:
		led.text = "%d + %d = ?" % [a, b]
	_fill_answers(_correct)
func _q_sub() -> void:
	var a := randi_range(2, 9)
	var b := randi_range(1, a - 1)
	_correct = a - b
	if led:
		led.text = "%d - %d = ?" % [a, b]
	_fill_answers(_correct)
func _q_mul() -> void:
	var a := randi_range(2, 6)
	var b := randi_range(2, 6)
	_correct = a * b
	if led:
		led.text = "%d × %d = ?" % [a, b]
	_fill_answers(_correct)
func _q_div() -> void:
	var b := randi_range(2, 6)
	var ans := randi_range(2, 6)
	var a := b * ans
	_correct = ans
	if led:
		led.text = "%d ÷ %d = ?" % [a, b]
	_fill_answers(_correct)
func _q_pemdas() -> void:
	var kind := randi() % 3
	if kind == 0:
		var a := randi_range(1, 6)
		var b := randi_range(2, 4)
		var c := randi_range(2, 4)
		_correct = a + b * c
		if led:
			led.text = "%d + %d × %d = ?" % [a, b, c]
	elif kind == 1:
		var b2 := randi_range(2, 4)
		var c2 := randi_range(2, 3)
		var a2 := b2 * c2 + randi_range(1, 6)
		_correct = a2 - b2 * c2
		if led:
			led.text = "%d - %d × %d = ?" % [a2, b2, c2]
	else:
		var b3 := randi_range(2, 4)
		var c3 := randi_range(2, 3)
		var a3 := b3 + randi_range(1, 6)
		var top := b3 * c3
		_correct = a3 - b3
		if led:
			led.text = "%d - %d ÷ %d = ?" % [a3, top, c3]
	_fill_answers(_correct)
func _fill_answers(right: int) -> void:
	if answers == null:
		return
	var opts: Array[int] = [right]
	while opts.size() < 3:
		var fake: int = right + randi_range(-5, 5)
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
	if int(btn.get_meta("value")) == _correct:
		_play(correct_sound)
		take_hit()
		if _alive:
			_new_question()
	else:
		_play(wrong_sound)
		failed_answer.emit()
		hp = mini(max_hp, hp + heal_on_wrong)
		_apply_hull_tex()
		_refresh_health_bar(true)
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
	if _is_desperate() and hull and _alive:
		var pulse := 0.15 + 0.15 * sin(Time.get_ticks_msec() / 1000.0 * 6.0)
		hull.modulate = Color(1.0 + pulse, 1.0 + pulse, 1.0 + pulse)
	if nav_light and _alive:
		var a := 0.12 + 0.88 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 0.9))
		var mcol := nav_light.modulate
		mcol.a = a
		nav_light.modulate = mcol
	if hull and _alive:
		var u := 1.0 - float(hp) / float(maxi(max_hp, 1))
		var t := Time.get_ticks_msec() / 1000.0
		var lumber := 0.45 + u * 0.7
		hull.position = _hull_home + Vector2(sin(t * 0.32) * lumber_move * lumber, sin(t * 0.21 + 1.0) * lumber_move * 0.35 * lumber)
		hull.rotation = _hull_rot + sin(t * 0.24) * lumber_rot * lumber
	if _prop and _alive and _parked and not _prop_gone:
		_prop.rotation = _prop_park + sin(Time.get_ticks_msec() / 1000.0 * prop_wiggle_speed) * prop_wiggle
		_prop.position = _prop_home
	if _is_desperate() and _alive:
		_spark_cd -= delta
		if _spark_cd <= 0.0:
			_boom()
			_spark_cd = randf_range(0.25, 0.55)
	if not (_alive and _parked):
		_force_rockets_off()
		return
	var rate := 0.5 if _is_desperate() else 1.0
	_trooper_cd -= delta
	if _trooper_cd <= 0.0:
		_spawn_trooper()
		_trooper_cd = trooper_interval * rate
	if _stage() == 1:
		_force_rockets_off()
		return
	if _phase < 0:
		_force_rockets_off()
		_rocket_cd -= delta
		if _rocket_cd <= 0.0 and _guns.size() > 0:
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
func _spawn_trooper() -> void:
	if trooper_scene == null:
		return
	var x := (_slot - 1) * trooper_spread
	_launch(trooper_scene, _park_global, _park_global + Vector2(x, trooper_drop), 0.7)
	_slot = (_slot + 1) % 3
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
		if not is_instance_valid(n):
			return
		if n.has_method("finish_travel"):
			n.finish_travel(n.position)
		else:
			n.set("_base_pos", n.position)
	)
func _pick_guns() -> void:
	_firing.clear()
	if _guns.size() == 1 or randf() > both_rocket_chance:
		_firing.append(randi() % _guns.size())
		return
	for i in _guns.size():
		_firing.append(i)
func _show_lights(a: float) -> void:
	for i in _guns.size():
		var m := _guns[i].modulate
		m.a = a if _firing.has(i) else 0.0
		_guns[i].modulate = m
func _force_rockets_off() -> void:
	for g in _guns:
		if g:
			g.modulate.a = 0.0
func _fire() -> void:
	_show_lights(0.0)
	_play(fire_sound)
	for i in _firing:
		_spawn_shell(_guns[i])
	_firing.clear()
	_phase = -1
	_rocket_cd = rocket_interval * (0.5 if _is_desperate() else 1.0)
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
	_boom()
	if hp <= 1 and not _prop_gone:
		_drop_prop()
	if hp <= 0:
		_die()
func _drop_prop() -> void:
	if _prop == null or _prop_gone:
		return
	_prop_gone = true
	var keep_pos: Vector2 = _prop.global_position
	var keep_rot: float = _prop.rotation
	var host := get_parent()
	if host == null:
		host = get_tree().current_scene
	_prop.reparent(host)
	_prop.global_position = keep_pos
	_prop.rotation = keep_rot
	var tw := _prop.create_tween()
	tw.set_parallel(true)
	tw.tween_property(_prop, "position", _prop.position + Vector2(randf_range(-60, 60), randf_range(160, 280)), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_prop, "rotation", _prop.rotation + randf_range(-1.0, 1.0), 0.8)
	tw.tween_property(_prop, "modulate:a", 0.0, 0.8)
	tw.chain().tween_callback(_prop.queue_free)
func _die() -> void:
	if not _alive:
		return
	_alive = false
	_hide_shield()
	_force_rockets_off()
	if health_bar:
		health_bar.visible = false
	if nav_light:
		nav_light.modulate.a = 0.0
	if answers:
		answers.visible = false
		answers.queue_free()
	_play(death_sound)
	PlayerData.currency += points
	PlayerData.save()
	defeated.emit()
	if hull and dead_texture:
		hull.texture = dead_texture
	for i in 3:
		_boom()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", position.y + 980.0, 5.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "rotation", rotation + 0.25, 5.0)
	tw.tween_property(self, "modulate:a", 0.0, 5.0)
	tw.chain().tween_callback(queue_free)
func _boom() -> void:
	if death_effect == null:
		return
	var fx := death_effect.instantiate()
	var host := get_parent()
	if host == null:
		return
	host.add_child(fx)
	var mid := _park_global + Vector2(randf_range(-80.0, 80.0), randf_range(20.0, 80.0))
	if fx.has_method("setup"):
		fx.setup(mid)
	else:
		fx.global_position = mid
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
