class_name Player
extends CharacterBody3D

@export_group("Player Settings")
@export_range(0, 1.0) var mouse_sensitivty: float = 0.25
@export var rotation_speed: float = 12.0
@export_range(1, 20, 1) var zoom_sensitivity: float = .5
@export_range(.1, 10, .1) var zoom_step: float = 1
@export var zoom_min: float = -12
@export var zoom_max: float = -4
@export var right_click_to_rotate_camera: bool = false
@export_group("Movement")
@export var move_speed: float = 8.0
@export var move_speed_sprint: float = 10.0
var move_speed_base: float 
@export_range(20,100,1) var acceleration: float = 20.0
@export var jump_power: float = 11.75 # Give jump height of ~2 meters. Slighly higher
@export_range(0,1,.1) var jump_coyote_time: float = .25
var jump_max: int = 2
var jump_count: int = 0
@export var gravity: float = -30

@export var _camera: Camera3D
@export var _camera_pivot: Node3D

var _camera_input_direction: Vector2 = Vector2.ZERO
var _last_movement_direction: Vector3 = Vector3.BACK
var _rotate_camera: bool = false

var zoom_target: float = -8

const MOVE_DIRECTION_THRESHOLD: float = 0.2

@export var _skin: Node3D

var coyote_jump_available: bool = true
var coyote_jump_timer: Timer = Timer.new()
var prev_is_on_floor: bool = true

@export var after_image_parent: Node
var after_image_spawn_time_max: float = .07
var after_image_spawn_time_count: float 

func _ready():
	# zoom_target = _spring_arm.spring_length 
	move_speed_base = move_speed
	coyote_jump_timer.one_shot = true
	coyote_jump_timer.autostart = false
	add_child(coyote_jump_timer)
	coyote_jump_timer.timeout.connect(on_coyote_jump_timer_timeout)
	_rotate_camera = not right_click_to_rotate_camera

func _process(delta):
	if not is_equal_approx(_camera.position.x, zoom_target):
		zoom_target = clamp(zoom_target, zoom_min, -4)
		_camera.position.x = lerp(_camera.position.x, zoom_target, zoom_sensitivity * delta)

	after_image_spawn_time_count += delta
	if after_image_spawn_time_count >= after_image_spawn_time_max:
		create_after_image()
		after_image_spawn_time_count = 0

func _input(_event):
	if Input.is_action_just_pressed("left_click"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Input.is_action_just_pressed("escape"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Input.is_action_just_pressed("sprint"):
		move_speed = move_speed_sprint
		_skin.animation_tree.set("parameters/TimeScale/scale", 1.25)
	if Input.is_action_just_released("sprint"):
		move_speed = move_speed_base
		_skin.animation_tree.set("parameters/TimeScale/scale", 1.0)
	if Input.is_action_just_pressed("jump"):
		jump()
	if right_click_to_rotate_camera:
		if Input.is_action_just_pressed("right_click"):
			_rotate_camera = true
		if Input.is_action_just_released("right_click"):
			_rotate_camera = false
	if Input.is_action_just_pressed("scroll_up"):
		zoom_target += zoom_step
	if Input.is_action_just_pressed("scroll_down"):
		zoom_target -= zoom_step

func _physics_process(delta: float) -> void:
	# Reset _camera_input_direction for the next time _unhandled_input() is triggered
	# If this is not reset, the camera will keep rotating until new input comes in
	# _camera_input_direction = Vector2.ZERO

	# For a sidescroller we only need the right direction
	var raw_input: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var right_direction: Vector3 = _camera.global_basis.x

	var move_direction: Vector3 =(right_direction * raw_input.x)
	move_direction.y = 0.0 # Player will never give up-and-down move input. Jumping and falling with handle this
	move_direction = move_direction.normalized() # This is just intended to be a direction vector so it needs to be normalized

	# Acceleration can be added by using move_toward(). This will also prevent overshooting inheritly
	var y_velocity = velocity.y
	velocity.y = 0.0
	velocity = velocity.move_toward(move_direction * move_speed, acceleration * delta)
	velocity.y = (y_velocity + (gravity * delta))

	if prev_is_on_floor != is_on_floor() and not is_on_floor():
		coyote_jump_timer.start(jump_coyote_time)

	prev_is_on_floor = is_on_floor()

	move_and_slide()

	# Ensure that character look direction does not update when there is no input
	if move_direction.length() > MOVE_DIRECTION_THRESHOLD:
		_last_movement_direction = move_direction

	var target_angle: float = Vector3.BACK.signed_angle_to(_last_movement_direction, Vector3.UP)
	_skin.global_rotation.y = lerp_angle(_skin.global_rotation.y, target_angle, rotation_speed * delta)

	# Animate
	if not is_on_floor() and velocity.y <= 0:
		_skin.fall()
		
	elif is_on_floor():
		coyote_jump_available = true
		coyote_jump_timer.stop()
		var ground_speed: float = velocity.length()
		jump_count = 0
		if ground_speed > 1.0:
			_skin.move()
		else:
			_skin.idle()

func jump() -> void:
	if is_on_floor() or coyote_jump_available or (jump_count < jump_max):
		jump_count += 1
		coyote_jump_available = false
		velocity.y = jump_power
		_skin.jump()

func on_coyote_jump_timer_timeout() -> void:
	coyote_jump_available = false

func create_after_image() -> void:
	pass
	# var skin_clone: SophiaSkin = _skin.duplicate()
	# var after_image: AfterImage = skin_clone as AfterImage
	# print(after_image)


	# after_image_parent.add_child(skin_clone)
	# skin_clone.global_position = _skin.mesh.global_position
	# skin_clone.global_rotation = _skin.global_rotation
	# skin_clone.animation_tree.active = false

	# var after_image: AfterImage = _skin
	# after_image = _skin
	# after_image_parent.add_child(after_image)
	# after_image.global_position = _skin.mesh.global_position
	# after_image.global_rotation = _skin.global_rotation
