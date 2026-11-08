extends Control
signal parked
signal defeated
signal failed_answer
@export var max_hp: int = 10
@export var points: int = 30
@export var contact_damage: int = 1
@export var max_addend := 9
@export var fly_time := 4.0
@export var drop_distance := 420.0
@export var leave_time := 3.5
@export var drone_scene: PackedScene
@export var shell_scene: PackedScene
@export var drone_distance := 180.0
@export var drone_interval := 4.0
@export var fire_interval := 1.0
@export var arrive_sound: AudioStream
@export var correct_sound: AudioStream
@export var wrong_sound: AudioStream
@export var leave_sound: AudioStream
@export var windup_sound: AudioStream
@export var fire_sound: AudioStream
@export var tentacle_frames: Array[Texture2D] = []
@export var tentacle_fps := 6.0
@export var pulse_color := Color(0.85, 0.35, 1.0)
@export var pulse_speed := 1.4
@onready var hull: TextureRect = $Hull
@onready var led: Label = $LED
@onready var answers: Control = $Answers
@onready var nav_light: TextureRect = get_node_or_null("Attack_Indicator")
@onready var shield: TextureRect = get_node_or_null("Shield")
@onready var rocket: TextureRect = get_node_or_null("RocketIndicator1")
var hp: int = 10
var _alive := true
var _parked := false
var _correct := 0
var _park := Vector2.ZERO
var _park_global := Vector2.ZERO
var _sfx: AudioStreamPlayer
var _flash_left := 0.0
var _hull_mod := Color.WHITE
var _drone_cd := 0.0
var _fire_cd := 0.0
var _shield_tw: Tween
var _shield_up := false
var _seen: Array[String] = []
var _wave := 0
var tentacles: Array[TextureRect] = []
var _tentacle_t: Array[float] = []
func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp
	for i in 4:
		var t := get_node_or_null("Tentacles%d" % (i + 1)) as TextureRect
		tentacles.append(t)
		_tentacle_t.append(float(i) * 0.37)
	if hull:
		_hull_mod = hull.modulate
		hull.pivot_offset = hull.size * 0.5
	_hide_shield()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if answers:
		answers.visible = false
	if nav_light:
		nav_light.modulate.a = 0.2
	if rocket:
		rocket.modulate.a = 0.0
		rocket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)
	if answers:
		for i in 3:
			var btn := answers.get_node("Answer%d" % i) as BaseButton
			var idx := i
			btn.pressed.connect(func() -> void: _pick(idx))
	call_deferred("_begin_approach")
func _hide_shield() -> void:
	if shield == null:
		shield = get_node_or_null("Shield")
	if shield == null:
		return
	shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shield.visible = false
	var sm := shield.modulate
	sm.a = 0.0
	shield.modulate = sm
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
	var m := shield.modulate
	m.a = 0.0
	shield.modulate = m
	_shield_tw = create_tween()
	_shield_tw.tween_property(shield, "modulate:a", 0.55, 0.08)
	_shield_tw.tween_property(shield, "modulate:a", 0.0, 0.35)
	_shield_tw.finished.connect(_hide_shield)
func _begin_approach() -> void:
	if not _alive:
		return
	_hide_shield()
	_park = position
	_park_global = global_position
	position = _park + Vector2(0.0, -drop_distance)
	_fly_in()
func _process(delta: float) -> void:
	_anim_tentacles(delta)
	if hull and _flash_left <= 0.0 and _alive:
		var u := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * pulse_speed)
		hull.modulate = Color.WHITE.lerp(pulse_color, 0.18 * u)
	if shield and not _shield_up:
		_hide_shield()
	if hull and _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			hull.modulate = _hull_mod
	if nav_light and _alive:
		var a := 0.18 + 0.82 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 1.6))
		var mcol := nav_light.modulate
		mcol.a = a
		nav_light.modulate = mcol
	if not _alive or not _parked:
		return
	_drone_cd -= delta
	if _drone_cd <= 0.0:
		_burst_pawns()
		_drone_cd = drone_interval
	_fire_cd -= delta
	if _fire_cd <= 0.0:
		_fire_rocket()
		_fire_cd = fire_interval
