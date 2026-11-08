extends Node
const USE_SAVE := true
const SAVE_PATH := "user://save.cfg"
var sfx_volume: float = 1.0
var currency: int = 0
var run_start_currency: int = 0
var current_level: int = 1
var cleared_levels: Array[int] = []
const CLASS_MAX := 5
var current_class: String = "assault"
var assault_level: int = 1
var heavy_level: int = 1
var scout_level: int = 1
var time_trial_best: Dictionary = {}
var survival_best: Dictionary = {}
const BASE_HP := 4
var hp: int = 4
var trial_wave: int = 0
var selected_ability: String = "shield"
var shield_hp: int = 0
const SHIELD_MAX := 5
var beacon_time: float = 0.0
const BEACON_DURATION := 8.0
var ammo_time: float = 0.0
const AMMO_DURATION := 10.0
var music_volume: float = 1.0
const CLASS_ORDER: Array[String] = ["assault", "heavy", "scout"]
var owned_costumes: Array[String] = []
var equipped_costume: String = ""
const COSTUME_PRICE := 1000
var nurse_regen_timer: float = 0.0
const NURSE_REGEN_INTERVAL := 20.0
func _ready() -> void:
	if USE_SAVE:
		load_save()
	Music.play_main_menu()
func _process(delta: float) -> void:
	if beacon_time > 0.0:
		beacon_time = maxf(0.0, beacon_time - delta)
	if ammo_time > 0.0:
		ammo_time = maxf(0.0, ammo_time - delta)
	if equipped_costume == "nurse" and hp > 0 and hp < max_hp():
		nurse_regen_timer += delta
		if nurse_regen_timer >= NURSE_REGEN_INTERVAL:
			nurse_regen_timer = 0.0
			heal(1)
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
	time_trial_best.clear()
	survival_best.clear()
	owned_costumes.clear()
	equipped_costume = ""
	save()
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_4:
			currency += 100
			save()
			print("DEBUG +100 points. Now: ", currency)
		if event.keycode == KEY_V:
			_debug_solve()
func _debug_solve() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var nodes: Array[Node] = [scene]
	nodes.append_array(scene.find_children("*", "", true, false))
	for n in nodes:
		if not ("_correct" in n) or not n.has_method("_pick"):
			continue
		var right := str(n.get("_correct"))
		var answers: Node = n.get("answers")
		if answers == null:
			answers = scene.find_child("Answers", true, false)
		if answers == null:
			continue
		for i in 4:
			var btn := answers.get_node_or_null("Answer%d" % i)
			if btn == null or not btn.has_meta("value"):
				continue
			if str(btn.get_meta("value")) != right:
				continue
			n.call("_pick", i)
			return
func max_hp() -> int:
	var base := BASE_HP + clampi(class_level() - 1, 0, CLASS_MAX - 1)
	if equipped_costume == "armor":
		base += 5
	return base
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
	time_trial_best.clear()
	var trials := str(cfg.get_value("player", "time_trial_best", ""))
	for part in trials.split(",", false):
		var bits := part.split(":", false)
		if bits.size() != 2:
			continue
		time_trial_best[bits[0]] = int(bits[1])
	survival_best.clear()
	var surv := str(cfg.get_value("player", "survival_best", ""))
	for part in surv.split(",", false):
		var bits := part.split(":", false)
		if bits.size() != 2:
			continue
		survival_best[bits[0]] = int(bits[1])
	owned_costumes.clear()
	var owned = cfg.get_value("player", "owned_costumes", [])
	for x in owned:
		owned_costumes.append(str(x))
	equipped_costume = str(cfg.get_value("player", "equipped_costume", ""))
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
	cfg.set_value("player", "owned_costumes", owned_costumes)
	cfg.set_value("player", "equipped_costume", equipped_costume)
	var trials := ""
	for id in time_trial_best.keys():
		if trials != "":
			trials += ","
		trials += "%s:%d" % [str(id), int(time_trial_best[id])]
	cfg.set_value("player", "time_trial_best", trials)
	var surv := ""
	for id in survival_best.keys():
		if surv != "":
			surv += ","
		surv += "%s:%d" % [str(id), int(survival_best[id])]
	cfg.set_value("player", "survival_best", surv)
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
			d = 10
		"scout":
			d = 3
		_:
			d = 5
	if equipped_costume == "hunter":
		d = roundi(float(d) * 1.5)
	if beacon_time > 0.0:
		d *= 4
	return d
func reload_time() -> float:
	var lvl := clampi(class_level(), 1, 5)
	return 2.0 - float(lvl - 1) * 0.2
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
func time_trial_wave(id: String) -> int:
	return int(time_trial_best.get(id, 0))
func set_time_trial_wave(id: String, wave: int) -> void:
	trial_wave = wave
	var best: int = int(time_trial_best.get(id, 0))
	if wave <= best:
		return
	time_trial_best[id] = wave
	save()
func survival_wave(diff: String) -> int:
	return int(survival_best.get(diff, 0))
func record_survival(diff: String, waves: int) -> void:
	if waves <= survival_wave(diff):
		return
	survival_best[diff] = waves
	save()
func owns_costume(id: String) -> bool:
	return owned_costumes.has(id)
func buy_costume(id: String) -> bool:
	if owns_costume(id):
		return false
	if currency < COSTUME_PRICE:
		return false
	currency -= COSTUME_PRICE
	owned_costumes.append(id)
	save()
	return true
func equip_costume(id: String) -> void:
	if not owns_costume(id):
		return
	equipped_costume = id
	save()
func unequip_costume() -> void:
	equipped_costume = ""
	save()
func medal_rank_for_wave(wave: int) -> int:
	if wave >= 50:
		return 4
	if wave >= 40:
		return 3
	if wave >= 25:
		return 2
	if wave >= 10:
		return 1
	return 0
func get_medal_rank(key: String) -> int:
	var w := 0
	if time_trial_best.has(key):
		w = int(time_trial_best[key])
	elif survival_best.has(key):
		w = int(survival_best[key])
	return medal_rank_for_wave(w)
var survival_current: int = 0
func set_survival_current(wave: int) -> void:
	survival_current = wave
func clear_survival_current() -> void:
	survival_current = 0
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		pass
func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	var master := AudioServer.get_bus_index("Master")
	var music := AudioServer.get_bus_index("Music")
	var db := linear_to_db(sfx_volume) if sfx_volume > 0.001 else -80.0
	if master >= 0:
		AudioServer.set_bus_volume_db(master, db)
	if music >= 0:
		AudioServer.set_bus_volume_db(music, -db)
	save()
