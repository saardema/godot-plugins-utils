const UniformSet = ComputeSequencer.UniformSet
const Uniform = ComputeSequencer.Uniform
const GLSLParser = preload("uid://cl3rds3t64fpm")

var seq: ComputeSequencer
var shader_path: String
var rid: RID
var pipeline_rid: RID
var uniform_sets: Array[UniformSet]
var group_size := Vector3i(1, 1, 1)
var local_size := Vector3i(1, 1, 1)
var name: String
var intel: GLSLParser.ParseResult
var is_ready: bool

func _init(sequencer: ComputeSequencer, path: String):
	name = path.get_file().split('.')[0]
	seq = sequencer
	shader_path = path
	_parse_shader()
	is_ready = _create_pipeline()

func _parse_shader():
		intel = GLSLParser.parse(shader_path)
		print(intel.local_size)

		for uniform in intel.uniforms:
			printt(
				uniform.name.rpad(10),
				uniform.binding,
				uniform.set,
				uniform.format.rpad(6),
				GLSLParser.Uniform.Type.keys()[uniform.type],
			)

		print('-'.repeat(50))

func _create_pipeline() -> bool:
	var shader_file := load(shader_path)
	if shader_file == null:
		push_error('Shader file not found at "%s"' % shader_file)
		return false

	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	rid = seq.rd.shader_create_from_spirv(shader_spirv)

	if not rid.is_valid():
		push_error("Error compiling rid. RID is invalid")
		return false

	pipeline_rid = seq.rd.compute_pipeline_create(rid)

	return seq.rd.compute_pipeline_is_valid(pipeline_rid)


func _validate_set_idx(candidate_idx: int) -> int:
	if candidate_idx == -1:
		return uniform_sets.size()

	if not uniform_sets.has(candidate_idx):
		return candidate_idx

	push_error("Uniform set with index %d already exists." % candidate_idx)

	return -1


func add_uniforms_as_set(uniforms: Array, set_idx: int):
	var typed_array: Array[Uniform]
	typed_array.assign(uniforms)
	add_uniform_set(UniformSet.new(seq, typed_array, set_idx, self ))


func add_uniform_set(uniform_set: UniformSet):
	uniform_sets.append(uniform_set)


func dispatch(compute_list_id: int = -1):
	var standalone := compute_list_id == -1
	if standalone: compute_list_id = seq.rd.compute_list_begin()

	seq.rd.compute_list_bind_compute_pipeline(compute_list_id, pipeline_rid)
	seq.push_constant.bind(compute_list_id)
	for set in uniform_sets:
		seq.rd.compute_list_bind_uniform_set(compute_list_id, set.active_rid, set.set_idx)

	seq.rd.compute_list_dispatch(compute_list_id, group_size.x, group_size.y, group_size.z)

	if standalone:
		seq.rd.compute_list_end()


func destroy():
	if rid.is_valid(): seq.rd.free_rid(rid)
