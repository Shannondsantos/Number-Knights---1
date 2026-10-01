extends Control

@onready var points_label: Label = $PointsBox/PointsLabel

func _ready() -> void:
	Music.play_hub()
	points_label.text = "Points: %s" % PlayerData.currency
