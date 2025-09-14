extends CharacterBody2D

@onready var collision_shape_2d = $CollisionShape2D
@onready var animated_sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var visual: Node2D = $Visual

@export var speed: float = 280.0
@export var acceleration: float = 1200.0
@export var deceleration: float = 800.0  
@export var air_deceleration: float = 400.0 

@export var gravity: float = 2000.0
@export var max_fall_speed: float = 2000.0

@export var jump_action: String = "ui_accept"
@export var jump_power: float = 700.0        
@export var jump_duration: float = 0.5       
@export var jump_curve: Curve

@export var entity_texture: Texture
@export var collision_shape: Shape2D

@export var enable_click_move: bool = true
@export var arrival_radius: float = 6.0
@export var click_cancel_on_keyboard: bool = true
@export var click_move_affects_y: bool = true     
@export var vertical_speed: float = 280.0         
@export var vertical_acceleration: float = 1200.0
@export var vertical_deceleration: float = 800.0

@export var team: Enums.Team
 
@export var air_hold_time: float = 1.0
var _air_hold_active: bool = false
var _air_hold_timer: float = 0.0

@export var spin_speed_deg: float = 360.0   
var _right_click_spin_active: bool = false
var _right_click_move_active: bool = false
var _right_click_target := Vector2.ZERO

var _is_jumping: bool = false
var _jump_time: float = 0.0
var _control_avalability = {
	Enums.event_type.LEFT: true,
	Enums.event_type.RIGHT: true
}
var is_mirrored: bool = false
var bullet_error_offset : Vector2
var input_disabled: bool = false
var click_sound_player
var button_view = preload("res://scenes/bullet_scene.tscn")
var is_attacking: bool = false
var pending_shot: bool = false
var pending_shot_target: Vector2
# ========================
# Animation state helpers
# ========================
const WALK_THRESHOLD := 5.0  

var invert_mat: ShaderMaterial           
var mirror_visual_active: bool = false
var force_mirror_flip: bool = false   
var glitch_visual_active: bool = false 

func _ready() -> void:
	if not jump_curve:
		jump_curve = Curve.new()
		jump_curve.add_point(Vector2(0.0, 0.0))
		jump_curve.add_point(Vector2(0.25, 0.9))
		jump_curve.add_point(Vector2(0.5, 1.0))
		jump_curve.add_point(Vector2(0.8, 0.6))
		jump_curve.add_point(Vector2(1.0, 0.0))
		jump_curve.bake()
	collision_shape_2d.shape = collision_shape
	_ensure_invert_material()
	
	if team == Enums.Team.PLAYER:
		SignalBus.control_glitched.connect(_on_control_glitched)
		SignalBus.control_back_to_normal.connect(_on_control_back_to_normal)
	
	click_sound_player = get_node(^"/root/Node2D/ClickSound")
	
	# Connect animation finished (if not connected via editor)
	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)
	
	animated_sprite.play("idle")

func _process(delta: float) -> void:
	if _right_click_spin_active:
		visual.rotation += deg_to_rad(spin_speed_deg) * delta
	else:
		visual.rotation = 0.0

func _rotate_visual_towards_mouse():
	var to_mouse = get_global_mouse_position() - global_position
	if to_mouse.length() > 0.001:
		visual.rotation = to_mouse.angle()

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_left") and not _control_avalability[Enums.event_type.LEFT]:
		click_sound_player.play()
	
	if Input.is_action_just_pressed("ui_right") and not _control_avalability[Enums.event_type.RIGHT]:
		click_sound_player.play()
	
	process_movement(delta)
	_update_animation() 
	
	if _air_hold_active:
		_air_hold_timer -= delta
		if _air_hold_timer <= 0.0:
			_air_hold_active = false


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
	
	# CLICK MOVE X
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
	
	# APPLY H ACCEL/DECEL
	if desired_speed_x != 0.0:
		var accel_rate := acceleration
		if abs(desired_speed_x) < abs(velocity.x):
			accel_rate = deceleration
		velocity.x = move_toward(velocity.x, desired_speed_x, accel_rate * delta)
	else:
		var decel_rate := deceleration if is_on_floor() else air_deceleration
		velocity.x = move_toward(velocity.x, 0.0, decel_rate * delta)
	
	if _air_hold_active:
		# Hover: freeze vertical velocity
		velocity.y = 0.0
	else:
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
			if abs(_right_click_target.x - global_position.x) <= arrival_radius and ady <= arrival_radius:
				_right_click_move_active = false
		else:
			# NORMAL JUMP / GRAVITY
			if not input_disabled:
				if Input.is_action_just_pressed(jump_action) and is_on_floor() and not _right_click_move_active:
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
	
	if not input_disabled and not is_attacking and not _right_click_spin_active:
		if abs(velocity.x) > 0.01:
			animated_sprite.flip_h = velocity.x < 0.0

