extends Control
var p: Control

func _ready():
	p = owner


func _draw():
	draw_set_transform(
		p.plot_position * p.size / p.plot_scale,
		0,
		Vector2(1, -1))

	if p.sizes.size() == 0:
		if p.colors.size() == 0:
			for i in p.visible_point_count:
				draw_circle(p.raw_points[i] * size / p.plot_scale, p.base_size, p.color)

		else:
			for i in p.visible_point_count:
				draw_circle(p.raw_points[i] * size / p.plot_scale, p.base_size, p.colors[i])

	elif p.colors.size() == 0:
		for i in p.visible_point_count:
			draw_circle(p.raw_points[i] * size / p.plot_scale, p.sizes[i] * p.base_size, p.color)

	else:
		for i in p.visible_point_count:
			draw_circle(p.raw_points[i] * size / p.plot_scale, p.sizes[i] * p.base_size, p.colors[i])
