extends Node

signal stopped
signal started
signal resumed
signal paused
signal finished(id)
signal tick(remaining: float)

var is_paused: bool = false

func wait_and_do_with_ticks(seconds: float, id=null):
	var remaining = max(0.0, seconds)
	while remaining > 0:
		if is_paused:
			await resumed
		await get_tree().process_frame
		remaining -= get_process_delta_time()
		tick.emit(max(0.0, remaining), id)
	finished.emit(id)

func wait_and_do(seconds: float):
	var remaining = max(0.0, seconds)
	while remaining > 0:
		if is_paused:
			await resumed
		await get_tree().process_frame
		remaining -= get_process_delta_time()
