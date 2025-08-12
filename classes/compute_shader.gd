@tool
class_name ComputeShader
extends Resource

signal shader_ready

# Local rendering device
var rd := RenderingServer.get_rendering_device()

# Shader storage buffer
var output_buffers: Array
var _buffer_types: Array[int]

# Compute Shader
var pipelines: Array[RID]
var uniform_sets: Array[RID]
var shaders: Array[RID]

# Optional array for params etc.
var _push_constant: PackedByteArray

var is_ready: bool = false
var is_initialized: bool = false

var uniforms: Array[RDUniform]
var buffer_rids: Array[RID]

var data_logger: DataLogger
var stopwatch = Utils.Stopwatch.new()

var texture_rids: Array[RID]
var textures: Array[Texture2DRD]

var default_usage_bits := (
	RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
	RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT |
	RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT |
	RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
)

func get_local_size_from_shader(shader_filepath):
	var file = FileAccess.open(shader_filepath, FileAccess.READ)

	if not file:
		printerr('Cannot read from shader. File not found.')
		return

	var regex := RegEx.new()
	regex.compile("local_size_\\w\\s*=\\s*(\\d{1,3})")

	var matches: Array[RegExMatch]

	for line_number in 15:
		var line := file.get_line()
		var line_matches := regex.search_all(line)
		if line_matches.size():
			matches.append_array(line_matches)

		if matches.size() == 3:
			var local_size: Vector3i
			local_size.x = int(matches[0].get_string(1))
			local_size.y = int(matches[1].get_string(1))
			local_size.z = int(matches[2].get_string(1))

			return local_size

	return null


func initialize():
	if is_initialized: uninitialize()
	is_initialized = true


func add_uniform_buffer(input_array, binding: int = -1, type: RenderingDevice.UniformType = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER):
	var input: PackedByteArray

	# Store type so it can be unpacked into its intrinsic type
	var buffer_type: int
	if input_array is PackedByteArray:
		input = input_array
		buffer_type = TYPE_PACKED_BYTE_ARRAY

	elif input_array is PackedFloat32Array:
		input = input_array.to_byte_array()
		buffer_type = TYPE_PACKED_FLOAT32_ARRAY

	elif input_array is PackedInt32Array:
		input = input_array.to_byte_array()
		buffer_type = TYPE_PACKED_INT32_ARRAY

	elif input_array is PackedVector2Array:
		input = input_array.to_byte_array()
		buffer_type = TYPE_PACKED_VECTOR2_ARRAY

	elif input_array is PackedVector3Array:
		input = input_array.to_byte_array()
		buffer_type = TYPE_PACKED_VECTOR3_ARRAY

	else:
		printerr("Unsupported buffer type: ", typeof(input_array))
		return

	_buffer_types.append(buffer_type)

	# Setup buffer
	var buffer_rid
	if type == RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER:
		buffer_rid = rd.storage_buffer_create(input.size(), input)
	else:
		buffer_rid = rd.uniform_buffer_create(input.size(), input)
	buffer_rids.append(buffer_rid)

	# Create a uniform to assign the buffer to the rendering device
	var uniform := RDUniform.new()
	uniform.uniform_type = type
	uniform.binding = uniforms.size() if binding == -1 else binding
	uniform.add_id(buffer_rid)
	uniforms.append(uniform)


func set_uniform_buffer(input_array, index: int):
	var byte_array = input_array if input_array is PackedByteArray else input_array.to_byte_array()
	rd.buffer_update(buffer_rids[index], 0, byte_array.size(), byte_array)


func add_uniform_texture(
		src_texture: Texture2DRD,
		texture_size: Vector2i,
		format: RenderingDevice.DataFormat = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT,
		usage_bits: int = -1):
	var tex_format := RDTextureFormat.new()
	tex_format.width = texture_size.x
	tex_format.height = texture_size.y
	tex_format.format = format
	tex_format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	tex_format.usage_bits = (default_usage_bits if usage_bits < 0 else usage_bits) as RenderingDevice.TextureUsageBits

	var texture_rid := rd.texture_create(tex_format, RDTextureView.new(), [])
	src_texture.texture_rd_rid = texture_rid

	texture_rids.append(texture_rid)

	var texture_uniform := RDUniform.new()
	texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	texture_uniform.binding = uniforms.size()
	texture_uniform.add_id(texture_rid)
	uniforms.append(texture_uniform)


