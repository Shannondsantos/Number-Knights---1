extends Node

const USE_SAVE := true
const SAVE_PATH := "user://save.cfg"

var currency: int = 0
var run_start_currency: int = 0
var current_level: int = 1
var cleared_levels: Array[int] = []

const CLASS_MAX := 5
var current_class: String = "assault"
var assault_level: int = 1
var heavy_level: int = 1
var scout_level: int = 1

const BASE_HP := 4
var hp: int = 4

var selected_ability: String = "shield"
var shield_hp: int = 0
const SHIELD_MAX := 5
var beacon_time: float = 0.0
const BEACON_DURATION := 8.0
var ammo_time: float = 0.0
const AMMO_DURATION := 10.0

var music_volume: float = 1.0

const CLASS_ORDER: Array[String] = ["assault", "heavy", "scout"]

func _ready() -> void:
	if USE_SAVE:
		load_save()
	Music.play_main_menu()

func _process(delta: float) -> void:
	if beacon_time > 0.0:
		beacon_time = maxf(0.0, beacon_time - delta)
	if ammo_time > 0.0:
		ammo_time = maxf(0.0, ammo_time - delta)

func reset_to_default() -> void:
	currency = 0
	run_start_currency = 0
	current_class = "assault"
	assault_level = 1
	heavy_level = 1
	scout_level = 1
	hp = max_hp()
	shield_hp = 0
	beacon_time = 0.0
	selected_ability = "shield"
	current_level = 1
	cleared_levels.clear()
	save()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_4:
			currency += 100
			save()
			print("DEBUG +100 points. Now: ", currency)

func max_hp() -> int:
	return BASE_HP + clampi(class_level() - 1, 0, CLASS_MAX - 1)

func mark_run_start() -> void:
	run_start_currency = currency
	hp = max_hp()
	shield_hp = 0
	beacon_time = 0.0

func level_points() -> int:
	return maxi(0, currency - run_start_currency)

func discard_run() -> void:
	currency = run_start_currency
	shield_hp = 0
	beacon_time = 0.0

func commit_run() -> void:
	run_start_currency = currency

func load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	currency = int(cfg.get_value("player", "currency", currency))
	assault_level = clampi(int(cfg.get_value("upgrades", "assault_level", 1)), 1, CLASS_MAX)
	heavy_level = clampi(int(cfg.get_value("upgrades", "heavy_level", 1)), 1, CLASS_MAX)
	scout_level = clampi(int(cfg.get_value("upgrades", "scout_level", 1)), 1, CLASS_MAX)
	current_class = str(cfg.get_value("player", "current_class", "assault"))
	music_volume = clampf(float(cfg.get_value("player", "music_volume", 1.0)), 0.0, 1.0)
	selected_ability = str(cfg.get_value("player", "selected_ability", "shield"))
	var raw := str(cfg.get_value("player", "cleared_levels", ""))
	cleared_levels.clear()
	for part in raw.split(",", false):
		var id := int(part)
		if id > 0 and not cleared_levels.has(id):
			cleared_levels.append(id)

func save() -> void:
	if not USE_SAVE:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("player", "currency", currency)
	cfg.set_value("player", "current_class", current_class)
	cfg.set_value("upgrades", "assault_level", assault_level)
	cfg.set_value("upgrades", "heavy_level", heavy_level)
	cfg.set_value("upgrades", "scout_level", scout_level)
	cfg.set_value("player", "music_volume", music_volume)
	cfg.set_value("player", "selected_ability", selected_ability)
	var parts: PackedStringArray = []
	for id in cleared_levels:
		parts.append(str(id))
	cfg.set_value("player", "cleared_levels", ",".join(parts))
	cfg.save(SAVE_PATH)

func class_level(id: String = current_class) -> int:
	match id:
		"heavy":
			return heavy_level
		"scout":
			return scout_level
		_:
			return assault_level

func set_class_level(id: String, value: int) -> void:
	value = clampi(value, 1, CLASS_MAX)
	match id:
		"heavy":
			heavy_level = value
		"scout":
			scout_level = value
		_:
			assault_level = value

func cycle_class(dir: int) -> void:
	var i := CLASS_ORDER.find(current_class)
	if i < 0:
		i = 0
	i = (i + dir) % CLASS_ORDER.size()
	if i < 0:
		i += CLASS_ORDER.size()
	current_class = CLASS_ORDER[i]
	save()

func upgrade_cost(id: String = current_class) -> int:
	match class_level(id):
		1:
			return 20
		2:
			return 40
		3:
			return 250
		4:
			return 500
		_:
			return 0

func try_upgrade_current() -> bool:
	if class_level() >= CLASS_MAX:
		return false
	var cost := upgrade_cost()
	if currency < cost:
		return false
	currency -= cost
	set_class_level(current_class, class_level() + 1)
	save()
	return true

func assault_upgrade_cost() -> int:
	return upgrade_cost("assault")

func try_upgrade_assault() -> bool:
	current_class = "assault"
	return try_upgrade_current()

func reset_run() -> void:
	hp = max_hp()
	shield_hp = 0
	beacon_time = 0.0

func heal(amount: int = 2) -> void:
	hp = mini(max_hp(), hp + amount)
	print("healed +", amount, " now ", hp)

func assault_mag_size() -> int:
	var lvl := clampf(float(class_level() - 1) / 4.0, 0.0, 1.0)
	match current_class:
		"heavy":
			return roundi(lerpf(5.0, 20.0, lvl))
		"scout":
			return roundi(lerpf(20.0, 55.0, lvl))
		_:
			return roundi(lerpf(10.0, 35.0, lvl))

func current_damage() -> int:
	var d := 4
	match current_class:
		"heavy":
			d = 8
		"scout":
			d = 2
		_:
			d = 5
	if beacon_time > 0.0:
		d *= 4
	return d

func assault_reload_time() -> float:
	return 2.0 - (clampi(class_level("assault"), 1, 5) - 1) * 0.2

func take_hit(amount: int = 1) -> void:
	hp = max(0, hp - amount)

func ability_busy() -> bool:
	return shield_hp > 0 or beacon_time > 0.0 or ammo_time > 0.0

func spawn_ammo() -> void:
	if selected_ability != "ammo":
		return
	ammo_time = AMMO_DURATION

func spawn_shield() -> void:
	if selected_ability != "shield":
		return
	shield_hp = SHIELD_MAX

func spawn_beacon() -> void:
	if selected_ability != "beacon":
		return
	beacon_time = BEACON_DURATION

func shield_up() -> bool:
	return shield_hp > 0

func eat_shield_hit() -> bool:
	if shield_hp <= 0:
		return false
	shield_hp -= 1
	return true

func is_unlocked(level_id: int) -> bool:
	if level_id <= 1:
		return true
	return cleared_levels.has(level_id - 1)

func mark_cleared(level_id: int) -> void:
	if level_id <= 0 or cleared_levels.has(level_id):
		return
	cleared_levels.append(level_id)
	save()
