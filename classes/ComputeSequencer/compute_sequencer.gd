# @tool
class_name ComputeSequencer
extends Resource

#region Head

const StageShader = preload('stage_shader.gd')
const GLSLParser = preload("uid://cl3rds3t64fpm")

var rd := RenderingServer.get_rendering_device()
var local_rd: RenderingDevice
var push_constant := PushConstant.new(self )
var uniforms: Dictionary[StringName, Uniform]
var uniform_sets: Dictionary[RID, UniformSet]
var stages: Array[Stage]
var shaders: Dictionary[String, StageShader]
var double_buffers: Array[DoubleBuffer]

var is_dirty: bool:
	get:
		for container in [stages, uniforms, shaders, uniform_sets]:
			if container.size() > 0: return true
		return false

var use_local_rd: bool = false:
	set(v):
		if v == use_local_rd: return
		use_local_rd = v
		if is_dirty: destroy()
		if use_local_rd:
			if not local_rd:
				local_rd = RenderingServer.create_local_rendering_device()
			rd = local_rd
		else:
			rd = RenderingServer.get_rendering_device()

#endregion

#region DoubleBuffer

class DoubleBuffer:
	var seq: ComputeSequencer
	var enabled: bool = true
	var state: bool
	var sets: Array[UniformSet]
	var uniform_a: Uniform
	var uniform_b: Uniform
	var primary_rid: RID
	var secondary_rid: RID
	var callback: Callable

	func _init(
		sequencer: ComputeSequencer,
		a_uniform: Uniform,
		b_uniform: Uniform,
		callback_function = null
	):
		seq = sequencer
		uniform_a = a_uniform
		uniform_b = b_uniform
		callback = callback_function

		for shader in seq.shaders.values():
			for set in shader.uniform_sets:
				if uniform_a in set.uniforms or uniform_b in set.uniforms:
					set.add_swap_set(uniform_a, uniform_b)
					sets.append(set)

	func swap():
		if not enabled: return
		state = not state

		if state:
			primary_rid = uniform_b.data_rid
			secondary_rid = uniform_a.data_rid
		else:
			primary_rid = uniform_a.data_rid
			secondary_rid = uniform_b.data_rid

		for set in sets:
			set.swap(state)

		if callback:
			if callback.get_argument_count() == 1:
				callback.call(primary_rid)
			else:
				callback.call(primary_rid, secondary_rid)


func set_double_buffer(name_a: String, name_b: String, callback = null):
	var double_buffer := DoubleBuffer.new(
		self ,
		uniforms[name_a],
		uniforms[name_b],
		callback
	)

	double_buffers.append(double_buffer)

#endregion

#region Core methods

func auto_bind():
	for shader in shaders.values():
		for set_idx in shader.intel.sets:
			var set_uniforms := []
			for uniform_info in shader.intel.sets[set_idx]:
				var uniform: Uniform = uniforms.get(uniform_info.name)

				if not uniform:
					push_error('Uniform "%s" not defined. Cannot bind shader "%s"'
					% [uniform_info.name, shader.name])
					continue

				set_uniforms.append(uniform)
				uniform.bind(uniform_info.binding)
			shader.add_uniforms_as_set(set_uniforms, set_idx)


func dispatch():
	var compute_list_id: int = rd.compute_list_begin()
	for stage in stages:
		stage.dispatch(compute_list_id)
		rd.compute_list_add_barrier(compute_list_id)
	rd.compute_list_end()

	for buffer in double_buffers:
		buffer.swap()

func destroy():
	stages.clear()

	for shader in shaders.values():
		shader.destroy()
	shaders.clear()

	for set in uniform_sets.values():
		set.destroy()
	uniform_sets.clear()

	uniforms.clear()


func set_sequence(sequence: Array):
	stages.clear()
	for stage_shaders in sequence:
		var typed_shaders: Array[StageShader]
		typed_shaders.assign(stage_shaders)
		create_stage(typed_shaders)


func add_shader(path: String) -> StageShader:
	if not path.contains('/'):
		var source: String = get_stack()[1].source
		path = &"%s/%s" % [source.get_base_dir(), path]

	var shader := StageShader.new(self , path)
	shaders[shader.name] = shader

	return shader


#endregion


#region Uniform

func add_image_uniform(
		name: StringName,
		src_texture: Texture2D,
		texture_size: Vector2i,
		format: RenderingDevice.DataFormat = -1,
		usage_bits: int = -1) -> ImageUniform:
	var uniform := ImageUniform.new(
		self ,
		src_texture,
		texture_size,
		format,
		usage_bits)

	uniforms[name] = uniform

	return uniform


func create_buffer_uniform(
		name: StringName,
		data_size: int,
		type: Uniform.Type = Uniform.Type.StorageBuffer
	) -> Uniform:
	var buffer_uniform: BufferUniform

	if type == Uniform.Type.UniformBuffer:
		buffer_uniform = UniformBufferUniform.new(self )
	else:
		buffer_uniform = StorageBufferUniform.new(self )

	var input_array := PackedByteArray()
	input_array.resize(data_size * 4)
	buffer_uniform._set_data(input_array)
	uniforms[name] = buffer_uniform

	return buffer_uniform


