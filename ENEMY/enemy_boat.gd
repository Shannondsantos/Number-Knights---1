extends Control

signal died

@export var max_hp: int = 75
@export var points: int = 5
@export var fly_time := 6.0
@export var travel_distance := 500.0
@export var fire_interval := 3.0
@export var shell_scene: PackedScene
@export var heal_drone_scene: PackedScene
@export var death_effect: PackedScene
@export var double_shot_chance := 0.25
@export var heal_side := 140.0
@export var heal_rise := 40.0
@export var heal_travel_time := 0.55
@export var hull_wobble_move := 5.0
@export var hull_wobble_rot := 0.04
@export var hull_wobble_speed := 2.4
@export var move_wobble_mul := 1.8
@export var attack_fade_in := 0.45
@export var attack_windup := 0.55
@export var hull_tex_100: Texture2D
@export var hull_tex_50: Texture2D
@export var hull_tex_20: Texture2D
@export var hull_tex_dead: Texture2D
@export var wave_frames: Array[Texture2D] = []
@export var wave_fps := 6.0
@export var water_loop: AudioStream
@export var windup_sound: AudioStream
@export var fire_sound: AudioStream
@export var death_sound: AudioStream

@onready var hull: TextureRect = $Hull
@onready var waves: TextureRect = get_node_or_null("Waves")

var hp: int = 75
var _alive := true
var _parked := false
var _park := Vector2.ZERO
var _guns: Array[TextureRect] = []
var _phase := -1
var _phase_t := 0.0
var _gun_i := 0
var _double_shot := false
var _fire_cd := 0.0
var _sfx: AudioStreamPlayer
var _water_sfx: AudioStreamPlayer
var _hull_home := Vector2.ZERO
var _hull_rot := 0.0
var _wphase := 0.0
var _flash := 0.0
var _hull_mod := Color.WHITE
var _wave_mod := Color.WHITE
var _wave_t := 0.0
var _wave_i := 0

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
	if waves == null:
		waves = get_node_or_null("Tracks")
	if waves:
		_wave_mod = waves.modulate
		waves.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_body_tex()
	_wphase = randf() * TAU
	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)
	_water_sfx = AudioStreamPlayer.new()
	add_child(_water_sfx)
	for c in find_children("*", "TextureRect", true, false):
		if String(c.name).begins_with("Attack"):
			_guns.append(c)
			c.modulate.a = 0.0
	call_deferred("_begin_approach")

func _begin_approach() -> void:
	if not _alive:
		return
	_park = position
	position = _park - Vector2(travel_distance, 0.0)
	_fly_in()

func contains_point(screen_pos: Vector2) -> bool:
	if hull and hull.get_global_rect().has_point(screen_pos):
		return true
	if waves and waves.get_global_rect().has_point(screen_pos):
		return true
	return false

func _pick_tex(tex_100: Texture2D, tex_50: Texture2D, tex_20: Texture2D) -> Texture2D:
	var ratio := float(hp) / float(maxi(max_hp, 1))
	if ratio > 0.5:
		return tex_100
	if ratio > 0.2:
		return tex_50
	return tex_20

func _apply_body_tex() -> void:
	if hull:
		var t := _pick_tex(hull_tex_100, hull_tex_50, hull_tex_20)
		if t:
			hull.texture = t

func _apply_dead_tex() -> void:
	if hull and hull_tex_dead:
		hull.texture = hull_tex_dead

func _loop_stream(src: AudioStream) -> AudioStream:
	if src == null:
		return null
	var s := src.duplicate()
	if s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif s is AudioStreamOggVorbis:
		s.loop = true
	return s

func _cycle_waves(delta: float) -> void:
	if waves == null or wave_frames.size() == 0:
		return
	_wave_t += delta
	var step := 1.0 / maxf(wave_fps, 0.1)
	if _wave_t < step:
		return
	_wave_t = 0.0
	_wave_i = (_wave_i + 1) % wave_frames.size()
	if wave_frames[_wave_i]:
		waves.texture = wave_frames[_wave_i]

