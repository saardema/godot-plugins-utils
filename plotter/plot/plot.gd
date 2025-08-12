# @tool
@abstract
extends Control
const Feature = Plotter.Feature
const LinePlot = preload('line_plot.gd')
var plot_scale: Vector2 = Vector2(1, 1)
var plot_position: Vector2 = Vector2(0, 0)
var raw_points: PackedVector2Array
var buffer_size: int
var visible_point_count: int
var points: PackedVector2Array
var colors: PackedColorArray
var sizes: PackedFloat32Array
var use_individual_sizes: bool
var default_colors: PackedColorArray

var is_default: Dictionary[Feature, bool] = {
	Feature.X: false,
	Feature.Y: false,
	Feature.Size: false,
	Feature.Color: false,
	Feature.Alpha: false
}

@export var base_size: float = 1

@export var color := Color.WHITE:
	set(v):
		color = v
		color.a = default_alpha

@export var color_a := Color(0, 0.645, 0.89):
	set(v):
		color_a = v
		color_a.a = default_alpha

@export var color_b := Color(1, 0.192, 0.773):
	set(v):
		color_b = v
		color_b.a = default_alpha

@export_range(0, 1) var default_alpha: float = 1.0:
	set(v):
		default_alpha = clamp(v, 0, 1)
		color.a = default_alpha
		color_a.a = default_alpha
		color_b.a = default_alpha

@export var color_mode: ColorMode = ColorMode.Gradient

enum ColorMode {
	Binary,
	Gradient,
	Hue,
	Auto
}

@abstract func update_transform(scale_in: Vector2, pos_in: Vector2)
@abstract func clear()


func init(plot_color: Color):
	color = plot_color
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS


func plot(packet: Dictionary[Feature, PackedFloat32Array], content_size: int):
	# for type in PacketIndex.keys():
	# 	var local = [raw_points, raw_points, sizes, colors, colors]
	# 	DebugTools.write(type, '%d (%d)' % [
	# 		packet[PacketIndex[type]].size(), local[PacketIndex[type]].size()
	# 	])
	if visible_point_count != content_size:
		visible_point_count = content_size
		points.resize(visible_point_count)

	if content_size > buffer_size:
		buffer_size = content_size
		colors.resize(buffer_size)
		raw_points.resize(buffer_size)
		if use_individual_sizes:
			sizes.resize(buffer_size)

	apply_points(packet)
	apply_colors(packet)
	apply_alpha(packet)
	if use_individual_sizes: apply_sizes(packet)

func handle_defaults(packet: Dictionary[Feature, PackedFloat32Array]):
	for feature in Feature.keys():
		if feature not in packet:
			if is_default[feature]: continue

			if feature == Feature.Size and use_individual_sizes:
				sizes.fill(base_size)
			elif feature == Feature.Color:
				colors.fill(color)
			elif feature == Feature.Alpha:
				for c in colors.size():
					colors[c].a = default_alpha
			else:
				var other = (feature + 1) % 2
				if other not in packet:
					raw_points.fill(Vector2(0, 0))
					is_default[other] = true
				else:
					for p in visible_point_count:
						raw_points[p][feature] = packet[feature][p]

			is_default[feature] = true

func apply_sizes(packet: Dictionary[Feature, PackedFloat32Array]):
	var data = packet.get(Feature.Size)
	if not data:
		if not is_default[Feature.Size]:
			sizes.fill(1)
			is_default[Feature.Size] = true
		return
	is_default[Feature.Size] = false
	for s in data.size(): sizes[s] = data[s]


func apply_points(packet: Dictionary[Feature, PackedFloat32Array]):
	var data_x = packet.get(Feature.X, [])
	var data_y = packet.get(Feature.Y, [])
	var sizes := Vector2i(data_x.size(), data_y.size())
	if not sizes:
		if not is_default[Feature.X]:
			raw_points.fill(Vector2(0, 0))
			is_default[Feature.X] = true
		return

	is_default[Feature.X] = false
	is_default[Feature.Y] = false

	for p in visible_point_count:
		raw_points[p].x = data_x[p] if p < sizes.x else 0.0
		raw_points[p].y = data_y[p] if p < sizes.y else 0.0


func apply_colors(packet: Dictionary[Feature, PackedFloat32Array]):
	var data = packet.get(Feature.Color)

	if not data:
		if not is_default[Feature.Color]:
			colors.fill(color)
			is_default[Feature.Color] = true
		return

	is_default[Feature.Color] = false

	if color_mode == ColorMode.Binary:
		for c in data.size():
			colors[c] = color_a if data[c] < 0.0 else color_b

	elif color_mode == ColorMode.Gradient:
		for c in data.size():
			colors[c] = color_a.lerp(color_b, data[c])

	elif color_mode == ColorMode.Hue:
		for c in data.size():
			colors[c] = Color.from_hsv(data[c], 1, 1)

	for c in range(data.size(), visible_point_count):
		colors[c] = color


func apply_alpha(packet: Dictionary[Feature, PackedFloat32Array]):
	var data = packet.get(Feature.Alpha)
	if not data:
		if not is_default[Feature.Alpha]:
			for c in colors.size():
				colors[c].a = default_alpha
			is_default[Feature.Alpha] = true
		return

	is_default[Feature.Alpha] = false

	for c in data.size():
		colors[c].a = data[c]

	for c in range(data.size(), visible_point_count):
		colors[c].a = default_alpha