@abstract class Uniform:
	var seq: ComputeSequencer
	var type: Uniform.Type
	var binding: int
	var rd_uniform: RDUniform
	var data_rid: RID

	enum Type {
		StorageBuffer = RenderingDevice.UniformType.UNIFORM_TYPE_STORAGE_BUFFER,
		UniformBuffer = RenderingDevice.UniformType.UNIFORM_TYPE_UNIFORM_BUFFER,
		Image = RenderingDevice.UNIFORM_TYPE_IMAGE
	}

	static func get_uniform_class(type: Type) -> GDScript:
		const _class_map := {
			Uniform.Type.StorageBuffer: StorageBufferUniform,
			Uniform.Type.UniformBuffer: UniformBufferUniform,
			Uniform.Type.Image: ImageUniform
		}

		return _class_map[type]


	func _init_uniform(sequencer: ComputeSequencer, uniform_type: Uniform.Type):
		seq = sequencer
		type = uniform_type


	func bind(binding_idx: int):
		if rd_uniform and binding != binding_idx:
			push_error("Uniform binding mismatch: %d != %d" % [binding, binding_idx])
		rd_uniform = RDUniform.new()
		rd_uniform.uniform_type = type as RenderingDevice.UniformType
		rd_uniform.add_id(data_rid)
		rd_uniform.binding = binding_idx
		binding = binding_idx


	func _set_rid(new_rid: RID):
		if new_rid.is_valid() and rd_uniform:
			rd_uniform.clear_ids()
			rd_uniform.add_id(new_rid)


class ImageUniform extends Uniform:
	const default_usage_bits := (
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT |
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	)

	var texture: Texture2D

	func _init(
		sequencer: ComputeSequencer,
		src_texture: Texture2D,
		texture_size: Vector2i,
		format: RenderingDevice.DataFormat = -1,
		usage_bits: int = -1):
		_init_uniform(sequencer, Uniform.Type.Image)

		texture = src_texture

		var tex_format := RDTextureFormat.new()
		if format == -1:
			format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
		tex_format.width = texture_size.x
		tex_format.height = texture_size.y
		tex_format.format = format
		tex_format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
		tex_format.usage_bits = default_usage_bits
		if usage_bits >= 0:
			tex_format.usage_bits = usage_bits as RenderingDevice.TextureUsageBits

		data_rid = seq.rd.texture_create(tex_format, RDTextureView.new(), [])

		if texture is Texture2DRD:
			texture.texture_rd_rid = data_rid

	func clear(color := Color(0, 0, 0, 1)):
		seq.rd.texture_clear(data_rid, color, 0, 1, 0, 1)


@abstract class BufferUniform extends Uniform:
	var data_type: int
	var data_size: int
	var byte_size: int

	const supported_types := [
		TYPE_PACKED_BYTE_ARRAY,
		TYPE_PACKED_FLOAT32_ARRAY,
		TYPE_PACKED_INT32_ARRAY,
		TYPE_PACKED_VECTOR2_ARRAY,
		TYPE_PACKED_VECTOR3_ARRAY
	]

	func _set_data(input_array):
		var bytes: PackedByteArray
		data_type = typeof(input_array)

		# Store type so it can be unpacked into its intrinsic type
		if input_array is PackedByteArray:
			bytes = input_array

		elif data_type in supported_types:
			bytes = input_array.to_byte_array()

		else:
			printerr("Unsupported buffer type: ", typeof(input_array))
			return

		byte_size = bytes.size()
		data_size = input_array.size()

		_create_buffer_rd(bytes)


	func _create_buffer_rd(bytes: PackedByteArray):
		if data_rid.is_valid():
			seq.rd.free_rid(data_rid)

		if self is StorageBufferUniform:
			data_rid = seq.rd.storage_buffer_create(byte_size, bytes)
		else:
			data_rid = seq.rd.uniform_buffer_create(byte_size, bytes)


	func update(input_array, from := 0, to := byte_size):
		seq.rd.buffer_update(data_rid, from, to, input_array.to_byte_array())

class StorageBufferUniform extends BufferUniform:
	func _init(sequencer: ComputeSequencer):
		_init_uniform(sequencer, Uniform.Type.StorageBuffer)


class UniformBufferUniform extends BufferUniform:
	func _init(sequencer: ComputeSequencer):
		_init_uniform(sequencer, Uniform.Type.UniformBuffer)

#endregion


#region UniformSet

func create_uniform_set(uniforms: Array[Uniform], shader: StageShader) -> UniformSet:
	var uset := UniformSet.new(self , uniforms, 0, shader)
	uniform_sets[uset.rid] = uset

	return uset


