extends Control

signal died

@export var max_hp: int = 100
@export var points: int = 30
@export var fire_interval := 3.2
@export var shell_scene: PackedScene
@export var death_effect: PackedScene
@export var attack_fade_in := 0.45
@export var attack_windup := 0.55
@export var double_shot_chance := 0.2
@export var tex_100: Texture2D
@export var tex_50: Texture2D
@export var tex_25: Texture2D
@export var tex_dead: Texture2D
@export var windup_sound: AudioStream
@export var fire_sound: AudioStream
@export var death_sound: AudioStream

@onready var turret: TextureRect = get_node_or_null("Turret")
@onready var health: ColorRect = get_node_or_null("Health")

var hp: int = 500
var _alive := true
var _guns: Array[TextureRect] = []
var _phase := -1
var _phase_t := 0.0
var _gun_i := 0
var _double := false
var _fire_cd := 1.5
var _sfx: AudioStreamPlayer
var _flash := 0.0
var _turret_mod := Color.WHITE
var _bar_h := 0.0
var _bar_y := 0.0

func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if turret:
		turret.mouse_filter = Control.MOUSE_FILTER_IGNORE
		turret.pivot_offset = turret.size * 0.5
		_turret_mod = turret.modulate
		if tex_100 == null:
			tex_100 = turret.texture
		turret.texture = tex_100
	if health:
		health.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bar_h = health.size.y
		_bar_y = health.position.y
	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)
	for c in find_children("*", "TextureRect", true, false):
		if String(c.name).begins_with("Attack"):
			_guns.append(c)
			c.modulate.a = 0.0
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if c.pivot_offset == Vector2.ZERO:
				c.pivot_offset = c.size * 0.5
	_apply_tex()
	_set_bar(false)

func contains_point(screen_pos: Vector2) -> bool:
	if turret and turret.get_global_rect().has_point(screen_pos):
		return true
	return false

func _process(delta: float) -> void:
	if not _alive:
		return
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0 and turret:
			turret.modulate = _turret_mod
	if _phase < 0:
		_fire_cd -= delta
		if _fire_cd <= 0.0 and _guns.size() > 0:
			_gun_i = randi() % _guns.size()
			_double = randf() < double_shot_chance and _guns.size() >= 2
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
		var u := clampf(_phase_t / attack_windup, 0.0, 1.0)
		var freq := lerpf(4.0, 14.0, u * u)
		_show_lights(0.5 + 0.5 * sin(_phase_t * freq * TAU))
		if _phase_t >= attack_windup:
			_fire()

func _show_lights(a: float) -> void:
	for i in _guns.size():
		var on := i == _gun_i or _double
		var m := _guns[i].modulate
		m.a = a if on else 0.0
		_guns[i].modulate = m

func _fire() -> void:
	for g in _guns:
		var m := g.modulate
		m.a = 0.0
		g.modulate = m
	_play(fire_sound)
	if _guns.size() > _gun_i:
		_spawn_shell(_guns[_gun_i])
	if _double and _guns.size() >= 2:
		_spawn_shell(_guns[1 - _gun_i])
	_double = false
	_phase = -1
	_fire_cd = fire_interval + randf_range(0.4, 1.0)

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
	_flash = 0.1
	if turret:
		turret.modulate = Color(6, 6, 6)
	_apply_tex()
	_set_bar(true)
	if hp <= 0:
		_die()

func _apply_tex() -> void:
	if turret == null:
		return
	var ratio := float(hp) / float(maxi(max_hp, 1))
	var tex := tex_100
	if ratio <= 0.25:
		tex = tex_25
	elif ratio <= 0.5:
		tex = tex_50
	if tex:
		turret.texture = tex

func _set_bar(animate: bool) -> void:
	if health == null:
		return
	var ratio := clampf(float(hp) / float(maxi(max_hp, 1)), 0.0, 1.0)
	var h := _bar_h * ratio
	var y := _bar_y + (_bar_h - h)
	if not animate:
		health.size.y = h
		health.position.y = y
		return
	var tw := health.create_tween()
	tw.set_parallel(true)
	tw.tween_property(health, "size:y", h, 0.12)
	tw.tween_property(health, "position:y", y, 0.12)

func _die() -> void:
	if not _alive:
		return
	_alive = false
	if turret:
		turret.modulate = _turret_mod
		if tex_dead:
			turret.texture = tex_dead
	if health:
		health.visible = false
	for g in _guns:
		g.modulate.a = 0.0
	_play(death_sound)
	PlayerData.currency += points
	PlayerData.save()
	died.emit()
	if death_effect:
		var fx := death_effect.instantiate()
		var host := get_parent()
		if host == null:
			host = get_tree().current_scene
		host.add_child(fx)
		if fx.has_method("setup"):
			fx.setup(global_position)
	var tw := create_tween()
	tw.tween_interval(0.4)
	tw.tween_property(self, "modulate:a", 0.0, 1.4)
	tw.tween_callback(queue_free)

func _play(stream: AudioStream) -> void:
	if _sfx == null or stream == null:
		return
	_sfx.stream = stream
	_sfx.play()
