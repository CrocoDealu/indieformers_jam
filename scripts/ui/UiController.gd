extends Control

@onready var end_screen = $EndScreen
@onready var motive_label = $EndScreen/Control/VBoxContainer/Label
@onready var action_button = $EndScreen/Control/VBoxContainer/Button

var last_button_action

func _ready() -> void:
	SignalBus.game_ended.connect(_on_game_ended)
	SignalBus.level_restarted.connect(_on_game_restarted)
	SignalBus.next_level.connect(_on_next_level)

func _on_game_ended(motive, action, action_name):
	end_screen.visible = true
	motive_label.text = motive
	action_button.text = str(action_name)
	last_button_action = action
	action_button.pressed.connect(_on_action)

func _on_game_restarted():
	end_screen.visible = false

func _on_next_level():
	end_screen.visible = false

func _on_action():
	last_button_action.call()
