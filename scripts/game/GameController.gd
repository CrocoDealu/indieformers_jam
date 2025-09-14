extends Node

var iem
var player_controller
var click_sound

var current_player_health := 10
var max_player_health := 150

var bullet_number := 3
var max_bullet_number := 3
var bullet_recovery_time := 1.0
var _bullet_recovering := false

var can_use_special := true
var special_no_of_uses = 3
var special_recovery_time = 10
var _special_recovering := false
var starting_point
var tilemap
@onready var game_node: Node = $"/root/Node2D/Game"

func _ready() -> void:
	iem = get_node(^"/root/Node2D/InvertColorManager")
	player_controller = get_node(^"/root/Node2D/Game/Player")
	tilemap = get_node(^"/root/Node2D/Game/Level")
	starting_point = tilemap.initial_position
	_send_initial_signals()
	SignalBus.bullet_hit.connect(_on_bullet_hit)
	SignalBus.level_ready.connect(_on_level_ready)
	SignalBus.enemy_died.connect(_on_enemy_dead)
	#LimboConsole.register_command(subtract_health)
	LimboConsole.register_command(go_to_next_level)

func _send_initial_signals():
	SignalBus.call_deferred("emit_signal", "bullet_number_changed", bullet_number, max_bullet_number)
	SignalBus.call_deferred("emit_signal", "special_state_changed", can_use_special)
	SignalBus.call_deferred("emit_signal", "health_changed", current_player_health, max_player_health)

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
	if _special_recovering or can_use_special or special_no_of_uses > 0:
		return
	_special_recovering = true
	await get_tree().create_timer(special_recovery_time).timeout
	special_no_of_uses = 3
	can_use_special = true
	SignalBus.special_state_changed.emit(can_use_special)
	_special_recovering = false

func shoot_bullet():
	bullet_number -= 1
	SignalBus.bullet_number_changed.emit(bullet_number, max_bullet_number)
	_start_bullet_recovery_timer()

func use_special():
	if is_tutorial():
		tilemap.delete_blocks()
		tilemap.show_layer(2)
	special_no_of_uses -= 1
	can_use_special = not special_no_of_uses == 0
	SignalBus.special_state_changed.emit(can_use_special)
	if not can_use_special:
		_start_special_recovery_timer()

func add_health(health):
	current_player_health = min(current_player_health + health, max_player_health)
	SignalBus.health_changed.emit(current_player_health, max_player_health)

func subtract_health(health):
	if current_player_health - health <= 0:
		SignalBus.game_ended.emit("Game Over", restart_game, "Restart")
		player_controller.input_disabled = true
	current_player_health = max(current_player_health - health, 0)
	SignalBus.health_changed.emit(current_player_health, max_player_health)

func _on_bullet_hit(target, shooter, bullet):
	if shooter.team == Enums.Team.PLAYER:
		return
	if "team" not in target:
		return
	subtract_health(bullet.damage)

func _on_level_ready(initial_position: Vector2):
	if player_controller:
		player_controller.global_position = initial_position

func is_tutorial():
	return tilemap.is_tutorial

func restart_game():
	player_controller.global_position = starting_point
	player_controller.input_disabled = false
	SignalBus.level_restarted.emit()
	current_player_health = max_player_health
	bullet_number = max_bullet_number
	_send_initial_signals()

func _on_enemy_dead(enemy):
	if is_tutorial():
		SignalBus.game_ended.emit("Level Won", go_to_next_level, "Next Level")

func go_to_next_level():
	var level_2 = preload("res://scenes/level_1.tscn").instantiate()
	var level = game_node.get_node("Level")
	if game_node.has_node("Enemy"):
		var enemy = game_node.get_node("Enemy")
		game_node.remove_child(enemy)
		enemy.queue_free()
	level.queue_free()
	level_2.name = "Level"
	game_node.add_child(level_2)
	player_controller.global_position = level_2.initial_position
	game_node.move_child(level_2, 0)
	tilemap = level_2
	starting_point = tilemap.initial_position
	SignalBus.next_level.emit()
