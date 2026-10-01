extends TextureRect

@export var max_hp: int = 1
@export var contact_damage: int = 1
@export var life_time := 2.5
@export var start_scale := 0.45
@export var end_scale := 1.15
@export var wobble_move := 8.0
@export var wobble_speed := 5.0
@export var death_effect: PackedScene

@export var travel_sound: AudioStream
@export var hit_player_sound: AudioStream
@export var death_sound: AudioStream

@onready var hitbox: Control = get_node_or_null("Hitbox")
@onready var glow: TextureRect = get_node_or_null("Glow")

var hp: int = 1
var _alive := true
var _base := Vector2.ZERO
var _phase := 0.0
var _t := 0.0
var _flash := 0.0
var _spin_speed := 0.0
var _sfx: AudioStreamPlayer
var _travel: AudioStreamPlayer

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("projectiles")
	hp = max_hp
	if texture:
		size = texture.get_size()
	_base = position
	_phase = randf() * TAU
	_spin_speed = randf_range(-4.5, 4.5)
	if absf(_spin_speed) < 1.2:
		_spin_speed = 1.2 * signf(_spin_speed) if _spin_speed != 0.0 else 2.0
	pivot_offset = size * 0.5
	scale = Vector2.ONE * start_scale
	rotation = randf() * TAU
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if hitbox:
		hitbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if glow:
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.pivot_offset = glow.size * 0.5
	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)
	_travel = AudioStreamPlayer.new()
	add_child(_travel)
	if travel_sound:
		var s := travel_sound.duplicate()
		if s is AudioStreamWAV:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		elif s is AudioStreamOggVorbis:
			s.loop = true
		_travel.stream = s
		_travel.play()

func _process(delta: float) -> void:
	if not _alive:
		return
	_t += delta
	var u := clampf(_t / life_time, 0.0, 1.0)
	scale = Vector2.ONE * lerpf(start_scale, end_scale, u)
	rotation += _spin_speed * delta
	var w := Time.get_ticks_msec() / 1000.0 * wobble_speed + _phase
	position = _base + Vector2(sin(w) * wobble_move, cos(w * 1.37 + _phase) * wobble_move * 0.65)
	if glow:
		var pulse := 0.35 + 0.65 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 10.0))
		var gm := glow.modulate
		gm.a = pulse
		glow.modulate = gm
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			modulate = Color.WHITE
	if _t >= life_time:
		_detonate()

func contains_point(screen_pos: Vector2) -> bool:
	var box: Control = hitbox if hitbox else self
	if box == null:
		return false
	var local: Vector2 = box.get_global_transform().affine_inverse() * screen_pos
	return Rect2(Vector2.ZERO, box.size).has_point(local)

func receive_shot() -> void:
	if not _alive:
		return
	hp -= PlayerData.current_damage()
	_flash = 0.08
	modulate = Color(2.4, 2.4, 2.4)
	if hp <= 0:
		_pop()

func _stop_travel() -> void:
	if _travel and _travel.playing:
		_travel.stop()

func _detonate() -> void:
	if not _alive:
		return
	_alive = false
	_stop_travel()
	if hit_player_sound:
		_sfx.stream = hit_player_sound
		_sfx.play()
	var hud := get_tree().current_scene
	if hud != null and hud.has_method("apply_damage"):
		hud.apply_damage(contact_damage)
	get_tree().create_timer(0.15).timeout.connect(queue_free)

func _pop() -> void:
	_alive = false
	_stop_travel()
	if death_sound:
		_sfx.stream = death_sound
		_sfx.play()
	if death_effect:
		var fx := death_effect.instantiate()
		var host := get_parent()
		if host:
			host.add_child(fx)
		if fx.has_method("setup"):
			fx.setup(global_position + size * 0.5)
	get_tree().create_timer(0.15).timeout.connect(queue_free)
