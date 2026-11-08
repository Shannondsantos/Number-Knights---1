extends Control
signal died
@export var max_hp: int = 80
@export var points: int = 15
@export var fly_time := 3.5
@export var drop_distance := 420.0
@export var fire_interval := 2.4
@export var shell_scene: PackedScene
@export var fodder_scene: PackedScene
@export var death_effect: PackedScene
@export var ball_spin := 0.55
@export var attack_fade_in := 0.4
@export var attack_windup := 0.5
@export var hull_wobble_move := 6.0
@export var hull_wobble_rot := 0.035
@export var hull_wobble_speed := 1.4
@export var hull_tex_100: Texture2D
@export var hull_tex_50: Texture2D
@export var hull_tex_25: Texture2D
@export var hull_tex_dead: Texture2D
@export var windup_sound: AudioStream
@export var fire_sound: AudioStream
@export var death_sound: AudioStream
@onready var hull: TextureRect = $Hull
@onready var orbit: Marker2D = get_node_or_null("Marker2D")
@onready var shield: TextureRect = get_node_or_null("MastermindShield")
var hp: int = 80
var _alive := true
var _parked := false
var _park := Vector2.ZERO
var _guns: Array[TextureRect] = []
var _phase := -1
var _phase_t := 0.0
var _gun_i := 0
var _fire_cd := 0.0
var _sfx: AudioStreamPlayer
var _flash := 0.0
var _hull_mod := Color.WHITE
var _hull_home := Vector2.ZERO
var _hull_rot := 0.0
var _wphase := 0.0
var _shield_tw: Tween
var _shield_flashing := false
func _ready() -> void:
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
	_apply_body_tex()
	_wphase = randf() * TAU
	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)
	if shield:
		shield.modulate.a = 0.0
		shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wire_balls()
	for c in find_children("*", "TextureRect", true, false):
		if String(c.name).begins_with("Attack"):
			_guns.append(c)
			c.modulate.a = 0.0
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	call_deferred("_begin_approach")
func _wire_balls() -> void:
	if orbit == null:
		return
	for c in orbit.get_children():
		if c is TextureRect and String(c.name).begins_with("Ball"):
			if c.has_signal("died"):
				c.died.connect(_on_ball_died)
func _on_ball_died() -> void:
	pass
func _balls_alive() -> int:
	if orbit == null:
		return 0
	var n := 0
	for c in orbit.get_children():
		if c is TextureRect and String(c.name).begins_with("Ball") and is_instance_valid(c) and bool(c.get("_alive")):
			n += 1
	return n
func _begin_approach() -> void:
	if not _alive:
		return
	_park = position
	position = _park + Vector2(0.0, -drop_distance)
	_fly_in()
func _fly_in() -> void:
	_parked = false
	var tw := create_tween()
	tw.tween_property(self, "position", _park, fly_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void:
		_parked = true
		_fire_cd = 0.8 + randf_range(0.2, 0.6)
	)
func contains_point(screen_pos: Vector2) -> bool:
	if hull and hull.get_global_rect().has_point(screen_pos):
		return true
	return false
func _pick_tex() -> Texture2D:
	var ratio := float(hp) / float(maxi(max_hp, 1))
	if ratio > 0.5:
		return hull_tex_100
	if ratio > 0.25:
		return hull_tex_50
	return hull_tex_25
func _apply_body_tex() -> void:
	if hull == null:
		return
	var t := _pick_tex()
	if t:
		hull.texture = t
func _process(delta: float) -> void:
	if not _alive:
		return
	if shield and not _shield_flashing:
		shield.modulate.a = 0.0
	_spin_orbit(delta)
	_wobble_hull()
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0 and hull:
			hull.modulate = _hull_mod
	if not _parked:
		return
	if _phase < 0:
		_fire_cd -= delta
		if _fire_cd <= 0.0 and _guns.size() > 0:
			_gun_i = randi() % _guns.size()
			_phase = 0
			_phase_t = 0.0
			_play(windup_sound)
		return
	_phase_t += delta
	match _phase:
		0:
			var u := clampf(_phase_t / attack_fade_in, 0.0, 1.0)
			_show_lights(u)
			if _phase_t >= attack_fade_in:
				_phase = 1
				_phase_t = 0.0
		1:
			var u := clampf(_phase_t / attack_windup, 0.0, 1.0)
			var freq := lerpf(4.0, 14.0, u * u)
			_show_lights(0.5 + 0.5 * sin(_phase_t * freq * TAU))
			if _phase_t >= attack_windup:
				_fire()
