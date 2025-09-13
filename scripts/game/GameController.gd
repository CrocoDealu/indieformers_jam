extends Node

var iem
var player_controller
var click_sound

var current_player_health := 150
var max_player_health := 150

var bullet_number := 3
var max_bullet_number := 3
var bullet_recovery_time := 1.0
var _bullet_recovering := false

var can_use_special := true
var special_recovery_time = 10
var _special_recovering := false


func _ready() -> void:
	iem = get_node(^"/root/Node2D/InvertColorManager")
	player_controller = get_node(^"/root/Node2D/Game/Player")
	SignalBus.call_deferred("emit_signal", "bullet_number_changed", bullet_number, max_bullet_number)
	SignalBus.call_deferred("emit_signal", "special_state_changed", can_use_special)
	SignalBus.call_deferred("emit_signal", "health_changed", current_player_health, max_player_health)
	SignalBus.bullet_hit.connect(_on_bullet_hit)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_mirror"):
		iem.toggle()
		player_controller.toggle_inverse_locked_controls()
	

func _start_bullet_recovery_timer():
	if _bullet_recovering:
		return
	_bullet_recovering = true

	while bullet_number < max_bullet_number:
		await get_tree().create_timer(bullet_recovery_time).timeout
		if bullet_number < max_bullet_number:
			bullet_number += 1
			SignalBus.bullet_number_changed.emit(bullet_number, max_bullet_number)
	_bullet_recovering = false

func _start_special_recovery_timer():
	if _special_recovering or can_use_special:
		return
	_special_recovering = true
	await get_tree().create_timer(special_recovery_time).timeout
	can_use_special = true
	SignalBus.special_state_changed.emit(can_use_special)
	_special_recovering = false

func shoot_bullet():
	bullet_number -= 1
	SignalBus.bullet_number_changed.emit(bullet_number, max_bullet_number)
	_start_bullet_recovery_timer()

func use_special():
	can_use_special = false
	SignalBus.special_state_changed.emit(can_use_special)
	_start_special_recovery_timer()

func add_health(health):
	current_player_health = min(current_player_health + health, max_player_health)
	SignalBus.health_changed.emit(current_player_health, max_player_health)

func subtract_health(health):
	current_player_health = max(current_player_health - health, 0)
	SignalBus.health_changed.emit(current_player_health, max_player_health)

func _on_bullet_hit(target, shooter, bullet):
	if shooter.team == Enums.Team.PLAYER:
		return
	subtract_health(bullet.damage)
