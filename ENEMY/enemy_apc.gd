extends Control
signal died
@export var max_hp: int = 35
@export var points: int = 5
@export var fly_time := 5.0
@export var travel_distance := 500.0
@export var fire_interval := 1.5
@export var shell_scene: PackedScene
@export var death_effect: PackedScene
@export var hull_wobble_move := 8.0
@export var hull_wobble_rot := 0.06
@export var hull_wobble_speed := 2.8
@export var move_wobble_mul := 2.4
@export var wheel_spin := 0.055
@export var attack_fade_in := 0.35
@export var attack_windup := 0.4
@export var hull_tex_100: Texture2D
@export var hull_tex_50: Texture2D
@export var hull_tex_25: Texture2D
@export var hull_tex_dead: Texture2D
@export var tracks_loop: AudioStream
@export var windup_sound: AudioStream
@export var fire_sound: AudioStream
@export var death_sound: AudioStream
@onready var hull: TextureRect = $Hull
var hp: int = 40
var _alive := true
var _parked := false
var _park := Vector2.ZERO
var _guns: Array[TextureRect] = []
var _wheels: Array[TextureRect] = []
var _phase := -1
var _phase_t := 0.0
var _gun_i := 0
var _fire_cd := 0.0
var _sfx: AudioStreamPlayer
var _tracks_sfx: AudioStreamPlayer
var _hull_home := Vector2.ZERO
var _hull_rot := 0.0
var _wphase := 0.0
var _flash := 0.0
var _hull_mod := Color.WHITE
var _last_x := 0.0
func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if hull:
		_hull_home = hull.position
		_hull_rot = hull.rotation
		_hull_mod = hull.modulate
		hull.pivot_offset = hull.size * 0.5
		if hull_tex_100 == null:
			hull_tex_100 = hull.texture
	_apply_body_tex()
	_wphase = randf() * TAU
	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)
	_tracks_sfx = AudioStreamPlayer.new()
	add_child(_tracks_sfx)
	for named in ["Wheel1", "Wheel2"]:
		var w := get_node_or_null(named)
		if w is TextureRect:
			var wheel := w as TextureRect
			wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if wheel.pivot_offset == Vector2.ZERO:
				wheel.pivot_offset = wheel.size * 0.5
			_wheels.append(wheel)
	var rocket := get_node_or_null("RocketIndicator1")
	if rocket is TextureRect:
		var g := rocket as TextureRect
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.modulate.a = 0.0
		_guns.append(g)
	call_deferred("_begin_approach")
func _begin_approach() -> void:
	if not _alive:
		return
	_park = position
	position = _park - Vector2(travel_distance, 0.0)
	_last_x = position.x
	_fly_in()
func contains_point(screen_pos: Vector2) -> bool:
	return hull != null and hull.get_global_rect().has_point(screen_pos)
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
func _loop_stream(src: AudioStream) -> AudioStream:
	if src == null:
		return null
	var s := src.duplicate()
	if s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif s is AudioStreamOggVorbis:
		s.loop = true
	return s
func _fly_in() -> void:
	_parked = false
	if tracks_loop:
		_tracks_sfx.stream = _loop_stream(tracks_loop)
		_tracks_sfx.play()
	var tw := create_tween()
	tw.tween_property(self, "position", _park, fly_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void:
		_parked = true
		_fire_cd = 0.6 + randf_range(0.2, 0.5)
		if _tracks_sfx.playing:
			_tracks_sfx.stop()
	)
func _process(delta: float) -> void:
	if not _alive:
		return
	_spin_wheels()
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
			_gun_i = 0
			_phase = 0
			_phase_t = 0.0
			_play(_sfx, windup_sound)
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
func _spin_wheels() -> void:
	var dx := position.x - _last_x
	_last_x = position.x
	if absf(dx) < 0.05:
		return
	for w in _wheels:
		if w:
			w.rotation += dx * wheel_spin
func _wobble_hull() -> void:
	if hull == null:
		return
	var mul := move_wobble_mul if not _parked else 1.0
	var t := Time.get_ticks_msec() / 1000.0 * hull_wobble_speed + _wphase
	hull.position = _hull_home + Vector2(sin(t * 1.7) * hull_wobble_move * 0.35 * mul, sin(t) * hull_wobble_move * mul)
	hull.rotation = _hull_rot + sin(t * 0.9) * hull_wobble_rot * mul
func _show_lights(a: float) -> void:
	if _guns.is_empty():
		return
	var m := _guns[0].modulate
	m.a = a
	_guns[0].modulate = m
func _clear_lights() -> void:
	for g in _guns:
		var m := g.modulate
		m.a = 0.0
		g.modulate = m
func _fire() -> void:
	_clear_lights()
	_play(_sfx, fire_sound)
	if _guns.size() > 0:
		_spawn_shell(_guns[0])
	_phase = -1
	_fire_cd = fire_interval + randf_range(0.15, 0.4)
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
func receive_shot() -> void:
	if not _alive:
		return
	hp -= PlayerData.current_damage()
	_flash_hit()
	_apply_body_tex()
	if hp <= 0:
		_die()
func _flash_hit() -> void:
	_flash = 0.12
	if hull:
		hull.modulate = Color(6, 6, 6)
func _die() -> void:
	if not _alive:
		return
	_alive = false
	_flash = 0.0
	if hull:
		hull.modulate = _hull_mod
	if _tracks_sfx.playing:
		_tracks_sfx.stop()
	_clear_lights()
	_play(_sfx, death_sound)
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
	_wreck_hull()
func _wreck_hull() -> void:
	if hull == null:
		queue_free()
		return
	hull.position = _hull_home
	hull.rotation = _hull_rot
	var up := _hull_home + Vector2(0.0, -18.0)
	var rest := _hull_home + Vector2(4.0, 3.0)
	var tw := create_tween()
	tw.tween_property(hull, "position", up, 0.14)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(hull, "rotation", _hull_rot - 0.06, 0.14)
	tw.tween_property(hull, "position", rest, 0.28)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(hull, "rotation", _hull_rot + 0.16, 0.28)
	tw.tween_interval(0.25)
	tw.tween_property(self, "modulate:a", 0.0, 1.6)
	tw.tween_callback(queue_free)
func _play(player: AudioStreamPlayer, stream: AudioStream) -> void:
	if player == null or stream == null:
		return
	player.stream = stream
	player.play()
