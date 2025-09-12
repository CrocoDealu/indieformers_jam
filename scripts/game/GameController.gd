extends Node

var iem
var player_controller
var click_sound



func _ready() -> void:
	iem = get_node(^"/root/Node2D/InvertColorManager")
	player_controller = get_node(^"/root/Node2D/Game/Player")
	

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_mirror"):
		iem.toggle()
		player_controller.toggle_inverse_locked_controls()
	#if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		#var mouse_pos = get_viewport().get_mouse_position()
		#print("Mouse position (viewport): ", mouse_pos)
	#if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		#var mouse_pos = get_viewport().get_mouse_position()
		#
	
