extends CharacterBody2D

@onready var collision_shape_2d = $CollisionShape2D
@onready var sprite_2d = $Sprite2D

@export var speed: float = 280.0
@export var acceleration: float = 1200.0
@export var deceleration: float = 800.0  
@export var air_deceleration: float = 400.0 

# Gravity & fall limits
@export var gravity: float = 2000.0
@export var max_fall_speed: float = 2000.0

# Jump curve controls
@export var jump_action: String = "ui_accept"
@export var jump_power: float = 700.0        
@export var jump_duration: float = 0.5       
@export var jump_curve: Curve

# Sprite
@export var entity_texture: Texture

# Collision
@export var collision_shape: Shape2D

# Click-to-move settings
@export var enable_click_move: bool = true
@export var arrival_radius: float = 6.0
@export var click_cancel_on_keyboard: bool = true
@export var click_move_affects_y: bool = true     
@export var vertical_speed: float = 280.0         
@export var vertical_acceleration: float = 1200.0
@export var vertical_deceleration: float = 800.0

# Entity Variables
@export var team: Enums.Team
 
var _right_click_move_active: bool = false
var _right_click_target := Vector2.ZERO

var _is_jumping: bool = false
var _jump_time: float = 0.0
var _control_avalability = {
	Enums.event_type.LEFT: true,
	Enums.event_type.RIGHT: true
}

var bullet_error_offset : Vector2

var input_disabled: bool = false
var click_sound_player
var button_view = preload("res://scenes/bullet_scene.tscn")


func _ready() -> void:
	if not jump_curve:
		jump_curve = Curve.new()
		jump_curve.add_point(Vector2(0.0, 0.0))
		jump_curve.add_point(Vector2(0.25, 0.9))
		jump_curve.add_point(Vector2(0.5, 1.0))
		jump_curve.add_point(Vector2(0.8, 0.6))
		jump_curve.add_point(Vector2(1.0, 0.0))
		jump_curve.bake()
	sprite_2d.texture = entity_texture
	collision_shape_2d.shape = collision_shape
	if team == Enums.Team.PLAYER:
		SignalBus.control_glitched.connect(_on_control_glitched)
		SignalBus.control_back_to_normal.connect(_on_control_back_to_normal)
	click_sound_player = get_node(^"/root/Node2D/ClickSound")

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_left") and not _control_avalability[Enums.event_type.LEFT]:
		click_sound_player.play()
	
	if Input.is_action_just_pressed("ui_right") and not _control_avalability[Enums.event_type.RIGHT]:
		click_sound_player.play()
	
	process_movement(delta)