func _anim_tentacles(delta: float) -> void:
	if tentacle_frames.is_empty():
		return
	for i in tentacles.size():
		var t := tentacles[i]
		if t == null:
			continue
		_tentacle_t[i] += delta
		var frame := int(_tentacle_t[i] * tentacle_fps) % tentacle_frames.size()
		if tentacle_frames[frame]:
			t.texture = tentacle_frames[frame]
func _fly_in() -> void:
	_parked = false
	_hide_shield()
	_play_sfx(arrive_sound)
	if led:
		led.text = ""
	var tw := create_tween()
	tw.tween_property(self, "position", _park, fly_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(_on_parked)
func _on_parked() -> void:
	if not _alive:
		return
	_parked = true
	_hide_shield()
	_park = position
	_park_global = global_position
	_drone_cd = drone_interval
	_fire_cd = 0.6
	var hud := _hud()
	if hud and answers and answers.get_parent() != hud:
		var gpos := answers.global_position
		answers.reparent(hud)
		answers.global_position = gpos
	if answers:
		answers.visible = true
		answers.mouse_filter = Control.MOUSE_FILTER_STOP
		for i in 3:
			var btn := answers.get_node("Answer%d" % i) as Control
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_new_question()
	parked.emit()
func _burst_pawns() -> void:
	if drone_scene == null:
		return
	var d := drone_distance
	var dirs: Array[Vector2]
	if _wave % 2 == 0:
		dirs = [
			Vector2(0, -d),
			Vector2(0, d),
			Vector2(-d, 0),
			Vector2(d, 0),
		]
	else:
		var c := d * 0.72
		dirs = [
			Vector2(-c, -c),
			Vector2(c, -c),
			Vector2(-c, c),
			Vector2(c, c),
		]
	_wave += 1
	for off in dirs:
		_launch_unit(drone_scene, _park_global, _park_global + off, 0.45)
func _fire_rocket() -> void:
	if rocket == null or shell_scene == null:
		return
	_play_sfx(windup_sound)
	var m := rocket.modulate
	m.a = 1.0
	rocket.modulate = m
	var tw := create_tween()
	tw.tween_property(rocket, "modulate:a", 0.0, 0.25)
	_play_sfx(fire_sound)
	var sh := shell_scene.instantiate() as Control
	if sh == null:
		return
	rocket.add_child(sh)
	if sh.texture:
		sh.size = sh.texture.get_size()
	if sh.pivot_offset == Vector2.ZERO:
		sh.pivot_offset = sh.size * 0.5
	sh.position = rocket.pivot_offset - sh.pivot_offset
	var keep: Vector2 = sh.global_position
	var host := get_parent()
	if host == null:
		host = get_tree().current_scene
	sh.reparent(host)
	sh.global_position = keep
	sh.set("_base", sh.position)
func _new_question() -> void:
	var key := ""
	var found := false
	var text := ""
	for _try in 80:
		var kind := randi() % 6
		match kind:
			0:
				# a + b × c
				var a := randi_range(1, 12)
				var b := randi_range(2, 6)
				var c := randi_range(2, 6)
				key = "%d+%d*%d" % [a, b, c]
				if _seen.has(key):
					continue
				_correct = a + b * c
				text = "%d + %d × %d = ?" % [a, b, c]
			1:
				# a × b + c
				var a := randi_range(2, 6)
				var b := randi_range(2, 6)
				var c := randi_range(1, 12)
				key = "%d*%d+%d" % [a, b, c]
				if _seen.has(key):
					continue
				_correct = a * b + c
				text = "%d × %d + %d = ?" % [a, b, c]
			2:
				# (a + b) × c
				var a := randi_range(1, 6)
				var b := randi_range(1, 6)
				var c := randi_range(2, 5)
				key = "(%d+%d)*%d" % [a, b, c]
				if _seen.has(key):
					continue
				_correct = (a + b) * c
				text = "(%d + %d) × %d = ?" % [a, b, c]
			3:
				# a × (b + c)
				var a := randi_range(2, 5)
				var b := randi_range(1, 6)
				var c := randi_range(1, 6)
				key = "%d*(%d+%d)" % [a, b, c]
				if _seen.has(key):
					continue
				_correct = a * (b + c)
				text = "%d × (%d + %d) = ?" % [a, b, c]
			4:
				# a - b × c
				var b := randi_range(2, 5)
				var c := randi_range(2, 4)
				var a := b * c + randi_range(1, 10)
				key = "%d-%d*%d" % [a, b, c]
				if _seen.has(key):
					continue
				_correct = a - b * c
				text = "%d - %d × %d = ?" % [a, b, c]
			_:
				# a ÷ b + c
				var b := randi_range(2, 5)
				var quot := randi_range(2, 6)
				var a := b * quot
				var c := randi_range(1, 8)
				key = "%d/%d+%d" % [a, b, c]
				if _seen.has(key):
					continue
				_correct = quot + c
				text = "%d ÷ %d + %d = ?" % [a, b, c]
		found = true
		break
	if not found:
		_seen.clear()
		_new_question()
		return
	_seen.append(key)
	if led:
		led.text = text
	var opts: Array[int] = [_correct]
	while opts.size() < 3:
		var fake: int = _correct + randi_range(-6, 6)
		if fake < 0 or fake == _correct or opts.has(fake):
			continue
		opts.append(fake)
	opts.shuffle()
	for i in 3:
		var lbl := answers.get_node("Answer%d/Label" % i) as Label
		lbl.text = str(opts[i])
		answers.get_node("Answer%d" % i).set_meta("value", opts[i])
func _pick(i: int) -> void:
	if not _alive or not _parked:
		return
	var val := int(answers.get_node("Answer%d" % i).get_meta("value"))
	if val == _correct:
		_hit_boss()
	else:
		_wrong()
func _hit_boss() -> void:
	hp -= 1
	_play_sfx(correct_sound)
	_flash()
	if hp <= 0:
		_leave()
		return
	_new_question()
func _wrong() -> void:
	_play_sfx(wrong_sound)
	failed_answer.emit()
	var hud := _hud()
	if hud != null and hud.has_method("apply_damage"):
		hud.apply_damage(contact_damage)
	_new_question()
func _flash() -> void:
	if hull == null:
		return
	_flash_left = 0.1
	hull.modulate = Color(2.4, 2.4, 2.4)
func _leave() -> void:
	_alive = false
	_parked = false
	_hide_shield()
	if nav_light:
		nav_light.modulate.a = 0.0
	if rocket:
		rocket.modulate.a = 0.0
	if answers:
		answers.visible = false
		answers.queue_free()
	_play_sfx(leave_sound)
	PlayerData.currency += points
	PlayerData.save()
	defeated.emit()
	var dest := _park + Vector2(0.0, -drop_distance)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position", dest, leave_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 0.0, leave_time)\
		.set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(queue_free)
func _launch_unit(packed: PackedScene, from_global: Vector2, dest_global: Vector2, t: float) -> void:
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
	tw.tween_property(n, "global_position", dest_global, t)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void:
		if not is_instance_valid(n):
			return
		if n.has_method("finish_travel"):
			n.finish_travel(n.position)
		else:
			n.set("_base_pos", n.position)
	)
func _play_sfx(stream: AudioStream) -> void:
	if _sfx == null or stream == null:
		return
	_sfx.stream = stream
	_sfx.play()
func _hud() -> Node:
	var n := get_tree().current_scene
	if n != null and n.has_method("apply_damage"):
		return n
	return get_tree().root.get_node_or_null("Game")
