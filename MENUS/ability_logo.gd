extends TextureRect

@export var shield_icon: Texture2D
@export var ammo_icon: Texture2D
@export var beacon_icon: Texture2D

var _shown := ""

func _ready() -> void:
	_apply()

func _process(_delta: float) -> void:
	if _shown != PlayerData.selected_ability:
		_apply()

func _apply() -> void:
	_shown = PlayerData.selected_ability
	match _shown:
		"ammo":
			texture = ammo_icon
		"beacon":
			texture = beacon_icon
		_:
			texture = shield_icon
