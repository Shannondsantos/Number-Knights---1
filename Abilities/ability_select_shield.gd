extends TextureButton

func _pressed() -> void:
	PlayerData.selected_ability = "shield"
	PlayerData.save()
	print("ability = shield")
