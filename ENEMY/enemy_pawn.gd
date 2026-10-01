extends TextureRect

signal died
signal attacked_player

@export var max_hp: int = 8
@export var points: int = 1
@export var contact_damage: int = 1
@export var dead_texture: Texture2D
@export var death_effect: PackedScene
@export var base_texture: Texture2D
@export var variant_textures: Array[Texture2D] = []

@export var wobble_move := 6.0
@export var wobble_rot := 0.08
@export var wobble_speed := 3.0

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
var _hit_tween: Tween
var _flash_left := 0.0
var _sfx: AudioStreamPlayer
var _traveling := false
var _attack_jitter := 0.0
var _wobble_phase := 0.0
var _wobble_speed_mul := 1.0
var _wobble_x_mul := 1.0
var _wobble_y_mul := 1.0

func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp
	_pick_look()
	_base_pos = position
	_base_rot = rotation
	_base_mod = modulate
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roll_wobble()
	_roll_jitter()
	_sfx = AudioStreamPlayer.new()
	_sfx.name = "EnemySfx"
	add_child(_sfx)
	_collect_indicators()
	_set_indicators_alpha(0.0)
	_attack_phase = -1
	_phase_t = -_attack_jitter

func _pick_look() -> void:
	var base := base_texture if base_texture else texture
	if variant_textures.is_empty() or randf() >= 0.5:
		if base:
			texture = base
		return
	var opts: Array[Texture2D] = []
	for t in variant_textures:
		if t:
			opts.append(t)
	if opts.is_empty():
		if base:
			texture = base
		return
	texture = opts[randi() % opts.size()]

func _roll_wobble() -> void:
	_wobble_phase = randf() * TAU
	_wobble_speed_mul = randf_range(0.75, 1.25)
	_wobble_x_mul = randf_range(0.6, 1.3)
	_wobble_y_mul = randf_range(0.5, 1.2)

func _roll_jitter() -> void:
	_attack_jitter = randf_range(0.5, 1.0)

func _collect_indicators() -> void:
	_indicators.clear()
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
	var x := sin(t) * wobble_move * _wobble_x_mul
	var y := cos(t * 1.3 + _wobble_phase) * wobble_move * 0.45 * _wobble_y_mul
	position = _base_pos + Vector2(x, y)
	rotation = _base_rot + sin(t * 0.9) * wobble_rot

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
					_roll_jitter()
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