func _stop_spin_and_reset():
	_right_click_spin_active = false
	var tween = create_tween()
	tween.tween_property(visual, "rotation", 0.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _update_animation():
	if is_attacking:
		return
	
	var walking = abs(velocity.x) > WALK_THRESHOLD and is_on_floor()
	
	if walking:
		_play_anim_if_needed("walking")
	else:
		_play_anim_if_needed("idle")

func _play_anim_if_needed(name: String):
	if animated_sprite.animation != name:
		animated_sprite.play(name)

func _input(event):
	if input_disabled:
		return
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					if GameController.bullet_number == 0:
						return
					_queue_shot(get_global_mouse_position())
			MOUSE_BUTTON_RIGHT:
				if event.pressed:
					if GameController.can_use_special == false:
						return
					_right_click_spin_active = true
					_start_click_move(get_global_mouse_position())
				else:
					_right_click_spin_active = false
					_start_air_hold()
	elif event.is_action_pressed("toggle_mirror"):
		toggle_inverse_locked_controls()
		toggle_mirror_visual()

func _face_point(target: Vector2) -> void:
	if is_attacking:
		return
	var dx = target.x - global_position.x
	if abs(dx) > 0.01:
		animated_sprite.flip_h = dx < 0.0

func _queue_shot(target: Vector2):
	pending_shot_target = target
	pending_shot = true
	_face_point(target)
	if !is_attacking:
		_start_attack_animation()


func _start_attack_animation():
	if is_attacking:
		return 
	is_attacking = true
	animated_sprite.play("attack")

func _on_animation_finished():
	if animated_sprite.animation == "attack":
		_perform_pending_shot()
		is_attacking = false

func _start_click_move(target: Vector2):
	_right_click_target = target
	_right_click_move_active = true
	GameController.use_special()

func _on_control_glitched(control):
	if is_mirrored:
		_control_avalability.set((control + 1) % 2 , false)
	else:
		_control_avalability.set(control, false)
	
func _on_control_back_to_normal(control):
	_control_avalability[Enums.event_type.LEFT] = true
	_control_avalability[Enums.event_type.RIGHT] = true

func toggle_inverse_locked_controls():
	is_mirrored = not is_mirrored
	var temp = _control_avalability[Enums.event_type.LEFT]
	_control_avalability[Enums.event_type.LEFT] = _control_avalability[Enums.event_type.RIGHT]
	_control_avalability[Enums.event_type.RIGHT] = temp

func _perform_pending_shot():
	if !pending_shot:
		return
	pending_shot = false
	var direction = (pending_shot_target - global_position).normalized()
	var bullet = button_view.instantiate()
	bullet.position = global_position + direction * 3
	bullet.set_direction(direction)
	bullet.shooter = self
	bullet.hit.connect(_on_bullet_hit)
	GameController.shoot_bullet()
	get_parent().add_child(bullet)

func _on_bullet_hit(target, shooter, bullet):
	if "team" in target and target.team == Enums.Team.ENEMY:
		target.subtract_health(bullet.damage)

func _start_air_hold():
	if _air_hold_active:
		return
	if is_on_floor():
		return
	_air_hold_active = true
	_air_hold_timer = air_hold_time
	_right_click_move_active = false
	_is_jumping = false

func toggle_mirror_visual():
	mirror_visual_active = !mirror_visual_active
	_update_invert_shader()

func _update_invert_shader():
	if invert_mat == null:
		return
	var should_be_active = mirror_visual_active or glitch_visual_active
	invert_mat.set("shader_parameter/active", 1.0 if should_be_active else 0.0)

func toggle_force_flip():
	force_mirror_flip = !force_mirror_flip
	if force_mirror_flip:
		animated_sprite.flip_h = true 
func _ensure_invert_material():
	if animated_sprite.material and animated_sprite.material is ShaderMaterial:
		invert_mat = animated_sprite.material.duplicate() as ShaderMaterial
		animated_sprite.material = invert_mat
	else:
		var shader = load("res://assets/shaders/player_invert.shader")
		invert_mat = ShaderMaterial.new()
		invert_mat.shader = shader
		animated_sprite.material = invert_mat
	invert_mat.set("shader_parameter/active", 0.0)
