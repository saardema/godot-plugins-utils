# @tool
extends Plot

const Plot = preload('plot.gd')
var min_size: int

var line_width: float = 10:
	set(v):
		line_width = max(0, v)

func init(plot_color: Color = Color.WHITE):
	super.init(plot_color)
	resized.connect(rescale)

func clear(): pass

func plot(packet: Dictionary[Feature, PackedFloat32Array], content_size: int):
	super.plot(packet, content_size)
	rescale()


func update_transform(scale_in: Vector2, pos_in: Vector2):
	if plot_scale != scale_in or plot_position != pos_in:
		plot_scale = scale_in
		plot_position = pos_in
		rescale()

		queue_redraw()


func rescale():
	for p in visible_point_count:
		points[p] = raw_points[p] * size / plot_scale
	queue_redraw()


func _draw():
	if visible_point_count < 2: return

	draw_set_transform(
		plot_position * size / plot_scale,
		0,
		Vector2(1, -1))

	draw_polyline_colors(points, colors, line_width, true)
