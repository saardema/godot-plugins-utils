var buffer: PackedFloat32Array
var name: StringName
var color: Color
var max_size: int
var pointer: int = 0
var ring_buffer: bool = true

func _init(channel_name: StringName, max_buffer_size := 256, as_ring_buffer := true):
	name = channel_name
	max_size = max_buffer_size
	ring_buffer = as_ring_buffer

	if ring_buffer: buffer.resize(max_size)


func flush():
	buffer.resize(0)


func is_full() -> bool:
	return buffer.size() >= max_size


func read_single(_channel: int = 0) -> float:
	if buffer.size() == 0: return 0.0

	return buffer[-1]


func write_single(value: float):
	var size := buffer.size()

	if size >= max_size:
		if ring_buffer:
			if pointer >= max_size:
				pointer = 0
			buffer[pointer] = value
			pointer += 1
		else:
			buffer[-1] = value
	else:
		buffer.append(value)


func set_buffer(new_buffer: PackedFloat32Array):
	if new_buffer.size() > max_size:
		push_warning("New buffer size exceeds max_size. Resizing to match.")
		new_buffer.resize(max_size)

	buffer = new_buffer


func get_buffer(_channel: int = 0, flush_after := true) -> PackedFloat32Array:
	if flush_after:
		flush.call_deferred()
	return buffer
