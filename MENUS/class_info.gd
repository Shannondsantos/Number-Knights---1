extends Control

@onready var damage_bar: Control = get_node_or_null("ClassDamage")
@onready var ammo_bar: Control = get_node_or_null("ClassAmmo")
@onready var health_bar: Control = get_node_or_null("ClassHealth")

var _damage_w := 1.0
var _ammo_w := 1.0
var _health_w := 1.0
var _shown := ""
var _shown_mk := -1
var _damage_tw: Tween
var _ammo_tw: Tween
var _health_tw: Tween

func _ready() -> void:
	if damage_bar:
		_damage_w = damage_bar.size.x
		_pin(damage_bar)
	if ammo_bar:
		_ammo_w = ammo_bar.size.x
		_pin(ammo_bar)
	if health_bar:
		_health_w = health_bar.size.x
		_pin(health_bar)
	_apply(false)

func _process(_delta: float) -> void:
	if PlayerData.current_class != _shown or PlayerData.class_level() != _shown_mk:
		_apply(true)

func _pin(bar: Control) -> void:
	bar.anchor_right = bar.anchor_left
	bar.offset_right = bar.offset_left + bar.size.x

func _apply(animate: bool) -> void:
	_shown = PlayerData.current_class
	_shown_mk = PlayerData.class_level()
	var damage := 5.0
	match _shown:
		"heavy":
			damage = 8.0
		"scout":
			damage = 2.0
	var ammo := float(PlayerData.assault_mag_size())
	var health := float(PlayerData.max_hp())
	_set_bar(damage_bar, _damage_w, damage / 8.0, animate, "damage")
	_set_bar(ammo_bar, _ammo_w, ammo / 55.0, animate, "ammo")
	_set_bar(health_bar, _health_w, health / 8.0, animate, "health")

func _set_bar(bar: Control, full_w: float, ratio: float, animate: bool, which: String) -> void:
	if bar == null:
		return
	var w := full_w * clampf(ratio, 0.08, 1.0)
	var tw: Tween = _damage_tw
	if which == "ammo":
		tw = _ammo_tw
	elif which == "health":
		tw = _health_tw
	if tw:
		tw.kill()
	if not animate:
		bar.size.x = w
		bar.offset_right = bar.offset_left + w
		return
	tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(bar, "size:x", w, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(bar, "offset_right", bar.offset_left + w, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if which == "ammo":
		_ammo_tw = tw
	elif which == "health":
		_health_tw = tw
	else:
		_damage_tw = tw
