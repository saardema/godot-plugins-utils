const PAT_LAYOUT := \
	"layout\\s*\\" + \
	"((?<layout>[\\w\\s=,]+)\\)" + \
	"(?<modifiers>[\\s\\w]+)" + \
	"(?:{\\s*(?<block>[\\w\\W]+?)\\s*})?"

const PAT_DECLARATION := \
	"(?:(?<type>\\w+)\\s)?" + \
	"(?<name>\\w+)" + \
	"(?:\\[(?<size>\\d+)\\])?" + \
	"(?:\\s*=\\s*(?<value>.+))?"


class Uniform:
	enum Type {
		Image,
		StorageBuffer,
		UniformBuffer
	}

	var binding: int
	var name: String
	var type: Type
	var format: String
	var set: int
	var read: bool = true
	var write: bool = true

class Declaration:
	var type: String
	var name: String
	var size: int = -1
	var value: int = -1

class PushConstant:
	var format: String
	var components: Array[Declaration]

class ParseResult:
	var local_size: Vector3i
	var push_constant: PushConstant
	var uniforms: Array[Uniform]
	var sets: Dictionary[int, Array]


static func parse(path: String) -> ParseResult:
	# path = 'res://addons/utils/classes/example.glsl'
	var result := ParseResult.new()
	var file = FileAccess.open(path, FileAccess.READ)

	if not file:
		printerr('Cannot parse shader. File not found.')
		return

	var layouts := _rsa(PAT_LAYOUT, file.get_as_text())

	for def in layouts:
		var layout := def.get_string("layout").split(',')
		var modifiers := def.get_string("modifiers").split(' ', false)
		var block := def.get_string("block").remove_chars(';').split('\n', false)

		if 'push_constant' in layout:
			_parse_push_constant(layout, modifiers, block)
			continue

		if 'local_size' in layout[0]:
			result.local_size = _parse_local_size(layout)
			continue

		var uniform := _parse_uniform(layout, modifiers, block)
		if uniform: result.uniforms.append(uniform)

		if not result.sets.has(uniform.set):
			result.sets[uniform.set] = []
		result.sets[uniform.set].append(uniform)

	return result


static func _parse_push_constant(
		layout: PackedStringArray,
		modifiers: PackedStringArray,
		block: PackedStringArray
	) -> PushConstant:
	var pc := PushConstant.new()

	return pc


static func _parse_local_size(layout: PackedStringArray) -> Vector3i:
	var components := _parse_declarations(layout)
	var local_size := -Vector3i.ONE

	if components.size() == 3:
		for comp in components.values():
			if !comp.name.length(): return -Vector3i.ONE
			var index := ['x', 'y', 'z'].find(comp.name.right(1))
			local_size[index] = comp.value if comp.value != -1 else 0

	return local_size


static func _parse_uniform(
		layout: PackedStringArray,
		modifiers: PackedStringArray,
		block: PackedStringArray
	) -> Uniform:
	var uniform := Uniform.new()
	var layout_decls := _parse_declarations(layout)

	uniform.name = modifiers[-1]
	uniform.format = 'None'

	if block:
		var block_decls := _parse_declaration(block[0])
		uniform.name = block_decls.name

	for decl: Declaration in layout_decls.values():
		if decl.name == 'set': uniform.set = decl.value
		elif decl.name == 'binding': uniform.binding = decl.value
		elif decl.value == -1:
			uniform.format = decl.name

	if modifiers.has('buffer'):
		if modifiers.has('uniform'):
			uniform.type = Uniform.Type.UniformBuffer
		else: uniform.type = Uniform.Type.StorageBuffer
	elif modifiers.has('image2D'):
		uniform.type = Uniform.Type.Image
	elif modifiers.has('readonly'):
		uniform.write = false
	elif modifiers.has('writeonly'):
		uniform.read = false

	return uniform


static func _parse_declaration(subject: String) -> Declaration:
	var dec := Declaration.new()
	var rmatch := _rs(PAT_DECLARATION, subject)
	for prop in rmatch.names:
		var value = rmatch.get_string(prop)
		if prop in ['size', 'value']: value = value.to_int()
		dec.set(prop, value)

	return dec


static func _parse_declarations(subjects: Array) -> Dictionary[String, Declaration]:
	var declarations: Dictionary[String, Declaration]
	for subject in subjects:
		var declaration := _parse_declaration(subject)
		if declaration.name and not declaration.name in declarations:
			declarations[declaration.name] = declaration
		else: push_warning('Could not output declaration "%s"' % subject)

	return declarations


static func _rsa(pattern: String, subject: String) -> Array[RegExMatch]:
	var regex := RegEx.new()
	regex.compile(pattern)
	return regex.search_all(subject)


static func _rs(pattern: String, subject: String) -> RegExMatch:
	var regex := RegEx.new()
	regex.compile(pattern)
	return regex.search(subject)


static func _rg(pattern: String, subject: String, group = 0) -> String:
	return _rs(pattern, subject).get_string(group)
