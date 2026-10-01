extends TextureButton

func _pressed() -> void:
	PlayerData.selected_ability = "beacon"
	PlayerData.save()
	print("ability = beacon")
