@tool

extends Control

static var Stopwatch = preload('./classes/stopwatch.gd').Stopwatch

func _ready():
	RateLimiter._timers_node = $Timers
