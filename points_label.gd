extends Label

func _process(_delta: float) -> void:
	text = "%s" % PlayerData.currency
