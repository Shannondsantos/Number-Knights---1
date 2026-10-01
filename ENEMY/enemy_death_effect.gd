extends Control

@export var piece_1: Texture2D
@export var piece_2: Texture2D
@export var piece_3: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for tex in [piece_1, piece_2, piece_3]:
		if tex:
			_burst(tex)
	# root dies after the slowest piece
	get_tree().create_timer(1.1).timeout.connect(queue_free)

func _burst(tex: Texture2D) -> void:
	var p := TextureRect.new()
	p.texture = tex
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size = tex.get_size()
	p.pivot_offset = p.size * 0.5
	p.position = -p.size * 0.5
	add_child(p)
	var dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.2, -0.2)).normalized()
	var pop := dir * randf_range(40.0, 110.0)
	var fall := Vector2(randf_range(-50.0, 50.0), randf_range(280.0, 520.0))
	var spin := randf_range(-2.2, 2.2)
	var pop_t := randf_range(0.12, 0.22)
	var fall_t := randf_range(0.45, 0.75)
	var tw := p.create_tween()
	tw.tween_property(p, "position", p.position + pop, pop_t)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(p, "rotation", spin * 0.35, pop_t)
	tw.tween_property(p, "position", p.position + pop + fall, fall_t)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(p, "rotation", spin, fall_t)
	tw.parallel().tween_property(p, "modulate:a", 0.0, fall_t)

func setup(world_pos: Vector2) -> void:
	global_position = world_pos