func create_pipeline(shader_filepath: String, uniform_indices: Array[int]):
	if shader_filepath.length() == 0:
		printerr("Shader path not defined. Check shader path.")
		return

	var shader_file := load(shader_filepath)
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	var shader = rd.shader_create_from_spirv(shader_spirv)

	if not shader.is_valid():
		printerr("Error compiling shader. Cannot initialize")
		return

	shaders.append(shader)

	create_uniform_set(uniform_indices, shader)

	var pipeline = rd.compute_pipeline_create(shader)

	if rd.compute_pipeline_is_valid(pipeline):
		pipelines.append(pipeline)
		is_ready = true
		shader_ready.emit()


func create_uniform_set(uniform_indices: Array[int], shader_rid: RID, set_idx: int = 0):
	var uniform_set: Array[RDUniform]
	for i in uniform_indices: uniform_set.append(uniforms[i])

	uniform_sets.append(rd.uniform_set_create(uniform_set, shader_rid, set_idx))

func update_uniform_set(index: int, uniform_indices: Array[int], shader_rid: RID, set_idx: int = 0):
	var uniform_set: Array[RDUniform]
	for i in uniform_indices: uniform_set.append(uniforms[i])
	rd.free_rid(uniform_sets[index])
	uniform_sets[index] = rd.uniform_set_create(uniform_set, shader_rid, set_idx)

func set_push_constant_array(array: Array):
	var byte_array := PackedByteArray()
	for item in array:
		var bytes
		if item is float:
			bytes = PackedFloat32Array([item]).to_byte_array()
		else:
			bytes = var_to_bytes(item).slice(4)
		byte_array.append_array(bytes)

	# Push Constants size must be a multiple of 16
	byte_array.resize(ceil(byte_array.size() / 16.0) * 16)

	if _push_constant.size() == 0 or _push_constant.size() == byte_array.size():
		_push_constant = byte_array
	else:
		printerr(
			'Size mismatch of new push_constant array. Size %d should be %d.' %
			[byte_array.size(), _push_constant.size()]
		)


func clear_texture(index: int):
	rd.texture_clear(texture_rids[index], Color(0, 0, 0, 0), 0, 1, 0, 1)


func compute(pipeline_idx: int, groups_layout: Vector3i, uniform_set_indices: Array[int] = []):
	if not is_ready:
		printerr("Cannot execute shader. Pipeline is not (yet) ready.")
		return

	var compute_list: int = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipelines[pipeline_idx])

	uniform_set_indices.push_front(pipeline_idx)
	for i in uniform_set_indices.size():
		rd.compute_list_bind_uniform_set(compute_list, uniform_sets[uniform_set_indices[i]], i)

	if _push_constant and _push_constant.size():
		rd.compute_list_set_push_constant(compute_list, _push_constant, _push_constant.size())

	rd.compute_list_dispatch(compute_list, groups_layout.x, groups_layout.y, groups_layout.z)
	rd.compute_list_end()


func uninitialize() -> void:
	for rid in texture_rids:
		if rid.is_valid(): rd.free_rid(rid)
		rid = RID()

	for rid in pipelines:
		if rid.is_valid(): rd.free_rid(rid)
		rid = RID()

	for rid in shaders:
		if rid.is_valid(): rd.free_rid(rid)
		# rid = RID()

	for rid in uniform_sets:
		if rid.is_valid(): rd.free_rid(rid)
		rid = RID()

	for rid in buffer_rids:
		if rid.is_valid(): rd.free_rid(rid)
		rid = RID()

	buffer_rids = []
	output_buffers = []
	_buffer_types = []
	_push_constant = []
	uniforms = []
	uniform_sets = []
	texture_rids = []
	pipelines = []

	is_ready = false
	is_initialized = false