class UniformSet:
	var seq: ComputeSequencer
	var rid: RID
	var swap_set_rid: RID
	var active_rid: RID
	var uniforms: Array[Uniform]
	var primary_shader: StageShader
	var set_idx: int
	var rd_uniforms: Array:
		get: return uniforms.map(func(u): return u.rd_uniform)


	func _init(sequencer: ComputeSequencer, set_uniforms: Array[Uniform], set_index: int, shader: StageShader):
		seq = sequencer
		primary_shader = shader
		set_idx = set_index
		uniforms = set_uniforms
		_create_rd_uniform_set(set_index)


	func _create_rd_uniform_set(set_idx: int):
		if rid.is_valid(): seq.rd.free_rid(rid)
		rid = seq.rd.uniform_set_create(rd_uniforms, primary_shader.rid, set_idx)
		active_rid = rid


	func swap(state: bool):
		active_rid = swap_set_rid if state else rid


	func add_swap_set(uniform_a: Uniform, uniform_b: Uniform):
		var swap_rd_uniforms: Array[RDUniform] = []
		for uni in uniforms:
			var rd_uniform := RDUniform.new()
			rd_uniform.uniform_type = uni.rd_uniform.uniform_type
			rd_uniform.binding = uni.rd_uniform.binding

			if uni == uniform_a:
				rd_uniform.add_id(uniform_b.rd_uniform.get_ids()[0])
			elif uni == uniform_b:
				rd_uniform.add_id(uniform_a.rd_uniform.get_ids()[0])
			else:
				rd_uniform.add_id(uni.rd_uniform.get_ids()[0])
			swap_rd_uniforms.append(rd_uniform)

		swap_set_rid = seq.rd.uniform_set_create(swap_rd_uniforms, primary_shader.rid, set_idx)


	func destroy():
		if rid.is_valid(): seq.rd.free_rid(rid)
		if swap_set_rid.is_valid(): seq.rd.free_rid(swap_set_rid)

#endregion


#region PushConstant

class PushConstant:
	var seq: ComputeSequencer
	var size: int
	var bytes: PackedByteArray

	const type_lookup: Dictionary[int, Dictionary] = {
		TYPE_BOOL: {'stride': 4, 'offset': 0},
		TYPE_INT: {'stride': 4, 'offset': 0},
		TYPE_FLOAT: {'stride': 4, 'offset': 0},
		TYPE_VECTOR2: {'stride': 8, 'offset': 0},
		TYPE_VECTOR2I: {'stride': 8, 'offset': 0},
		TYPE_VECTOR3: {'stride': 16, 'offset': 0},
		TYPE_VECTOR3I: {'stride': 16, 'offset': 0},
		TYPE_VECTOR4: {'stride': 16, 'offset': 0},
		TYPE_VECTOR4I: {'stride': 16, 'offset': 0},
		TYPE_PACKED_FLOAT32_ARRAY: {'stride': 16, 'offset': 4},
		TYPE_PACKED_VECTOR2_ARRAY: {'stride': 16, 'offset': 4},
		-1: {'stride': 16, 'offset': 0}
	}

	func _init(sequencer: ComputeSequencer):
		seq = sequencer

	func _snap_up(value: int, increment: int) -> int:
		return ceili(float(value) / increment) * increment

	func set_data(data):
		var f32a: PackedFloat32Array = [0]
		var new_bytes := PackedByteArray()
		var item_bytes: PackedByteArray
		var type: int
		var stride: int
		var offset: int
		size = 0

		for i in data.size():
			type = typeof(data[i])
			if type not in type_lookup: type = -1
			stride = type_lookup[type].stride
			offset = type_lookup[type].offset
			if stride > 4:
				size = _snap_up(size, stride)
				new_bytes.resize(size)

			if type == TYPE_FLOAT:
				f32a[0] = data[i]
				item_bytes = var_to_bytes(f32a[0])
			else:
				item_bytes = var_to_bytes(data[i])

			item_bytes = item_bytes.slice(4 + offset)
			new_bytes.append_array(item_bytes)
			size = new_bytes.size()
			if stride > 4:
				size = _snap_up(size, stride)
				new_bytes.resize(size)

		# Push Constants size must be a multiple of 16
		size = _snap_up(new_bytes.size(), 16)
		new_bytes.resize(size)
		bytes = new_bytes

	func bind(compute_list_id):
		if size < 16: return
		seq.rd.compute_list_set_push_constant(compute_list_id, bytes, size)

#endregion


#region Stage

func create_stage(stage_shaders: Array[StageShader] = []) -> Stage:
	var stage := Stage.new(self )
	stage.shaders = stage_shaders
	stages.append(stage)

	return stage

class Stage:
	var seq: ComputeSequencer
	var shaders: Array[StageShader]
	var enabled: bool = true

	func _init(sequencer: ComputeSequencer):
		seq = sequencer


	func dispatch(compute_list_id: int = -1):
		if not enabled: return

		var standalone := compute_list_id == -1
		if standalone: compute_list_id = seq.rd.compute_list_begin()

		for shader in shaders:
			shader.dispatch(compute_list_id)

		if standalone:
			seq._end_compute_list(compute_list_id)

#endregion
