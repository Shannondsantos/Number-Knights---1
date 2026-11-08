extends TextureButton
func _pressed() -> void:
	for i in range(1, 101):
		if not PlayerData.cleared_levels.has(i):
			PlayerData.cleared_levels.append(i)
	var trials: Array[String] = ["easy", "normal", "hard", "expert", "knight"]
	for t in trials:
		PlayerData.time_trial_best[t] = 50
		PlayerData.record_survival(t, 50)
	PlayerData.save()
	print("debug: levels 1-100 + all medals unlocked")
