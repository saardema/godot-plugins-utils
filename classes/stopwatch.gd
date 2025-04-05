## Returns time elapsed in seconds
class_name Stopwatch

var start_time: int

func _init():
	start_time = Time.get_ticks_usec()

func stop() -> float:
	return (Time.get_ticks_usec() - start_time) * 0.000001
