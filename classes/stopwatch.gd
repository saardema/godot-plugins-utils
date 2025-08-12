## Returns time elapsed between laps in milliseconds

var start_time_μs: int = _now_μs()
var _last_lap_time_μs: int = start_time_μs
var laps: Dictionary[String, float] = {}
var timestamps: Dictionary[String, float] = {}
var timestamps_pretty: String:
	get: return _prettify(timestamps)
var laps_pretty: String:
	get: return _prettify(laps)

func _prettify(dict: Dictionary[String, float]) -> String:
	if dict.size() > 10:
		return 'dictoobig'

	var pretty: String = ''
	for key in dict:
		pretty += '%s: %5.2f\n' % [key, dict[key]]
	return pretty


func _now_ms() -> float:
	return Time.get_ticks_usec() / 1000.0


func _now_μs() -> int:
	return Time.get_ticks_usec()


## Resets the clock and laps
func start():
	start_time_μs = _now_μs()
	_last_lap_time_μs = start_time_μs
	laps.clear()
	timestamps.clear()

## Returns the time elapsed since the last lap in milliseconds
## If name is provided, it will be stored in the laps dictionary
func lap(name: String = '') -> float:
	var now := _now_μs()
	var lap_ms := (now - _last_lap_time_μs) / 1000.0
	if name: laps[name] = lap_ms

	_last_lap_time_μs = now

	return lap_ms

## Store the time elapsed since start in the timestamps dictionary
func timestamp(name: String) -> void:
	timestamps[name] = (_now_μs() - start_time_μs) / 1000.0


## Returns the time elapsed since the stopwatch started in milliseconds
func get_elapsed() -> float:
	return (_now_μs() - start_time_μs) / 1000.0
