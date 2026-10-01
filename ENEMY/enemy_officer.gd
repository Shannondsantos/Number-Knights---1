extends TextureRect

signal died
signal spawned_drone

@export var max_hp: int = 75
@export var points: int = 5
@export var dead_texture: Texture2D
@export var death_effect: PackedScene
@export var drone_scene: PackedScene

@export var spawn_distance := 150.0
@export var spawn_travel_time := 0.45
@export var rotation_rest := 5.0

@export var wobble_move := 4.0
@export var wobble_rot := 0.05
@export var wobble_speed := 2.0

@export var attack_start_delay := 2.0
@export var attack_fade_in := 0.8
@export var attack_windup := 1.2
@export var attack_cooldown := 1.8
@export var attack_loop := true

@export var windup_sound: AudioStream
@export var attack_sound: AudioStream
@export var death_sound: AudioStream
@export var burst_windup_sound: AudioStream
@export var burst_attack_sound: AudioStream
@export var burst_aura_texture: Texture2D

var hp: int = 25
var _alive := true
var _base_pos := Vector2.ZERO
var _base_rot := 0.0
var _base_mod := Color.WHITE
var _indicators: Array[TextureRect] = []
var _aura: TextureRect
var _attack_phase := -1
var _phase_t := 0.0
var _wait_time := 1.5
var _hit_tween: Tween
var _flash_left := 0.0
var _sfx: AudioStreamPlayer
var _spawn_index := 0
var _burst_next := false
var _traveling := false
var _attack_jitter := 0.0

var _wobble_phase := 0.0
var _wobble_speed_mul := 1.0
var _wobble_x_mul := 1.0
var _wobble_y_mul := 1.0

func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp
	_base_pos = position
	_base_rot = rotation
	_base_mod = modulate
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wobble_phase = randf() * TAU
	_wobble_speed_mul = randf_range(0.75, 1.25)
	_wobble_x_mul = randf_range(0.6, 1.3)
	_wobble_y_mul = randf_range(0.5, 1.2)
	_attack_jitter = randf_range(0.5, 1.0)
	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)
	_collect_indicators()
	_set_indicators_alpha(0.0)
	_set_aura_alpha(0.0)
	_attack_phase = -1
	_phase_t = -_attack_jitter

func _collect_indicators() -> void:
	_indicators.clear()
	_aura = get_node_or_null("Command_Aura") as TextureRect
	if _aura and burst_aura_texture:
		_aura.texture = burst_aura_texture
	for c in find_children("*", "TextureRect", true, false):
		if String(c.name).begins_with("Attack"):
			_indicators.append(c)

func _process(delta: float) -> void:
	if not _alive:
		return
	_wobble()
	_run_attack(delta)
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			modulate = _base_mod

func _wobble() -> void:
	if _traveling:
		return
	var t := Time.get_ticks_msec() / 1000.0 * wobble_speed * _wobble_speed_mul + _wobble_phase
	position = _base_pos + Vector2(
		sin(t) * wobble_move * _wobble_x_mul,
		cos(t * 1.3 + _wobble_phase) * wobble_move * 0.45 * _wobble_y_mul
	)
	rotation = _base_rot + sin(t * 0.9) * wobble_rot

func _run_attack(delta: float) -> void:
	if _indicators.is_empty() and _aura == null:
		return
	_phase_t += delta
	match _attack_phase:
		-1:
			_set_indicators_alpha(0.0)
			_set_aura_alpha(0.0)
			if _phase_t >= attack_start_delay:
				_attack_phase = 0
				_phase_t = 0.0
		0:
			if _phase_t <= delta:
				if _burst_next:
					_play_sfx(burst_windup_sound if burst_windup_sound else windup_sound)
				else:
					_play_sfx(windup_sound)
			var u := clampf(_phase_t / attack_fade_in, 0.0, 1.0)
			if _burst_next:
				_set_indicators_alpha(0.0)
				_set_aura_alpha(u)
			else:
				_set_aura_alpha(0.0)
				_set_indicators_alpha(u)
			if _phase_t >= attack_fade_in:
				_attack_phase = 1
				_phase_t = 0.0
		1:
			var u := clampf(_phase_t / attack_windup, 0.0, 1.0)
			var freq := lerpf(3.0, 16.0, u * u)
			var blink := 0.5 + 0.5 * sin(_phase_t * freq * TAU)
			if _burst_next:
				_set_indicators_alpha(0.0)
				_set_aura_alpha(blink)
			else:
				_set_aura_alpha(0.0)
				_set_indicators_alpha(blink)
			if _phase_t >= attack_windup:
				_do_attack()
		2:
			_set_indicators_alpha(0.0)
			_set_aura_alpha(0.0)
			if _phase_t >= _wait_time + _attack_jitter:
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

func _set_aura_alpha(a: float) -> void:
	if _aura == null:
		return
	var m := _aura.modulate
	m.a = a
	_aura.modulate = m

func _slot_offset(i: int) -> Vector2:
	match i % 4:
		0:
			return Vector2(0, -spawn_distance)
		1:
			return Vector2(-spawn_distance, 0)
		2:
			return Vector2(0, spawn_distance)
		_:
			return Vector2(spawn_distance, 0)

func _do_attack() -> void:
	_set_indicators_alpha(0.0)
	_set_aura_alpha(0.0)
	if _burst_next:
		_play_sfx(burst_attack_sound if burst_attack_sound else attack_sound)
		for i in 4:
			_spawn_drone_to(i)
		_burst_next = false
		_spawn_index = 0
		_wait_time = rotation_rest
	else:
		_play_sfx(attack_sound)
		_spawn_drone_to(_spawn_index)
		_spawn_index += 1
		if _spawn_index >= 4:
			_burst_next = true
		_wait_time = attack_cooldown
	_attack_phase = 2
	_phase_t = 0.0

func _spawn_drone_to(slot: int) -> void:
	if drone_scene == null:
		return
	var drone := drone_scene.instantiate()
	var host := get_parent()
	if host == null:
		host = get_tree().current_scene
	host.add_child(drone)
	if drone is Control:
		drone.position = _base_pos
		if drone.has_method("begin_travel"):
			drone.begin_travel()
		var dest := _base_pos + _slot_offset(slot)
		var tw := drone.create_tween()
		tw.tween_property(drone, "position", dest, spawn_travel_time)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.finished.connect(func() -> void:
			if is_instance_valid(drone) and drone.has_method("finish_travel"):
				drone.finish_travel(dest)
		)
	spawned_drone.emit()

func receive_shot() -> void:
	if not _alive:
		return
	hp -= PlayerData.current_damage()
	_hit_feedback()
	if hp <= 0:
		_die()

func _hit_feedback() -> void:
	_flash_left = 0.08
	modulate = Color(2.4, 2.4, 2.4)
	if _hit_tween:
		_hit_tween.kill()
	var ox := position.x
	_hit_tween = create_tween()
	_hit_tween.tween_property(self, "position:x", ox - 10.0, 0.04)
	_hit_tween.tween_property(self, "position:x", ox + 10.0, 0.04)
	_hit_tween.tween_property(self, "position:x", ox, 0.04)

func begin_travel() -> void:
	_traveling = true

func finish_travel(dest: Vector2) -> void:
	_traveling = false
	_base_pos = dest
	position = dest

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
	_set_aura_alpha(0.0)
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
