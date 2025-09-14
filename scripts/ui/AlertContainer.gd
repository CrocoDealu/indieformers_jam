extends VBoxContainer

@onready var glitch_info = $GlitchInfo
@onready var time_remaining_label = $HBoxContainer/TimeRemainingLabel

var event_time_check_cooldown: int = 5
var rng : RandomNumberGenerator = RandomNumberGenerator.new()

var event_preannounce_time: float = 3.0
var tutorial_event_ongoing_time: float = 10000
var current_event_id: int = -1
var current_event_type: int = -1
var event_ongoing_time: float = 10.5
var event_ongoing: bool = false
@export var can_generate: bool = true

var reverse_event_type = {
	Enums.event_type.LEFT: "Left",
	Enums.event_type.RIGHT: "Right"
}

func _ready() -> void:
	TimeManagement.tick.connect(_on_tick)
	_start_random_event_checks()
	if GameController.is_tutorial():
		can_generate = false
	#LimboConsole.register_command(trigger_event_type)
	SignalBus.player_area_entered.connect(_on_player_area_entered)
	SignalBus.player_area_exited.connect(_on_player_area_exited)
	SignalBus.next_level.connect(_on_next_level)

func _start_random_event_checks():
	while true:
		await TimeManagement.wait_and_do(event_time_check_cooldown)
		var generate_event = rng.randi_range(0, 1)
		if generate_event and event_ongoing == false and can_generate:
			print_debug("Generating event")
			await _generate_event()
			print_debug("Ended event")

func _on_tick(remaining, id):
	if current_event_id != -1 and current_event_id == id:
		time_remaining_label.text = str(snapped(remaining, 0.1)) + "s"

func _generate_event():
	current_event_type = rng.randi_range(0, Enums.event_type.size() - 1)
	glitch_info.text = str(reverse_event_type.get(current_event_type)) + " will glitch"
	glitch_info.set("theme_override_colors/font_color",Color.WHITE)
	show_alert_panel()
	event_ongoing = true
	current_event_id = IdManager.get_id()
	await TimeManagement.wait_and_do_with_ticks(event_preannounce_time, current_event_id)
	await self._on_finish_event_announce(current_event_id)

func _on_finish_event_announce(id):
	if current_event_id != id:
		return
	glitch_info.set("theme_override_colors/font_color",Color.RED)
	glitch_info.text = str(reverse_event_type.get(current_event_type)) + " is glitching"
	current_event_id = IdManager.get_id()
	SignalBus.control_glitched.emit(current_event_type)
	await TimeManagement.wait_and_do_with_ticks(event_ongoing_time, current_event_id)
	SignalBus.control_back_to_normal.emit(current_event_type)
	hide_alert_panel()
	event_ongoing = false
	current_event_id = -1

func trigger_event_type(event_type: int) -> void:
	if event_ongoing:
		SignalBus.control_back_to_normal.emit(current_event_type)
		hide_alert_panel()
		current_event_id = -1

	event_ongoing = true
	current_event_type = event_type
	show_alert_panel()

	glitch_info.set("theme_override_colors/font_color", Color.RED)
	glitch_info.text = str(reverse_event_type.get(current_event_type, "Unknown")) + " is glitching"

	current_event_id = IdManager.get_id()
	SignalBus.control_glitched.emit(current_event_type)
	if GameController.is_tutorial():
		await TimeManagement.wait_and_do_with_ticks(tutorial_event_ongoing_time, current_event_id)
	else:
		await TimeManagement.wait_and_do_with_ticks(event_ongoing_time, current_event_id)

	if current_event_id == -1:
		return

	SignalBus.control_back_to_normal.emit(current_event_type)
	hide_alert_panel()
	event_ongoing = false
	current_event_id = -1

func show_alert_panel():
	self.visible = true

func hide_alert_panel():
	self.visible = false

func _on_player_area_entered(event_type):
	trigger_event_type(event_type)

func _on_player_area_exited(event_type):
	terminate_event()

func terminate_event():
	SignalBus.control_back_to_normal.emit(current_event_type)
	hide_alert_panel()
	current_event_id = -1

func _on_next_level():
	can_generate = true
