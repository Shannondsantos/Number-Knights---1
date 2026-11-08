extends Control
@export var buy_sound: AudioStream
@export var equip_sound: AudioStream
@export var unequip_sound: AudioStream
var _selected := ""
var _sfx: AudioStreamPlayer
func _ready() -> void:
	Music.play_hub()
	_sfx = AudioStreamPlayer.new()
	_sfx.name = "StoreSfx"
	add_child(_sfx)
	_hide_all()
	$NurseButton.pressed.connect(func() -> void: _select("nurse", $NurseButton/SkinEquip))
	$ArmoredButton.pressed.connect(func() -> void: _select("armor", $ArmoredButton/SkinEquip))
	$HunterButton.pressed.connect(func() -> void: _select("hunter", $HunterButton/SkinEquip))
	$NurseButton/SkinEquip.pressed.connect(func() -> void: _on_equip_pressed("nurse", $NurseButton, $NurseButton/SkinEquip))
	$ArmoredButton/SkinEquip.pressed.connect(func() -> void: _on_equip_pressed("armor", $ArmoredButton, $ArmoredButton/SkinEquip))
	$HunterButton/SkinEquip.pressed.connect(func() -> void: _on_equip_pressed("hunter", $HunterButton, $HunterButton/SkinEquip))
func _hide_all() -> void:
	$NurseButton/SkinEquip.visible = false
	$ArmoredButton/SkinEquip.visible = false
	$HunterButton/SkinEquip.visible = false
func _select(id: String, equip_btn: TextureButton) -> void:
	_selected = id
	_hide_all()
	equip_btn.visible = true
	_refresh_equip(equip_btn, id)
func _refresh_equip(equip_btn: TextureButton, id: String) -> void:
	var lbl := equip_btn.get_node_or_null("Label") as Label
	if lbl == null:
		return
	if not PlayerData.owns_costume(id):
		lbl.text = str(PlayerData.COSTUME_PRICE)
		return
	if PlayerData.equipped_costume == id:
		lbl.text = "Unequip"
	else:
		lbl.text = "Equip"
func _flash(btn: TextureButton) -> void:
	var tw := btn.create_tween()
	tw.tween_property(btn, "modulate", Color(2.6, 2.6, 2.6), 0.06)
	tw.tween_property(btn, "modulate", Color.WHITE, 0.12)
func _on_equip_pressed(id: String, skin_btn: TextureButton, equip_btn: TextureButton) -> void:
	if not PlayerData.owns_costume(id):
		if PlayerData.buy_costume(id):
			PlayerData.equip_costume(id)
			_play(buy_sound)
			_flash(skin_btn)
			equip_btn.visible = false
			_refresh_equip(equip_btn, id)
		return
	if PlayerData.equipped_costume == id:
		PlayerData.unequip_costume()
		_play(unequip_sound)
	else:
		PlayerData.equip_costume(id)
		_play(equip_sound)
		_flash(skin_btn)
	equip_btn.visible = false
	_refresh_equip(equip_btn, id)
func _refresh_all() -> void:
	_refresh_equip($NurseButton/SkinEquip, "nurse")
	_refresh_equip($ArmoredButton/SkinEquip, "armor")
	_refresh_equip($HunterButton/SkinEquip, "hunter")
func _play(stream: AudioStream) -> void:
	if _sfx == null or stream == null:
		return
	_sfx.stream = stream
	_sfx.play()
