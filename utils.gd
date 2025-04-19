@tool

extends Node

const DataLogger = preload('./classes/data_logger.gd').DataLogger
const Stopwatch = preload('./classes/stopwatch.gd').Stopwatch
const RateLimiter = preload('./classes/rate_limiter.gd').RateLimiter

func _ready():
	RateLimiter._timers_node = $Timers
