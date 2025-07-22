extends Control
var p: Control

func _ready():
	p = owner

func _draw():
	draw_set_transform(
		p.plot_position * p.size / p.plot_scale,
		0,
		Vector2(1, -1))

	for point in p.visible_point_count:
		draw_circle(p.points[point] / p.plot_scale, p.sizes[point] * p.dot_size, p.colors[point])
