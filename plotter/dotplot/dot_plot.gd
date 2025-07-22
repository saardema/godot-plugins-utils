extends Control

@onready var renderer: Control = %Renderer
@onready var sub_viewport: SubViewport = %SubViewport

var points: PackedVector2Array
var x_values: PackedFloat32Array
var y_values: PackedFloat32Array
var colors: PackedColorArray
var sizes: PackedFloat32Array
var plot_scale: Vector2 = Vector2(1, 1)
var plot_position: Vector2 = Vector2(0, 0)
var total_point_count: int
var visible_point_count: int

@export var dot_size: float = 30
@export var color: Color = Color.WHITE
@export_range(0, 1) var default_alpha: float = 1.0:
	set(v):
		default_alpha = clamp(v, 0, 1)
		color_a.a = default_alpha
		color_b.a = default_alpha

@export var color_a: Color = Color.BLUE:
	set(v):
		color_a = v
		color_a.a = default_alpha
@export var color_b: Color = Color.RED:
	set(v):
		color_b = v
		color_b.a = default_alpha
@export var color_mode: ColorMode = ColorMode.Gradient
@export var persistence: bool:
	set(v):
		persistence = v
		if not sub_viewport: return
		if persistence:
			sub_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
		else:
			sub_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS

func init(name_: String, plot_color := Color.WHITE):
	color = plot_color
	clear()
	resized.connect(blank)
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS

	if persistence:
		sub_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	else:
		sub_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS


func clear():
	points.clear()
	x_values.clear()
	y_values.clear()
	visible_point_count = 0
	total_point_count = 0
	resize_buffers()
	DebugTools.print('Cleared')
	blank()

func resize_buffers():
	DebugTools.print('Resizing buffer to %d' % [total_point_count])
	x_values.resize(total_point_count)
	y_values.resize(total_point_count)
	points.resize(total_point_count)
	sizes.resize(total_point_count)
	colors.resize(total_point_count)

	colors.fill(color)
	sizes.fill(1)

enum ColorMode {
	Binary,
	Gradient,
	Hue,
	Channel
}

enum PacketIndex {
	X,
	Y,
	Size,
	Color,
	Alpha
}

func plot_dots(packet: Array[PackedFloat32Array], content_size: int):
	if content_size > total_point_count:
		total_point_count = content_size
		resize_buffers()

	visible_point_count = content_size

	# Position
	x_values = packet[PacketIndex.X]
	y_values = packet[PacketIndex.Y]

	for p in min(x_values.size(), y_values.size()):
		points[p] = Vector2(x_values[p], y_values[p]) * size

	# Size
	for s in packet[PacketIndex.Size].size():
		sizes[s] = packet[PacketIndex.Size][s]

	# Color
	if color_mode == ColorMode.Binary:
		for c in packet[PacketIndex.Color].size():
			colors[c] = color_a if packet[PacketIndex.Color][c] < 0.5 else color_b

	elif color_mode == ColorMode.Hue:
		for c in packet[PacketIndex.Color].size():
			colors[c] = Color.from_hsv(packet[PacketIndex.Color][c], 1, 1)
			colors[c].a = default_alpha

	elif color_mode == ColorMode.Gradient:
		for c in packet[PacketIndex.Color].size():
			colors[c] = color_a.lerp(color_b, packet[PacketIndex.Color][c])

	else:
		colors.fill(color)

	# Alpha
	for i in packet[PacketIndex.Alpha].size():
		colors[i].a = packet[PacketIndex.Alpha][i]


func blank():
	if persistence:
		sub_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE

func update_transform(scale_in: Vector2, pos_in: Vector2):
	if plot_scale != scale_in:
		plot_scale = scale_in
		blank()

	if plot_position != pos_in:
		plot_position = pos_in
		blank()
	renderer.queue_redraw()
