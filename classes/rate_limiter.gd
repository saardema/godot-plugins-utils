## Limit the execution interval of a callback
##
## Run [method exec] to execute [code]my_callable[/code]
## no more often than a predefined interval (100ms default):
## [codeblock]
## var limiter := RateLimiter.new(my_callable)
## limiter.exec()
## [/codeblock]
## [br][br]
## Set a rate in seconds:
## [codeblock]RateLimiter.new(my_callable, 0.5)[/codeblock]
## [br][br]
## To include arguments in the callback, use;
## [codeblock]RateLimiter.new(my_callable.bind('arg1', 'arg2'), 0.5)[/codeblock]
##
## Or change the bound args later:
## [codeblock]limiter.callback.bind('arg3', 'arg4')[/codeblock]
class_name RateLimiter

## Minimum time in seconds allowed between executions of [member callback]
var rate: float:
	set(v): rate = max(0, v)

## The callback to be executed when [method exec] is called
var callback: Callable

enum Mode {
	## Execute callback immediately initially and then rate limited while [method exec] is being called
	REGULAR,

	## Execute callback only after [method exec] has not been called for [member rate] seconds.
	## Useful for triggering expensive recalculations from property change events
	CONCLUDE,

	## Similar to CONCLUDE, but will also execute during calls to [method exec]
	SUB_CONCLUDE,
}

static var _timers_node: Node3D

var _timer: Timer
var _mode: Mode
var _scheduled_timestamp: float
var _last_trigger_timestamp: float
var _call_head: bool
var _call_body: bool
var _call_tail: bool

func _init(callback: Callable, rate: float = 0.1, mode: Mode = Mode.REGULAR):
	self.callback = callback
	self.rate = rate

	set_mode(mode)


## Change rate limiting behaviour. See [enum Mode]
func set_mode(mode: Mode):
	_mode = mode
	_call_head = _mode == Mode.REGULAR
	_call_body = _mode in [Mode.REGULAR, Mode.SUB_CONCLUDE]
	_call_tail = _mode in [Mode.CONCLUDE, Mode.SUB_CONCLUDE]

	if _call_tail and not _timer:
		_timer = Timer.new()
		RateLimiter._timers_node.add_child(_timer)
		_timer.one_shot = true
		_timer.timeout.connect(self._on_timer_timeout)


## Will execute callable if more than [member rate] seconds has passed,
## depending on the [enum Mode]. [br][br]
## Use [param force] to override the limiter and execute [member callback] immediately.
## Note that this will still reset the cooldown timer.
func exec(force: bool = false):
	var time: float = Time.get_ticks_msec() / 1000.0
	var should_exec := force

	if time >= _scheduled_timestamp:
		_scheduled_timestamp = time + rate

		if time - _last_trigger_timestamp > rate:
			should_exec = _mode == Mode.REGULAR

		elif _call_body:
			should_exec = true

	_last_trigger_timestamp = time

	if should_exec:
		callback.call()

	elif _call_tail:
		_timer.start(rate)


func _on_timer_timeout():
	exec(true)
