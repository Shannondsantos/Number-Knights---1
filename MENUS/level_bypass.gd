extends TextureButton
func _pressed() -> void:
	for i in range(1, 101):
		if not PlayerData.cleared_levels.has(i):
			PlayerData.cleared_levels.append(i)
	PlayerData.currency += 1000
	PlayerData.save()
	print("debug cleared 1-100 +1000 points")
