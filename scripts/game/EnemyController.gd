extends CharacterBody2D

@export var move_speed: float = 220.0
@export var acceleration: float = 1400.0
@export var deceleration: float = 1600.0
@export var gravity: float = 1400.0
@export var max_fall_speed: float = 900.0

@export var jump_power: float = 420.0
@export var can_jump: bool = true
@export var jump_cooldown: float = 0.6
@export var attack_range: float = 420.0
@export var vision_range: float = 640.0
@export var attack_cooldown_time: float = 0.8
@export var patrol_speed_scale: float = 0.45
@export var patrol_distance: float = 180.0
@export var line_of_sight_required: bool = true

@export var bullet_scene: PackedScene
@export var team: int = Enums.Team.ENEMY

# New patrol robustness options
@export var flip_on_wall: bool = true            # Flip if we hit a wall
@export var flip_when_blocked_frames: int = 8    # If stuck this many frames, flip
@export var reset_patrol_origin_on_wall: bool = false  # If true, center shifts when blocked


@export var enemy_health: int
# References
@export var player_path: NodePath
@onready var player: Node = get_node_or_null(player_path)
@onready var los_raycast: RayCast2D = $RayCast2D
@onready var attack_timer: Timer = $AttackCooldown
@onready var jump_timer: Timer = $JumpCooldown
@onready var health_bar: ProgressBar = $Node2D/ProgressBar

var States = Enums.State
var state: int = States.IDLE
var state_time: float = 0.0
var patrol_origin: Vector2
var patrol_dir: int = 1

var ai_input := {
	"move_x": 0.0,
	"jump_pressed": false,
	"shoot_pressed": false
}

# Internal helpers for stuck detection
var _blocked_frames: int = 0
var _last_desired_speed_x: float = 0.0

func _ready():
	patrol_origin = global_position
	attack_timer.wait_time = attack_cooldown_time
	jump_timer.wait_time = jump_cooldown
	attack_timer.one_shot = true
	jump_timer.one_shot = true
	health_bar.max_value = enemy_health

func _physics_process(delta: float):
	state_time += delta
	
	_update_state_logic(delta)
	var desired_speed_x = _apply_ai_input(delta)
	move_and_slide()
	
	_post_move_patrol_checks(desired_speed_x, delta)

func _update_state_logic(delta: float) -> void:
	ai_input.move_x = 0.0
	ai_input.jump_pressed = false
	ai_input.shoot_pressed = false
	
	if not is_instance_valid(player):
		state = States.IDLE
		return
	
	var to_player = player.global_position - global_position
	var dist = to_player.length()
	var has_los = _has_line_of_sight(player.global_position)
	
	match state:
		States.IDLE:
			if dist < vision_range and (has_los or not line_of_sight_required):
				_enter_state(States.CHASE)
			elif state_time > 1.0:
				_enter_state(States.PATROL)
		
		States.PATROL:
			ai_input.move_x = patrol_dir * patrol_speed_scale
			
			if abs(global_position.x - patrol_origin.x) > patrol_distance:
				patrol_dir *= -1
				if reset_patrol_origin_on_wall:
					patrol_origin = global_position
			
			if dist < vision_range and (has_los or not line_of_sight_required):
				_enter_state(States.CHASE)
		
		States.CHASE:
			ai_input.move_x = sign(to_player.x)
			
			if can_jump and to_player.y < -40 and is_on_floor() and jump_timer.is_stopped():
				ai_input.jump_pressed = true
			
			if dist <= attack_range and (has_los or not line_of_sight_required):
				_enter_state(States.ATTACK)
		
		States.ATTACK:
			ai_input.move_x = sign(to_player.x) * 0.2
			
			if attack_timer.is_stopped():
				ai_input.shoot_pressed = true
				_perform_attack(player.global_position)
				attack_timer.start()
			
			if dist > attack_range * 1.2 or (line_of_sight_required and not has_los):
				_enter_state(States.CHASE)
			elif state_time > 0.25:
				_enter_state(States.COOLDOWN)
		
		States.COOLDOWN:
			if dist > attack_range * 1.25:
				_enter_state(States.CHASE)
			elif dist <= attack_range and (has_los or not line_of_sight_required):
				if attack_timer.is_stopped():
					_enter_state(States.ATTACK)
	
	if ai_input.jump_pressed and jump_timer.is_stopped():
		jump_timer.start()

func _apply_ai_input(delta: float) -> float:
	var desired_speed_x = ai_input.move_x * move_speed
	
	if desired_speed_x != 0.0:
		var accel = acceleration
		if abs(desired_speed_x) < abs(velocity.x):
			accel = deceleration
		velocity.x = move_toward(velocity.x, desired_speed_x, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
	
	if ai_input.jump_pressed and is_on_floor():
		velocity.y = -jump_power
	else:
		velocity.y += gravity * delta
	velocity.y = min(velocity.y, max_fall_speed)
	
	return desired_speed_x

func _post_move_patrol_checks(desired_speed_x: float, delta: float) -> void:
	if state == States.PATROL and flip_on_wall:
		_maybe_flip_patrol_on_block(desired_speed_x)
	_last_desired_speed_x = desired_speed_x

func _maybe_flip_patrol_on_block(desired_speed_x: float):
	if is_on_wall() and desired_speed_x != 0.0:
		_flip_patrol_dir("wall")
		return
	
	var pushing = abs(desired_speed_x) > 1.0
	var hardly_moving = abs(velocity.x) < 5.0
	
	if pushing and hardly_moving:
		_blocked_frames += 1
	else:
		_blocked_frames = 0
	
	if _blocked_frames >= flip_when_blocked_frames:
		_flip_patrol_dir("stuck")
		_blocked_frames = 0

func _flip_patrol_dir(reason: String):
	patrol_dir *= -1
	if reset_patrol_origin_on_wall:
		patrol_origin = global_position
	global_position.x += patrol_dir * 2.0

func _perform_attack(target_pos: Vector2) -> void:
	if bullet_scene == null:
		return
	var bullet = bullet_scene.instantiate()
	var direction = (target_pos - global_position).normalized()
	bullet.global_position = global_position + direction * 10.0
	if bullet.has_method("set_direction"):
		bullet.set_direction(direction)
	if "shooter" in bullet:
		bullet.shooter = self
	if "team" in bullet:
		bullet.team = team
	bullet.hit.connect(_on_bullet_hit)
	get_tree().current_scene.add_child(bullet)

func _has_line_of_sight(target_pos: Vector2) -> bool:
	if los_raycast == null:
		return true
	los_raycast.target_position = to_local(target_pos)
	los_raycast.force_raycast_update()
	return not los_raycast.is_colliding()

func _enter_state(new_state: int):
	state = new_state
	state_time = 0.0

func _on_bullet_hit(target, shooter, bullet):
	print_debug("Bullet hit someone ", target, " ", shooter, " ", bullet)
	SignalBus.bullet_hit.emit(target, shooter, bullet)

func subtract_health(health):
	if enemy_health - health <= 0:
		self.queue_free()
		return
	enemy_health -= health
	health_bar.value = enemy_health