func _spin_orbit(delta: float) -> void:
	if orbit == null:
		return
	orbit.rotation += delta * ball_spin
func _wobble_hull() -> void:
	if hull == null:
		return
	var t := Time.get_ticks_msec() / 1000.0 * hull_wobble_speed + _wphase
	hull.position = _hull_home + Vector2(sin(t * 0.7) * hull_wobble_move * 0.4, sin(t) * hull_wobble_move)
	hull.rotation = _hull_rot + sin(t * 0.55) * hull_wobble_rot
func _show_lights(a: float) -> void:
	for i in _guns.size():
		var m := _guns[i].modulate
		m.a = a if i == _gun_i else 0.0
		_guns[i].modulate = m
func _clear_lights() -> void:
	for g in _guns:
		var m := g.modulate
		m.a = 0.0
		g.modulate = m
func _fire() -> void:
	_clear_lights()
	_play(fire_sound)
	if _guns.size() > _gun_i:
		_spawn_shell(_guns[_gun_i])
	_phase = -1
	_fire_cd = fire_interval + randf_range(0.2, 0.5)
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
func _flash_shield() -> void:
	if shield == null or _balls_alive() <= 0:
		return
	if _shield_tw:
		_shield_tw.kill()
	_shield_flashing = true
	shield.modulate.a = 0.85
	_shield_tw = create_tween()
	_shield_tw.tween_property(shield, "modulate:a", 0.0, 0.35)\
		.set_trans(Tween.TRANS_SINE)
	_shield_tw.finished.connect(func() -> void:
		_shield_flashing = false
		if shield:
			shield.modulate.a = 0.0
	)
func receive_shot() -> void:
	if not _alive:
		return
	if _balls_alive() > 0:
		_flash_shield()
		return
	hp -= PlayerData.current_damage()
	_flash = 0.12
	if hull:
		hull.modulate = Color(6, 6, 6)
	_apply_body_tex()
	if hp <= 0:
		_die()
func _die() -> void:
	if not _alive:
		return
	_alive = false
	_clear_lights()
	if shield:
		shield.modulate.a = 0.0
	_play(death_sound)
	if hull and hull_tex_dead:
		hull.texture = hull_tex_dead
	PlayerData.currency += points
	PlayerData.save()
	died.emit()
	if death_effect:
		var fx := death_effect.instantiate()
		var host := get_parent()
		if host:
			host.add_child(fx)
		if fx.has_method("setup"):
			fx.setup(global_position)
	_spawn_fodder_burst()
	_fall_off()
func _spawn_fodder_burst() -> void:
	if fodder_scene == null:
		return
	var origin := global_position
	if orbit:
		origin = orbit.global_position
	var offsets := [
		Vector2(0, -140),
		Vector2(-110, -40),
		Vector2(110, -40),
		Vector2(-80, 90),
		Vector2(80, 90),
	]
	var host := get_parent()
	if host == null:
		host = get_tree().current_scene
	for off in offsets:
		var n := fodder_scene.instantiate()
		host.add_child(n)
		if not n is Control:
			continue
		n.global_position = origin
		n.modulate.a = 0.0
		if "_base_pos" in n:
			n.set("_base_pos", n.position)
		if n.has_method("finish_travel"):
			n.finish_travel(n.position)
		var dest: Vector2 = origin + off
		var tw := n.create_tween()
		tw.set_parallel(true)
		tw.tween_property(n, "global_position", dest, 0.45)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "modulate:a", 1.0, 0.35)
		tw.finished.connect(func() -> void:
			if not is_instance_valid(n):
				return
			if "_base_pos" in n:
				n.set("_base_pos", n.position)
			if n.has_method("finish_travel"):
				n.finish_travel(n.position)
		)
func _fall_off() -> void:
	var fall_x := randf_range(-80.0, 80.0)
	var fall_y := randf_range(500.0, 740.0)
	var spin := randf_range(-0.5, 0.5)
	var fall_t := randf_range(1.1, 1.5)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position", position + Vector2(fall_x, fall_y), fall_t)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "rotation", rotation + spin, fall_t)
	tw.tween_property(self, "modulate:a", 0.0, fall_t)
	tw.chain().tween_callback(queue_free)
func _play(stream: AudioStream) -> void:
	if _sfx == null or stream == null:
		return
	_sfx.stream = stream
	_sfx.play()
