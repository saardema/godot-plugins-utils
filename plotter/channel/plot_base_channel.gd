var buffer: PackedFloat32Array
var channel_name: StringName
var color: Color
var max_size: int

func _init(name: StringName, max_buffer_size := 256):
	channel_name = name
	max_size = max_buffer_size


func flush():
	buffer.resize(0)


func read_single(_channel: int = 0) -> float:
	if buffer.size() == 0: return 0.0

	return buffer[-1]


func is_full() -> bool:
	return buffer.size() >= max_size

func write_single(value: float, _channel: int = 0):
	if buffer.size() >= max_size:
		buffer[-1] = value
		return

	buffer.append(value)


func set_buffer(new_buffer: PackedFloat32Array, _channel: int = 0):
	if new_buffer.size() > max_size:
		push_warning("New buffer size exceeds max_size. Resizing to match.")
		new_buffer.resize(max_size)

	buffer = new_buffer


func get_buffer(_channel: int = 0) -> PackedFloat32Array:
	flush.call_deferred()
	return buffer
