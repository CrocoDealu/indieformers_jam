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

var _is_jumping: bool = false
var _jump_time: float = 0.0
var _control_avalability = {
	Enums.event_type.LEFT: true,
	Enums.event_type.RIGHT: true
}

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
	var input_right = 0.0
	var input_left = 0.0
	var input_x = 0.0
	var walking = false
	var target_x = 0.0

	if not input_disabled:
		input_right = Input.get_action_strength("ui_right") if _control_avalability[Enums.event_type.RIGHT] else 0.0
		input_left = Input.get_action_strength("ui_left") if _control_avalability[Enums.event_type.LEFT] else 0.0
		input_x = input_right - input_left
		walking = input_x != 0.0
		target_x = input_x * speed

		if walking:
			velocity = velocity.move_toward(Vector2(target_x, 0), acceleration * delta)
		else:
			var decel = deceleration if is_on_floor() else air_deceleration
			velocity = velocity.move_toward(Vector2(0.0, 0.0), decel * delta)

		if Input.is_action_just_pressed(jump_action) and is_on_floor():
			_is_jumping = true
			_jump_time = 0.0
			velocity.y = 0.0

		if Input.is_action_just_released(jump_action) and _is_jumping:
			_is_jumping = false
	else:
		velocity.x = 0.0

	if _is_jumping:
		_jump_time += delta
		var t = clamp(_jump_time / jump_duration, 0.0, 1.0)
		var curve_val = jump_curve.sample_baked(t)
		velocity.y = -curve_val * jump_power
		if _jump_time >= jump_duration:
			_is_jumping = false
	else:
		velocity.y += gravity * delta
		velocity.y = min(velocity.y, max_fall_speed)

	move_and_slide()

	if not input_disabled and sprite_2d and input_x != 0:
		sprite_2d.flip_h = input_x < 0


func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			print("Left mouse clicked at:", get_global_mouse_position())
			var button_instance = button_view.instantiate()
			var mouse_pos = get_global_mouse_position()
			_shoot_bullet_towards_mouse()

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			print("Right mouse clicked at:", get_global_mouse_position())

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
	bullet.position = global_position  
	var mouse_pos = get_global_mouse_position()
	var direction = (mouse_pos - global_position).normalized()
	bullet.set_direction(direction)
	bullet.shooter = self
	get_parent().add_child(bullet)
