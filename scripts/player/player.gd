class_name Player
extends CharacterBody3D

@export_group("Player Settings")
@export_range(0, 1.0) var mouse_sensitivty: float = 0.25
@export var rotation_speed: float = 12.0
@export_range(1, 20, 1) var zoom_sensitivity: float = .5
@export_range(.1, 10, .1) var zoom_step: float = 1
@export var right_click_to_rotate_camera: bool = false
@export var after_image_active: bool = false
@export_group("Movement")
var can_move: bool = true # Used to enable/disable move and jump input
@export var move_speed_ground: float = 8.0
@export var move_speed_air: float = 12.0
@export var move_speed_sprint: float = 10.0
var move_speed: float 
var move_speed_base: float 
var is_moving_down: bool = false
@export var acceleration: float = 70
# @export var jump_power: float = 11.75 # Give jump height of ~2 meters. Slighly higher
@export var jump_power: float = 15.0
@export_range(0,1,.1) var jump_coyote_time: float = .25
var jump_max: int = 2
var jump_count: int = 0
@export_group("Gravity")
@export var gravity_default: float = -30
@export var gravity_wall_slide: float = -2
@export var gravity_wall_slide_increment: float = 0.09
@export var gravity_scale: float = 1.0
var gravity: float
@export var min_y_velocity: float = -30 # Fastest real-velocity character can fall
@export var max_y_velocity: float = 30 # Fastest real-velocity character can move up
@export_group("Camera")
@export var _camera: Camera3D
@export var _camera_pivot: Node3D
var camera_zoom_min: float = 2
var camera_zoom_max: float = 20
var camera_limit_left: float
var camera_limit_right: float 
var _camera_input_direction: Vector2 = Vector2.ZERO
var _last_movement_direction: Vector3 = Vector3.BACK
var _rotate_camera: bool = false
var camera_look_ahead_offset: Vector3

var zoom_target: float = 8

const MOVE_DIRECTION_THRESHOLD: float = 0.2
const CAMERA_FOLLOW_SPEED: float = 12

@export var _skin: Node3D

var coyote_jump_available: bool = true
var coyote_jump_timer: Timer = Timer.new()
var prev_is_on_floor: bool = true

@export var after_image_parent: Node
var after_image_spawn_time_max: float = .08
var after_image_spawn_time_count: float 

@export var wall_raycast: RayCast3D
@export var wall_raycast_distance_y: float = .35
@export var wall_push_power: float = 35
@export var wall_jump_power: float = 12.0
@export var wall_jump_move_disable_duration: float = .1
var is_wall_sliding: bool = false
var is_allowed_wall_slide: bool = true
var wall_jump_timer: Timer = Timer.new()
var prevent_wall_slide_timer: Timer = Timer.new() # Used to prevent wall sliding after move_down out of wallslide
var prevent_wall_slide_duration: float

@export_group("Particles")
@export var dust_particles: GPUParticles3D
@export var jump_dust_particles: GPUParticles3D

@export_group("Components")
@export var player_hurtbox: PlayerHurtbox

func _ready():
	# dust_particles.emitting = false
	gravity = gravity_default
	move_speed = move_speed_ground

	coyote_jump_timer.one_shot = true
	coyote_jump_timer.autostart = false
	add_child(coyote_jump_timer)
	coyote_jump_timer.timeout.connect(on_coyote_jump_timer_timeout)
	_rotate_camera = not right_click_to_rotate_camera

	wall_jump_timer.one_shot = true
	wall_jump_timer.autostart = false
	add_child(wall_jump_timer)
	wall_jump_timer.timeout.connect(on_wall_jump_timer_timeout)

	prevent_wall_slide_timer.one_shot = true
	prevent_wall_slide_timer.autostart = false
	add_child(prevent_wall_slide_timer)
	prevent_wall_slide_timer.timeout.connect(on_prevent_wall_slide_timer_timeout)

	initialize_camera()
	dust_particles.visible = true
	jump_dust_particles.visible = true

	player_hurtbox.hit.connect(on_player_hurtbox_hit)

