extends TextureRect

signal died
signal attacked_player

@export var max_hp: int = 4
@export var points: int = 1
@export var contact_damage: int = 1
@export var dead_texture: Texture2D
@export var death_effect: PackedScene
@export var wobble_rot := 0.06
@export var wobble_speed := 3.0
@export var leash := 70.0
@export var dash_time := 0.18
@export var hold := 0.5
@export var attack_start_delay := 2.0
@export var attack_fade_in := 0.8
@export var attack_windup := 1.2
@export var attack_cooldown := 1.5
@export var attack_loop := true
@export var windup_sound: AudioStream
@export var attack_sound: AudioStream
@export var death_sound: AudioStream

var hp: int = 8
var _alive := true
var _base_pos := Vector2.ZERO
var _base_rot := 0.0
var _base_mod := Color.WHITE
var _indicators: Array[TextureRect] = []
var _attack_phase := -1
var _phase_t := 0.0
var _flash_left := 0.0
var _sfx: AudioStreamPlayer
var _traveling := false
var _attack_jitter := 0.0
var _wobble_phase := 0.0
var _hold := 0.5
var _dashing := false
var _dash_tw: Tween

func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp
	_base_pos = position
	_base_rot = rotation
	_base_mod = modulate
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wobble_phase = randf() * TAU
	_attack_jitter = randf_range(0.5, 1.0)
	_hold = randf_range(0.2, 0.9)
	_sfx = AudioStreamPlayer.new()
	_sfx.name = "EnemySfx"
	add_child(_sfx)
	_collect_indicators()
	_set_indicators_alpha(0.0)
	_attack_phase = -1
	_phase_t = -_attack_jitter

func _collect_indicators() -> void:
	_indicators.clear()
	for c in find_children("*", "TextureRect", true, false):
		if String(c.name).begins_with("Attack"):
			_indicators.append(c)

func _process(delta: float) -> void:
	if not _alive:
		return
	_drift(delta)
	_run_attack(delta)
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			modulate = _base_mod

func _drift(delta: float) -> void:
	if _traveling or _dashing:
		return
	var t := Time.get_ticks_msec() / 1000.0 * wobble_speed + _wobble_phase
	rotation = _base_rot + sin(t * 0.9) * wobble_rot
	_hold -= delta
	if _hold > 0.0:
		return
	_dash(_goal())

func _goal() -> Vector2:
	var ang := randf() * TAU
	var dist := randf_range(leash * 0.25, leash * randf_range(0.8, 1.15))
	return _base_pos + Vector2(cos(ang), sin(ang)) * dist

func _dash(dest: Vector2) -> void:
	_dashing = true
	if _dash_tw:
		_dash_tw.kill()
	var t := dash_time * randf_range(0.65, 1.35)
	_dash_tw = create_tween()
	_dash_tw.tween_property(self, "position", dest, t)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_dash_tw.finished.connect(func() -> void:
		_dashing = false
		_hold = hold * randf_range(0.55, 1.6)
	)

func _dodge() -> void:
	var away := position - _base_pos
	if away.length() < 8.0:
		away = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	_dash(_base_pos + away.normalized() * leash * randf_range(0.7, 1.0))

func _run_attack(delta: float) -> void:
	if _indicators.is_empty():
		return
	_phase_t += delta
	match _attack_phase:
		-1:
			_set_indicators_alpha(0.0)
			if _phase_t >= attack_start_delay:
				_attack_phase = 0
				_phase_t = 0.0
		0:
			if _phase_t <= delta:
				_play_sfx(windup_sound)
			var u := clampf(_phase_t / attack_fade_in, 0.0, 1.0)
			_set_indicators_alpha(u)
			if _phase_t >= attack_fade_in:
				_attack_phase = 1
				_phase_t = 0.0
		1:
			var u := clampf(_phase_t / attack_windup, 0.0, 1.0)
			var freq := lerpf(3.0, 16.0, u * u)
			var blink := 0.5 + 0.5 * sin(_phase_t * freq * TAU)
			_set_indicators_alpha(blink)
			if _phase_t >= attack_windup:
				_do_attack()
		2:
			_set_indicators_alpha(0.0)
			if _phase_t >= attack_cooldown + _attack_jitter:
				if attack_loop:
					_attack_jitter = randf_range(0.5, 1.0)
					_attack_phase = 0
					_phase_t = 0.0
				else:
					_attack_phase = 3

func _set_indicators_alpha(a: float) -> void:
	for i in _indicators:
		var m := i.modulate
		m.a = a
		i.modulate = m

func _do_attack() -> void:
	_set_indicators_alpha(0.0)
	_play_sfx(attack_sound)
	attacked_player.emit()
	var hud := _hud()
	if hud != null and hud.has_method("apply_damage"):
		hud.apply_damage(contact_damage)
	_attack_phase = 2
	_phase_t = 0.0

func receive_shot() -> void:
	if not _alive:
		return
	hp -= PlayerData.current_damage()
	_hit_feedback()
	if hp <= 0:
		_die()
	else:
		_dodge()

func _hit_feedback() -> void:
	_flash_left = 0.08
	modulate = Color(2.4, 2.4, 2.4)

func begin_travel() -> void:
	_traveling = true

func finish_travel(dest: Vector2) -> void:
	_traveling = false
	_base_pos = dest
	position = dest
	_hold = hold

func _spawn_death_effect() -> void:
	if death_effect == null:
		return
	var fx := death_effect.instantiate()
	var host := get_parent()
	if host == null:
		host = get_tree().current_scene
	host.add_child(fx)
	var mid := global_position + size * 0.5
	if fx.has_method("setup"):
		fx.setup(mid)
	else:
		fx.global_position = mid

func _die() -> void:
	if not _alive:
		return
	_alive = false
	_set_indicators_alpha(0.0)
	_play_sfx(death_sound)
	if dead_texture:
		texture = dead_texture
	PlayerData.currency += points
	PlayerData.save()
	died.emit()
	_spawn_death_effect()
	var fall_x := randf_range(-180.0, 180.0)
	var fall_y := randf_range(520.0, 860.0)
	var spin := randf_range(-1.4, 1.4)
	var fall_t := randf_range(0.4, 0.75)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position", position + Vector2(fall_x, fall_y), fall_t)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "rotation", rotation + spin, fall_t)
	tw.tween_property(self, "modulate:a", 0.0, fall_t)
	tw.chain().tween_callback(queue_free)

func _play_sfx(stream: AudioStream) -> void:
	if _sfx == null or stream == null:
		return
	_sfx.stream = stream
	_sfx.play()

func _hud() -> Node:
	var n := get_tree().current_scene
	if n != null and n.has_method("try_fire"):
		return n
	return get_tree().root.get_node_or_null("Game")
