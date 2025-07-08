## Returns time elapsed between laps in milliseconds
class Stopwatch:
	var start_time: int = Time.get_ticks_usec()

	func lap() -> float:
		var now := Time.get_ticks_usec()
		var timing := (now - start_time) * 0.001
		start_time = now
		return timing