func initialize_camera() -> void:
	_camera.global_transform.origin = _camera_pivot.global_transform.origin
	_camera.rotation_degrees.y = 90
	_camera.position.x = zoom_target

## Called by parent Level
func set_camera_limits(left_limit: Vector3, right_limit: Vector3) -> void:
	camera_limit_left = left_limit.z
	camera_limit_right = right_limit.z

func _input(_event):
	if Input.is_action_just_pressed("left_click"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Input.is_action_just_pressed("escape"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Input.is_action_just_pressed("scroll_up"):
		zoom_target -= zoom_step
	if Input.is_action_just_pressed("scroll_down"):
		zoom_target += zoom_step

	if can_move:
		if Input.is_action_just_pressed("sprint"):
			velocity.y = (jump_power * 1.5)
			jump_dust_particles.restart()
		if Input.is_action_just_released("sprint"):
			pass
		if Input.is_action_just_pressed("jump"):
			jump()
		if Input.is_action_just_pressed("move_down"):
			is_moving_down = true
			reset_from_wall_slide()
			is_allowed_wall_slide = false
			prevent_wall_slide_timer.start(prevent_wall_slide_duration)
		if Input.is_action_just_released("move_down"):
			is_moving_down = false
	
func _process(delta):
	process_camera_limits()
	process_camera_zoom(delta)
	process_after_image(delta)

func _physics_process(delta: float) -> void:
	# For a sidescroller we only need the right direction
	var raw_input: Vector2 = Vector2.ZERO
	var move_direction: Vector3 = Vector3.ZERO
	var right_direction: Vector3 = _camera.global_basis.x
	if can_move:
		raw_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		move_direction = (right_direction * raw_input.x)
		move_direction.y = 0.0 # Player will never give up-and-down move input. Jumping and falling with handle this
		move_direction = move_direction.normalized() # This is just intended to be a direction vector so it needs to be normalized

	move_speed = move_speed_ground if is_on_floor() else move_speed_air

	var y_velocity = velocity.y
	velocity.y = 0.0
	velocity = velocity.move_toward(move_direction * move_speed, acceleration * delta) # Apply horizontal movement
	velocity.y = clampf((y_velocity + (gravity * (gravity_scale * delta))), min_y_velocity, max_y_velocity) # Apply vertical movement

	if move_direction.z < 0:
		wall_raycast.target_position.y = wall_raycast_distance_y
	elif move_direction.z > 0:
		wall_raycast.target_position.y = -wall_raycast_distance_y

	if prev_is_on_floor != is_on_floor() and not is_on_floor():
		coyote_jump_timer.start(jump_coyote_time)
	prev_is_on_floor = is_on_floor()

	process_wall_slide(move_direction)
	process_camera_position(delta)
	process_dust_particles()
	move_and_slide()

	# Ensure that character look direction does not update when there is no input
	if move_direction.length() > MOVE_DIRECTION_THRESHOLD:
		_last_movement_direction = move_direction

	var target_angle: float = Vector3.BACK.signed_angle_to(_last_movement_direction, Vector3.UP)
	_skin.global_rotation.y = lerp_angle(_skin.global_rotation.y, target_angle, rotation_speed * delta)
	
	# Animate
	if is_wall_sliding:
		_skin.wall_slide()
	elif not is_on_floor() and velocity.y <= 0:
		_skin.fall()
	elif not is_on_floor() and velocity.y > 0:
		_skin.jump()
	elif is_on_floor():
		coyote_jump_available = true
		coyote_jump_timer.stop()
		var ground_speed: float = velocity.length()
		jump_count = 0
		if ground_speed > 1.0:
			_skin.move()
		else:
			_skin.idle()

func process_camera_zoom(delta: float) -> void:
	if not is_equal_approx(_camera.position.x, zoom_target):
		zoom_target = clamp(zoom_target, camera_zoom_min, camera_zoom_max)
		_camera.position.x = lerp(_camera.position.x, zoom_target, zoom_sensitivity * delta)

func process_camera_limits() -> void:
	_camera.global_position.z = clamp(_camera.global_position.z, camera_limit_right, camera_limit_left)

## MUST be called in `_physics_process` to avoid desyncing which causes jittering
func process_camera_position(delta: float) -> void:
	_camera.global_transform.origin.z = lerp(_camera.global_transform.origin.z, _camera_pivot.global_transform.origin.z, delta * CAMERA_FOLLOW_SPEED)
	_camera.global_transform.origin.y = lerp(_camera.global_transform.origin.y, _camera_pivot.global_transform.origin.y, delta * CAMERA_FOLLOW_SPEED)

func process_wall_slide(_move_direction: Vector3) -> void:
	if can_wall_slide() and not is_wall_sliding and _move_direction != Vector3.ZERO and is_allowed_wall_slide: # Start wall slide
		is_wall_sliding = true
		velocity = Vector3.ZERO
		gravity = gravity_wall_slide
		jump_count = 0
	elif not can_wall_slide() and is_wall_sliding: # JUST fell off wall
		reset_from_wall_slide()
	elif is_wall_sliding: # Is actively wall sliding
		gravity -= gravity_wall_slide_increment
func process_dust_particles() -> void:
	if not is_equal_approx(velocity.z, 0) and is_on_floor():
		dust_particles.emitting = true
	else:
		dust_particles.emitting = false

func process_after_image(delta) -> void:
	if after_image_active:
		after_image_spawn_time_count += delta
		if after_image_spawn_time_count >= after_image_spawn_time_max:
			create_after_image()
			after_image_spawn_time_count = 0

func jump() -> void:
	if is_on_floor() or coyote_jump_available or (jump_count < jump_max):
		if jump_count != 0: # air jumping
			jump_dust_particles.restart()
		jump_count += 1
		coyote_jump_available = false
		_skin.jump()
		var _jump_power: float = jump_power
		if is_wall_sliding:
			_jump_power = wall_jump_power 
			velocity.z += (get_wall_normal().z * wall_push_power) # Push off away from wall if sliding
			_last_movement_direction = -_last_movement_direction # Flip direction character is facing

			can_move = false
			wall_jump_timer.start(wall_jump_move_disable_duration)

		velocity.y = _jump_power

func on_coyote_jump_timer_timeout() -> void:
	coyote_jump_available = false

## Returns true if wall_raycast is colliding, and character is not on floor
func can_wall_slide() -> bool:
	return wall_raycast.is_colliding() and not is_on_floor()

func sprint() -> void:
	move_speed = move_speed_sprint
	_skin.animation_tree.set("parameters/TimeScale/scale", 1.25)

func reset_sprint() -> void:
	move_speed = move_speed_base
	_skin.animation_tree.set("parameters/TimeScale/scale", 1.0)

func dash() -> void:
	after_image_active = true
	var raw_input: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var right_direction: Vector3 = _camera.global_basis.x
	var move_direction: Vector3 = (right_direction * raw_input.x).normalized()
	velocity += (move_direction * 25)
	velocity.y += 10
	await get_tree().create_timer(.6).timeout
	after_image_active = false

func on_wall_jump_timer_timeout() -> void:
	can_move = true

func on_prevent_wall_slide_timer_timeout() -> void:
	is_allowed_wall_slide = true

func on_player_hurtbox_hit(_hit_impulse: Vector3) -> void:
	velocity = _hit_impulse

func create_after_image() -> void:
	var material_after_image: StandardMaterial3D = load("res://materials/material_afterimage.tres")
	var skin_clone: SophiaSkin = _skin.duplicate()
	after_image_parent.add_child(skin_clone)
	skin_clone.animation_tree.active = false

	skin_clone.mesh.set_surface_override_material(0,material_after_image)
	skin_clone.mesh.set_surface_override_material(1,material_after_image)
	skin_clone.mesh.set_surface_override_material(2,material_after_image)
	skin_clone.mesh.set_surface_override_material(3,material_after_image)

	skin_clone.global_position = _skin.mesh.global_position
	skin_clone.global_rotation = _skin.global_rotation

	var lifetime: float = .3
	await get_tree().create_timer(lifetime).timeout
	skin_clone.queue_free()

## Reset to normal after wall slide completes
func reset_from_wall_slide() -> void:
	is_wall_sliding = false
	gravity = gravity_default