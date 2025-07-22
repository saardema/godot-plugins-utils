@tool
class_name DataLogger
extends RefCounted

var values: PackedFloat32Array
var refresh_rate: int
var min: float:
	get: return values[_min_deque[0]]
var max: float:
	get: return values[_max_deque[0]]
var value_range: float:
	get: return max - min
var average: float:
	get: return _get_average()
var count_values: int:
	get: return _count_valid_values
var downsampling: int:
	set(value): downsampling = clamp(value, 1, max(1, _count))
var pointer: int
var _average_cache: float
var _accumulator: float
var _count: int
var _average_cache_invalid: bool
var _last_update: int
var _current_time: int
var _count_valid_values: int
var average_range: int = -1
var _count_limit: int = -1


#region MinMax deque
var _min_deque: Array[int] = [0]
var _max_deque: Array[int] = [0]
var _deque_window_size: int

func _add_to_min_deque(value: float):
	while _min_deque.size() > 0 and (pointer - _min_deque[0] + _count) % _count >= _deque_window_size:
		_min_deque.pop_front()

	while _min_deque.size() > 0 and values[_min_deque[-1]] >= value:
		_min_deque.pop_back()

	_min_deque.push_back(pointer)

func _add_to_max_deque(value: float):
	while _max_deque.size() > 0 and (pointer - _max_deque[0] + _count) % _count >= _deque_window_size:
		_max_deque.pop_front()

	while _max_deque.size() > 0 and values[_max_deque[-1]] <= value:
		_max_deque.pop_back()

	_max_deque.push_back(pointer)
#endregion MinMax deque


func _init(count: int, refresh_rate_ms: int = 0, downsampling_amount: int = 1):
	count = max(1, count)

	values.resize(count)
	downsampling = downsampling_amount
	_count = count
	_deque_window_size = _count - 10
	refresh_rate = refresh_rate_ms

func append(value: float):
	values[pointer] = value
	_add_to_min_deque(value)
	_add_to_max_deque(value)
	pointer = (pointer + 1) % _count

	if _count_valid_values < _count:
		_count_valid_values += 1

	_current_time = Time.get_ticks_msec()

	if _current_time > _last_update + refresh_rate:
		_last_update = _current_time
		_average_cache_invalid = true

func set_count_limit(limit: int):
	_count = min(values.size(), max(0, limit))
	if _count_valid_values > _count:
		_count_valid_values = _count

func reset():
	values.fill(0)
	_count_valid_values = 0
	_average_cache = 0
	pointer = 0

func append_array(array: PackedFloat32Array):
	for value in array:
		append(value)
	# values.append_array(array)
	# pointer = (pointer + array.size()) % _count
	# _count_valid_values = min(_count_valid_values + array.size(), _count)

func get_slice(size: int) -> PackedFloat32Array:
	if size < pointer:
		return values.slice(pointer - size, pointer)

	var values_slice := values.slice(_count - size + pointer, _count)
	values_slice.append_array(values.slice(0, pointer))

	return values_slice


func get_relative(index: int = 0) -> float:
	index = min(index, _count - 1)
	return values[(pointer - index - 1)]

func interpolate(index: float) -> float:
	var i: int = int(index) % _count
	var value_a := values[i]
	var value_b := values[i - 1]

	return lerpf(value_b, value_a, index - i)

func _get_average() -> float:
	if _average_cache_invalid:
		_average_cache_invalid = false
		_accumulator = 0

		var avg_range: int = _count_valid_values
		if average_range > -1 and average_range < _count_valid_values:
			avg_range = average_range

		if avg_range < 2: return values[pointer - 1]

		for i in range(0, avg_range, downsampling):
			_accumulator += values[(pointer - 1 - i) % _count_valid_values]
		_average_cache = _accumulator / avg_range * downsampling

	return _average_cache
