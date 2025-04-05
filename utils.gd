@tool

extends Node

const DataLogger = preload('./classes/data_logger.gd')
const Stopwatch = preload('./classes/stopwatch.gd')
const RateLimiter = preload('./classes/rate_limiter.gd')

func _ready():
	RateLimiter._timers_node = $Timers
