@tool

extends Control

const Stopwatch = preload('classes/stopwatch.gd')
static var Math = preload('classes/math.gd')

func _ready():
	RateLimiter._timers_node = $Timers
