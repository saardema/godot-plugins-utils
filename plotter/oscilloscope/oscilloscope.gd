#@tool
extends Plotter.Plot
const Uniform = ComputeSequencer.Uniform
const ImageUniform = ComputeSequencer.ImageUniform

@onready var texture_rect: TextureRect = $OutputTexture
var texture: Texture2DRD
var seq := ComputeSequencer.new()
var texture_dim: int
var texture_size: Vector2i
var feature_buffer_map: Dictionary[Feature, ComputeSequencer.BufferUniform] = {}
var features := Plotter.draw_mode_features[Plotter.DrawMode.Oscilloscope]
var image_uniform_set: ComputeSequencer.UniformSet
var rendered_transform: Vector4
var jitter := Vector2(1, 0)

@export_exp_easing() var blanking: float:
	set(v):
		blanking = clamp(v, 0, 100)
@export_range(0, 1) var intensity: float = 1
@export var jitter_size: float
@export_range(0, TAU) var jitter_freq: float = 2


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.echo and event.pressed:
		if event.keycode == KEY_R:
			_recompile_shader()

		elif event.keycode == KEY_P:
			seq.shaders['phosphor']._parse_shader()


func _ready():
	if not can_process(): return
	setup_shader()


func _recompile_shader():
	texture_rect.texture.texture_rd_rid = RID()
	seq.destroy()
	setup_shader()


func setup_shader():
	var phosphor := seq.add_shader("phosphor.glsl")
	var blank := seq.add_shader("blank.glsl")
	var image_format := RenderingDevice.DataFormat.DATA_FORMAT_R32G32B32A32_SFLOAT
	texture_dim = 512
	texture_size = Vector2i.ONE * texture_dim
	seq.add_image_uniform('output_texture', Texture2DRD.new(), texture_size, image_format)
	for f in features:
		var name: String = 'feature_' + Feature.keys()[f].to_snake_case()
		feature_buffer_map[f] = seq.create_buffer_uniform(name, 256)

	seq.auto_bind()
	seq.set_sequence([
		[
			# seq.shaders['diffuse'],
			seq.shaders['blank'],
			seq.shaders['phosphor'],
		]
	])
	seq.shaders['blank'].group_size = Vector3i(texture_dim / 16, texture_dim / 16, 1)
	texture_rect.texture = seq.uniforms['output_texture'].texture
	clear()


func _on_buffer_swap(primary_rid, secondary_rid):
	texture_rect.texture.texture_rd_rid = primary_rid

func plot(packet: Dictionary[Feature, PackedFloat32Array], content_size: int):
	var current_transform := Vector4(
		plot_position.x, plot_position.y,
		plot_scale.x, plot_scale.y
	)
	var data_range := packet[Feature.X][-1] - packet[Feature.X][0]
	var units_per_point := data_range / (content_size - 1)

	DebugTools.print([plot_position, plot_scale])
	jitter = jitter.rotated(jitter_freq + randf() * jitter_freq * 0.1).normalized()

	seq.push_constant.set_data([
		plot_scale,
		plot_position,
		plot_scale / Vector2(texture_size),
		texture_size,
		plot_scale.x / plot_scale.y,
		data_range,
		units_per_point,
		content_size,
		blanking + 0.5 if current_transform != rendered_transform else blanking,
		intensity,
		packet.has(Feature.Alpha),
		jitter * jitter_size
	])

	rendered_transform = current_transform

	seq.shaders['phosphor'].group_size = Vector3i((texture_size.x + 31) / 32, 3, 1)

	for feature in packet:
		feature_buffer_map[feature].update(packet[feature])
	seq.dispatch()


func update_transform(scale_in: Vector2, pos_in: Vector2):
	plot_scale = scale_in
	plot_position = pos_in


func clear():
	seq.uniforms['output_texture'].clear(Color(0, 0, 0, 0))


func _exit_tree(): if seq: seq.destroy()
