extends Control
signal parked
signal defeated
signal failed_answer
@export var max_hp: int = 25
@export var points: int = 55
@export var contact_damage: int = 1
@export var fly_time := 8.0
@export var travel_distance := 500.0
@export var drone_scene: PackedScene
@export var drone_drop := 190.0
@export var drone_spread := 130.0
@export var drone_interval_min := 5.5
@export var drone_interval_max := 7.0
@export var drone_fast_min := 3.2
@export var drone_fast_max := 4.2
@export var rush_time := 50.0
@export var hull_tex_100: Texture2D
@export var hull_tex_50: Texture2D
@export var hull_tex_25: Texture2D
@export var dead_texture: Texture2D
@export var death_effect: PackedScene
@export var prop_wiggle := 0.08
@export var prop_wiggle_speed := 1.6
@export var lumber_move := 12.0
@export var lumber_rot := 0.025
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
var hp: int = 8
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
var _drone_cd := 0.0
var _drone_slot := 0
var _parked_time := 0.0
var _shield_tw: Tween
var _shield_up := false
var _hp_fill: Control
var _hp_fill_w := 0.0
var _hp_tw: Tween
var _prop: TextureRect
var _prop_base := 0.0
var _prop_park := 0.0
var _prop_home := Vector2.ZERO
var _seen: Array[String] = []
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
	if _prop:
		_prop.rotation = _prop_base
		tw.tween_property(_prop, "rotation", _prop_park, fly_time).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(_on_parked)
func _on_parked() -> void:
	if not _alive:
		return
	_parked = true
	_parked_time = 0.0
	_park_global = global_position
	_park = position
	_drone_cd = randf_range(drone_interval_min, drone_interval_max)
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
func _diff() -> float:
	return 1.0 - clampf(float(hp) / float(maxi(max_hp, 1)), 0.0, 1.0)
func _new_question() -> void:
	if randf() < 0.45:
		_q_div()
	else:
		_q_mul()
func _q_mul() -> void:
	var d := _diff()
	var hi := int(lerpf(5, 12, d))
	var a := 0
	var b := 0
	var key := ""
	var found := false
	for _try in 40:
		a = randi_range(2, hi)
		b = randi_range(2, hi)
		key = "%d*%d" % [a, b]
		if _seen.has(key):
			continue
		found = true
		break
	if not found:
		_seen.clear()
		a = randi_range(2, hi)
		b = randi_range(2, hi)
		key = "%d*%d" % [a, b]
	_seen.append(key)
	_correct = a * b
	if led:
		led.text = "%d × %d = ?" % [a, b]
	_fill_answers(_correct)
func _q_div() -> void:
	var d := _diff()
	var hi := int(lerpf(5, 12, d))
	var b := 0
	var quot := 0
	var a := 0
	var key := ""
	var found := false
	for _try in 40:
		b = randi_range(2, hi)
		quot = randi_range(2, hi)
		a = b * quot
		key = "%d/%d" % [a, b]
		if _seen.has(key):
			continue
		found = true
		break
	if not found:
		_seen.clear()
		b = randi_range(2, hi)
		quot = randi_range(2, hi)
		a = b * quot
		key = "%d/%d" % [a, b]
	_seen.append(key)
	_correct = quot
	if led:
		led.text = "%d ÷ %d = ?" % [a, b]
	_fill_answers(_correct)
func _fill_answers(right: int) -> void:
	if answers == null:
		return
	var opts: Array[int] = [right]
	while opts.size() < 3:
		var fake: int = right + randi_range(-6, 6)
		if fake < 2 or fake == right or opts.has(fake):
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
	if _prop and _alive and _parked:
		_prop.rotation = _prop_park + sin(Time.get_ticks_msec() / 1000.0 * prop_wiggle_speed) * prop_wiggle
		_prop.position = _prop_home
	if not (_alive and _parked):
		return
	_parked_time += delta
	_drone_cd -= delta
	if _drone_cd <= 0.0:
		_spawn_wave()
		if _parked_time >= rush_time:
			_drone_cd = randf_range(drone_fast_min, drone_fast_max)
		else:
			_drone_cd = randf_range(drone_interval_min, drone_interval_max)
func _spawn_wave() -> void:
	if drone_scene == null:
		return
	var n := 3 if _parked_time >= rush_time else 2
	for k in n:
		var x := (_drone_slot - 1) * drone_spread
		_launch(drone_scene, _park_global, _park_global + Vector2(x, drone_drop), 0.7)
		_drone_slot = (_drone_slot + 1) % 3
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
