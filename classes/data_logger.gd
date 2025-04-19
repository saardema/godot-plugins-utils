class DataLogger:

	var values: Array[float]
	var refresh_rate: int
	var average: float:
		get: return _get_average()
	var count_values: int:
		get: return _count_valid_values
	var _downsampling: int:
		set(value): _downsampling = clamp(value, 1, max(1, _count))
	var _pointer: int
	var _average_cache: float
	var _accumulator: float
	var _count: int
	var _average_cache_invalid: bool
	var _last_update: int
	var _current_time: int
	var _mode: int
	var _count_valid_values: int

	enum Mode {
		INTERPOLATE = 1
	}

	func _init(count: int, refresh_rate_ms: int = 0, downsampling: int = 1):
		values.resize(count)
		_downsampling = downsampling
		_count = count
		refresh_rate = refresh_rate_ms

	func append(value: float) -> DataLogger:
		values[_pointer] = value
		_pointer = (_pointer + 1) % _count

		if _count_valid_values < _count:
			_count_valid_values += 1

		_current_time = Time.get_ticks_msec()

		if _current_time > _last_update + refresh_rate:
			_last_update = _current_time
			_average_cache_invalid = true

		return self

	func _get_average() -> float:
		if _average_cache_invalid:
			_average_cache_invalid = false
			_accumulator = 0

			for i in range(0, _count_valid_values, _downsampling):
				_accumulator += values[(_pointer - 1 + i) % _count_valid_values]
			_average_cache = _accumulator / _count_valid_values * _downsampling

		return _average_cache