func process_movement(delta: float) -> void:
	var right_ok = _control_avalability.get(Enums.event_type.RIGHT, true)
	var left_ok  = _control_avalability.get(Enums.event_type.LEFT, true)
	
	var input_x := 0.0
	var keyboard_used := false
	
	if not input_disabled:
		var right_strength := Input.get_action_strength("ui_right") if right_ok else 0.0
		var left_strength  := Input.get_action_strength("ui_left") if left_ok else 0.0
		input_x = right_strength - left_strength
		keyboard_used = input_x != 0.0
		
		if keyboard_used and _right_click_move_active and click_cancel_on_keyboard:
			_right_click_move_active = false
	
	var desired_speed_x := 0.0
	var desired_vy_set := false 
	
	# -------------------------------------------------
	# HORIZONTAL CLICK MOVE (predictive)
	# -------------------------------------------------
	if enable_click_move and _right_click_move_active:
		var dx := _right_click_target.x - global_position.x
		var adx = abs(dx)
		if adx <= arrival_radius:
			desired_speed_x = 0.0
		else:
			var predictive_x := sqrt(2.0 * deceleration * adx)
			var allowed_x = min(speed, predictive_x)
			desired_speed_x = sign(dx) * allowed_x
	else:
		desired_speed_x = input_x * speed
	
	# -------------------------------------------------
	# APPLY HORIZONTAL ACCEL/DECEL
	# -------------------------------------------------
	if desired_speed_x != 0.0:
		var accel_rate := acceleration
		if abs(desired_speed_x) < abs(velocity.x):
			accel_rate = deceleration
		velocity.x = move_toward(velocity.x, desired_speed_x, accel_rate * delta)
	else:
		var decel_rate := deceleration if is_on_floor() else air_deceleration
		velocity.x = move_toward(velocity.x, 0.0, decel_rate * delta)
	
	# -------------------------------------------------
	# VERTICAL LOGIC
	# Two modes:
	#   - Platformer (jump + gravity)
	#   - Flight for click move if click_move_affects_y = true and _right_click_move_active
	# -------------------------------------------------
	if enable_click_move and click_move_affects_y and _right_click_move_active:
		_is_jumping = false
		
		var dy := _right_click_target.y - global_position.y
		var ady = abs(dy)
		
		if ady <= arrival_radius:
			var vdec = vertical_deceleration
			velocity.y = move_toward(velocity.y, 0.0, vdec * delta)
		else:
			var predictive_y = sqrt(2.0 * vertical_deceleration * ady)
			var allowed_y = min(vertical_speed, predictive_y)
			
			var desired_vy = sign(dy) * allowed_y
			
			var vy_accel := vertical_acceleration
			if abs(desired_vy) < abs(velocity.y):
				vy_accel = vertical_deceleration
			
			velocity.y = move_toward(velocity.y, desired_vy, vy_accel * delta)
		
		desired_vy_set = true
		
		if abs(_right_click_target.x - global_position.x) <= arrival_radius \
				and ady <= arrival_radius:
			_right_click_move_active = false
	else:
		# ------------------------------
		# Normal platformer jump physics
		# ------------------------------
		if not input_disabled:
			if Input.is_action_just_pressed(jump_action) \
					and is_on_floor() \
					and not _right_click_move_active:   
				_is_jumping = true
				_jump_time = 0.0
				velocity.y = 0.0
			
			if Input.is_action_just_released(jump_action) and _is_jumping:
				_is_jumping = false
		
		if _is_jumping:
			_jump_time += delta
			var t = clamp(_jump_time / jump_duration, 0.0, 1.0)
			var curve_val := jump_curve.sample_baked(t)
			velocity.y = -curve_val * jump_power
			if _jump_time >= jump_duration:
				_is_jumping = false
		else:
			velocity.y += gravity * delta
			velocity.y = min(velocity.y, max_fall_speed)
	
	move_and_slide()
	
	if not input_disabled and sprite_2d and abs(velocity.x) > 0.01:
		sprite_2d.flip_h = velocity.x < 0.0

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if GameController.bullet_number == 0:
				return
			var button_instance = button_view.instantiate()
			var mouse_pos = get_global_mouse_position()
			_shoot_bullet_towards_mouse()

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if GameController.can_use_special == false:
				return
			_start_click_move(get_global_mouse_position())

func _start_click_move(target: Vector2):
	_right_click_target = target
	_right_click_move_active = true
	GameController.use_special()

func _on_control_glitched(control):
	_control_avalability.set(control, false)
	
func _on_control_back_to_normal(control):
	_control_avalability[Enums.event_type.LEFT] = true
	_control_avalability[Enums.event_type.RIGHT] = true

func toggle_inverse_locked_controls():
	var temp = _control_avalability[Enums.event_type.LEFT]
	_control_avalability[Enums.event_type.LEFT] = _control_avalability[Enums.event_type.RIGHT]
	_control_avalability[Enums.event_type.RIGHT] = temp

func _shoot_bullet_towards_mouse():
	var bullet = button_view.instantiate()
	var mouse_pos = get_global_mouse_position()
	var direction = (mouse_pos - global_position).normalized()
	bullet.position = global_position + direction * 3
	bullet.set_direction(direction)
	bullet.shooter = self
	bullet.hit.connect(_on_bullet_hit)
	GameController.shoot_bullet()
	get_parent().add_child(bullet)

func _on_bullet_hit(target, shooter, bullet):
	if "team" in target and target.team == Enums.Team.ENEMY:
		target.subtract_health(bullet.damage)
		print_debug(target.enemy_health)
	print_debug("Bullet hit ", target, " ", shooter, " ", bullet)
	pass