func _fly_in() -> void:
	_parked = false
	if water_loop:
		_water_sfx.stream = _loop_stream(water_loop)
		_water_sfx.play()
	var tw := create_tween()
	tw.tween_property(self, "position", _park, fly_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void:
		_parked = true
		_fire_cd = fire_interval * 0.4 + randf_range(0.5, 1.0)
		if _water_sfx.playing:
			_water_sfx.stop()
	)

func _process(delta: float) -> void:
	_cycle_waves(delta)
	if not _alive:
		return
	_wobble_hull()
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			_clear_flash()
	if not _parked:
		return
	if _phase < 0:
		_fire_cd -= delta
		if _fire_cd <= 0.0 and _guns.size() > 0:
			_gun_i = randi() % _guns.size()
			_double_shot = randf() < double_shot_chance and _guns.size() >= 2
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

func _wobble_hull() -> void:
	if hull == null:
		return
	var mul := move_wobble_mul if not _parked else 1.0
	var t := Time.get_ticks_msec() / 1000.0 * hull_wobble_speed + _wphase
	hull.position = _hull_home + Vector2(sin(t * 1.7) * hull_wobble_move * 0.35 * mul, sin(t) * hull_wobble_move * mul)
	hull.rotation = _hull_rot + sin(t * 0.9) * hull_wobble_rot * mul

func _show_lights(a: float) -> void:
	for g in _guns.size():
		var on := g == _gun_i or _double_shot
		var m := _guns[g].modulate
		m.a = a if on else 0.0
		_guns[g].modulate = m

func _clear_lights() -> void:
	for g in _guns:
		var m := g.modulate
		m.a = 0.0
		g.modulate = m

func _fire() -> void:
	_clear_lights()
	_play(_sfx, fire_sound)
	if _guns.size() > _gun_i:
		_spawn_shell(_guns[_gun_i])
	if _double_shot and _guns.size() >= 2:
		_spawn_shell(_guns[1 - _gun_i])
	_double_shot = false
	_phase = -1
	_fire_cd = fire_interval + randf_range(0.5, 1.0)

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

func _spawn_heal_at(dest_global: Vector2) -> void:
	if heal_drone_scene == null:
		return
	var host := get_parent()
	if host == null:
		host = get_tree().current_scene
	var d := heal_drone_scene.instantiate()
	host.add_child(d)
	if not d is Control:
		return
	d.global_position = global_position
	if d.has_method("begin_travel"):
		d.begin_travel()
	var tw := d.create_tween()
	tw.tween_property(d, "global_position", dest_global, heal_travel_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void:
		if not is_instance_valid(d):
			return
		if d.has_method("finish_travel"):
			d.finish_travel(d.position)
		else:
			d.set("_base_pos", d.position)
	)

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
	if waves:
		waves.modulate = Color(6, 6, 6)

func _clear_flash() -> void:
	if hull:
		hull.modulate = _hull_mod
	if waves:
		waves.modulate = _wave_mod

func _die() -> void:
	if not _alive:
		return
	_alive = false
	_flash = 0.0
	_clear_flash()
	if _water_sfx.playing:
		_water_sfx.stop()
	_clear_lights()
	_play(_sfx, death_sound)
	_apply_dead_tex()
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
	if _parked:
		var origin := global_position
		_spawn_heal_at(origin + Vector2(-heal_side, -heal_rise))
		_spawn_heal_at(origin + Vector2(heal_side, -heal_rise))
	_wreck_hull()

func _wreck_hull() -> void:
	if hull == null:
		queue_free()
		return
	hull.position = _hull_home
	hull.rotation = _hull_rot
	var up := _hull_home + Vector2(0.0, -28.0)
	var rest := _hull_home + Vector2(6.0, 4.0)
	var tw := create_tween()
	tw.tween_property(hull, "position", up, 0.18)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(hull, "rotation", _hull_rot - 0.08, 0.18)
	tw.tween_property(hull, "position", rest, 0.35)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(hull, "rotation", _hull_rot + 0.22, 0.35)
	tw.tween_interval(0.35)
	tw.tween_property(self, "modulate:a", 0.0, 2.2)
	tw.tween_callback(queue_free)

func _play(player: AudioStreamPlayer, stream: AudioStream) -> void:
	if player == null or stream == null:
		return
	player.stream = stream
	player.play()
