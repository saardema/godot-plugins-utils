@tool

extends Node

#static var DataLogger = preload('./classes/data_logger.gd')
static var Stopwatch = preload('./classes/stopwatch.gd').Stopwatch
#static var RateLimiter = preload('./classes/rate_limiter.gd')

func _ready():
	RateLimiter._timers_node = $Timers
