extends Control
@onready var ammo_icon: TextureRect = $AmmoIcon
@onready var hearts: TextureRect = $Hearts
@onready var reload_banner: TextureRect = $ReloadingBanner
@onready var reload_sound: AudioStreamPlayer = get_node_or_null("ReloadSound")
@onready var ammo_fill: Control = get_node_or_null("AmmoIcon/Fill")
@onready var hp_fill: Control = get_node_or_null("Hearts/Fill")
@onready var infinite_ammo: CanvasItem = get_node_or_null("AmmoIcon/InfiniteAmmo")
@export var reload_sound_stream: AudioStream
var ammo: int = 0
var mag: int = 10
var reloading := false
var _reload_tween: Tween
var _spinning := false
var _spin_time := 0.0
var _spin_duration := 2.0
var _banner_base_rot := 0.0
var _ammo_fill_w := 1.0
var _hp_fill_w := 1.0
var _ammo_tw: Tween
var _hp_tw: Tween
func _ready() -> void:
	PlayerData.reset_run()
	PlayerData.mark_run_start()
	mag = PlayerData.assault_mag_size()
	ammo = mag
	if reload_banner:
		reload_banner.modulate.a = 0.0
		_banner_base_rot = reload_banner.rotation
		reload_banner.pivot_offset = reload_banner.size * 0.5
	if ammo_fill:
		_ammo_fill_w = ammo_fill.size.x
	if hp_fill:
		_hp_fill_w = hp_fill.size.x
	if infinite_ammo:
		infinite_ammo.visible = false
	_refresh_ammo(false)
	_refresh_hp(false)
func _process(delta: float) -> void:
	if _spinning and reload_banner:
		_spin_time += delta
		var u := clampf(_spin_time / _spin_duration, 0.0, 1.0)
		var speed := lerpf(1.2, 14.0, u * u)
		reload_banner.rotation += speed * delta
		if u > 0.55:
			reload_banner.modulate.a = 1.0 - (u - 0.55) / 0.45
	_refresh_infinite()
	if PlayerData.equipped_costume == "nurse":
		_refresh_hp(false)
func try_fire() -> bool:
	if reloading:
		return false
	if PlayerData.ammo_time > 0.0:
		return true
	if ammo <= 0:
		_start_reload()
		return false
	ammo -= 1
	_refresh_ammo(true)
	if ammo <= 0:
		_start_reload()
	return true
func request_reload() -> void:
	if reloading:
		return
	if PlayerData.ammo_time > 0.0:
		return
	if ammo >= mag:
		return
	_start_reload()
func _start_reload() -> void:
	if reloading:
		return
	reloading = true
	_spinning = true
	_spin_time = 0.0
	_spin_duration = PlayerData.reload_time()
	if reload_banner:
		reload_banner.rotation = _banner_base_rot
		reload_banner.modulate.a = 1.0
	if reload_sound and reload_sound_stream:
		reload_sound.stream = reload_sound_stream
		reload_sound.pitch_scale = 2.0 / maxf(_spin_duration, 0.2)
		reload_sound.play()
	if _reload_tween:
		_reload_tween.kill()
	_reload_tween = create_tween()
	_reload_tween.tween_interval(_spin_duration)
	_reload_tween.tween_callback(_finish_reload)
func _finish_reload() -> void:
	reloading = false
	_spinning = false
	ammo = mag
	_refresh_ammo(true)
	if reload_banner:
		reload_banner.modulate.a = 0.0
		reload_banner.rotation = _banner_base_rot
func apply_damage(amount: int = 1) -> void:
	if PlayerData.shield_up():
		PlayerData.eat_shield_hit()
		return
	PlayerData.take_hit(amount)
	_refresh_hp(true)
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("flash_hit"):
		player.flash_hit()
	if PlayerData.hp <= 0:
		var go := get_node_or_null("GameOverLayer")
		if go and go.has_method("show_lose"):
			go.show_lose()
func apply_heal(amount: int = 1) -> void:
	PlayerData.heal(amount)
	_refresh_hp(true)
	_flash_hp()
func _flash_hp() -> void:
	if hearts == null:
		return
	var tw := hearts.create_tween()
	tw.tween_property(hearts, "modulate", Color(2.4, 2.4, 2.4), 0.08)
	tw.tween_property(hearts, "modulate", Color.WHITE, 0.12)
func level_points() -> int:
	return PlayerData.level_points()
func hide_play_ui() -> void:
	for n in [
		"AmmoIcon", "Hearts", "ReloadingBanner", "PointsBox", "PointsBox2",
		"BackButton", "AbilityButton", "AbilityPrompt", "PauseButton", "ReloadButton",
	]:
		var node := get_node_or_null(n)
		if node:
			node.visible = false
func show_play_ui() -> void:
	for n in [
		"AmmoIcon", "Hearts", "ReloadingBanner", "PointsBox", "PointsBox2",
		"BackButton", "AbilityButton", "PauseButton", "ReloadButton",
	]:
		var node := get_node_or_null(n)
		if node:
			node.visible = true
	var prompt := get_node_or_null("AbilityPrompt")
	if prompt:
		prompt.visible = false
func _refresh_ammo(animate: bool = true) -> void:
	if ammo_fill == null:
		return
	var ratio := 0.0 if mag <= 0 else float(ammo) / float(mag)
	_tween_fill(ammo_fill, _ammo_fill_w, ratio, animate, true)
func _refresh_hp(animate: bool = true) -> void:
	if hp_fill == null:
		return
	var cap := PlayerData.max_hp()
	var ratio := 0.0 if cap <= 0 else float(PlayerData.hp) / float(cap)
	_tween_fill(hp_fill, _hp_fill_w, ratio, animate, false)
func _tween_fill(bar: Control, full_w: float, ratio: float, animate: bool, is_ammo: bool) -> void:
	var target := Vector2(full_w * clampf(ratio, 0.0, 1.0), bar.size.y)
	if not animate:
		bar.size = target
		return
	var tw: Tween = _ammo_tw if is_ammo else _hp_tw
	if tw:
		tw.kill()
	tw = bar.create_tween()
	tw.tween_property(bar, "size", target, 0.12).set_trans(Tween.TRANS_SINE)
	if is_ammo:
		_ammo_tw = tw
	else:
		_hp_tw = tw
func _refresh_infinite() -> void:
	if ammo_icon == null:
		return
	if PlayerData.ammo_time > 0.0:
		if infinite_ammo:
			infinite_ammo.visible = true
		var pulse: float = 0.75 + 0.25 * absf(sin(Time.get_ticks_msec() / 1000.0 * 5.0))
		ammo_icon.modulate = Color(1.0, 0.95, 0.55) * pulse
	else:
		if infinite_ammo:
			infinite_ammo.visible = false
		if not reloading:
			ammo_icon.modulate = Color.WHITE
func hit_all_under(screen_pos: Vector2) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if not bool(e.get("_alive")):
			continue
		if e.has_method("contains_point") and e.contains_point(screen_pos):
			if e.has_method("receive_shot"):
				e.receive_shot()
