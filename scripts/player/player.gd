class_name Player
extends CharacterBody3D

"""
Variables that start with _ (such as _move_speed) are internal variables that keep track of something at runtime and aren't intended to be edited.
Anything that starts with @export can be modified to change player stats.

Some internal variables have a corresponding @export var which control their initial value (example: _gravity and gravity_default)
"""

@export_category("Player Settings")
@export_group("Movement")
@export var move_speed_ground: float = 8.0
@export var move_speed_air: float = 8.0
@export var move_speed_sprint: float = 16.0
## Multiplier controlling how quickly the player reaches their intended velocity. Lowering this value will make the character appear more slippery.
@export var acceleration: float = 70
## Multipler controlling how quickly the player mesh rotates to face the forward direction. In a sidescroller, only affects speed the player changes from left to right.
@export var rotation_speed: float = 12.0
var _move_speed: float

@export_group("Jump")
@export var jump_power: float = 15
@export var jump_max: int = 2
@export_range(0,1,.1) var jump_coyote_time: float = .25
var _can_move: bool = true
var _is_moving_down: bool = false
var _prev_is_on_floor: bool = true
var _jump_count: int = 0
var _coyote_jump_available: bool = true
var coyote_jump_timer: Timer = Timer.new()

@export_group("Gravity & Falling")
## Gravity applied to the player in most cases.
@export var gravity_default: float = -30
## Gravity applied to the player when wall sliding
@export var gravity_wall_slide: float = -2
## How much [code]gravity_wall_slide[/code] increases per frame while wall sliding.
@export var gravity_wall_slide_increment: float = 0.09
## Multiplier controlling how fast gravity is applied. Lower [code]gravity_scale[/code] will accelerate the player to terminal velocity slower. Does not control the max amount of gravity applied.
@export var gravity_scale: float = 1.0
## Fastest real-velocity character can fall. This will continuously limit the max player fall speed.
@export var min_y_velocity: float = -15
## Fastest real-velocity character can rise. If a 1 time impulse (such as jump_power) is applied, this will cap it and the extra power will be discarded.
@export var max_y_velocity: float = INF
var _gravity: float

@export_group("Camera & Mouse")
@export_range(0, 1.0) var mouse_sensitivty: float = 0.25
@export var camera: Camera3D
@export var camera_pivot: Node3D
@export var camera_zoom_min: float = 2
@export var camera_zoom_max: float = 20
@export_range(1, 20, 1) var zoom_sensitivity: float = .5
@export_range(.1, 10, .1) var zoom_step: float = 1
## Multiplier controlling the strength of the camera's lerp to player's position. Lower values will cause the camera to trail behind the player's current position more.
@export var camera_follow_speed: float = 15
var _camera_limit_left: float
var _camera_limit_right: float 
var _last_movement_direction: Vector3 = Vector3.BACK
var _zoom_target: float = 8
const MOVE_DIRECTION_THRESHOLD: float = 0.2
# var camera_look_ahead_offset: Vector3 = Vector3.ZERO

@export_group("After Image")
@export var after_image_parent: Node
@export var after_image_spawn_time_max: float = .08
@export var after_image_active: bool = false
var _after_image_spawn_time_count: float 

@export_group("Wall Slide")
@export var wall_raycast: RayCast3D
@export var wall_raycast_distance_y: float = .35
@export var wall_push_power: float = 35
@export var wall_jump_power: float = 12.0
@export var wall_jump_move_disable_duration: float = .1
var _is_wall_sliding: bool = false
var _wall_slide_allowed: bool = true
var wall_jump_timer: Timer = Timer.new()
var prevent_wall_slide_timer: Timer = Timer.new() # Used to prevent wall sliding after move_down out of wallslide
var _prevent_wall_slide_duration: float = 0.2

@export_group("Particles")
@export var dust_particles: GPUParticles3D
@export var jump_dust_particles: GPUParticles3D

@export_group("Components")
@export var player_hurtbox: PlayerHurtbox
@export var _skin: Node3D

func _ready():
	# dust_particles.emitting = false
	_gravity = gravity_default
	_move_speed = move_speed_ground

	coyote_jump_timer.one_shot = true
	coyote_jump_timer.autostart = false
	add_child(coyote_jump_timer)
	coyote_jump_timer.timeout.connect(on_coyote_jump_timer_timeout)

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
	camera.global_transform.origin = camera_pivot.global_transform.origin
	camera.rotation_degrees.y = 90
	camera.position.x = _zoom_target

## Called by parent Level
func set_camera_limits(left_limit: Vector3, right_limit: Vector3) -> void:
	_camera_limit_left = left_limit.z
	_camera_limit_right = right_limit.z

func _input(_event):
	if Input.is_action_just_pressed("left_click"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Input.is_action_just_pressed("escape"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Input.is_action_just_pressed("scroll_up"):
		_zoom_target -= zoom_step
	if Input.is_action_just_pressed("scroll_down"):
		_zoom_target += zoom_step

	if _can_move:
		if Input.is_action_just_pressed("sprint"):
			velocity.y = (jump_power * 1.5)
			jump_dust_particles.restart()
		if Input.is_action_just_released("sprint"):
			pass
		if Input.is_action_just_pressed("jump"):
			jump()
		if Input.is_action_just_pressed("move_down"):
			_is_moving_down = true
			reset_from_wall_slide()
			_wall_slide_allowed = false
			prevent_wall_slide_timer.start(_prevent_wall_slide_duration)
		if Input.is_action_just_released("move_down"):
			_is_moving_down = false
	
func _process(delta):
	process_camera_limits()
	process_camera_zoom(delta)
	process_after_image(delta)

func _physics_process(delta: float) -> void:
	# For a sidescroller we only need the right direction
	var raw_input: Vector2 = Vector2.ZERO
	var move_direction: Vector3 = Vector3.ZERO
	var right_direction: Vector3 = camera.global_basis.x
	if _can_move:
		raw_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		move_direction = (right_direction * raw_input.x)
		move_direction.y = 0.0 # Player will never give up-and-down move input. Jumping and falling with handle this
		move_direction = move_direction.normalized() # This is just intended to be a direction vector so it needs to be normalized

	_move_speed = move_speed_ground if is_on_floor() else move_speed_air

	var y_velocity = velocity.y
	velocity.y = 0.0
	velocity = velocity.move_toward(move_direction * _move_speed, acceleration * delta) # Apply horizontal movement
	velocity.y = clampf((y_velocity + (_gravity * (gravity_scale * delta))), min_y_velocity, max_y_velocity) # Apply vertical movement

	if move_direction.z < 0:
		wall_raycast.target_position.y = wall_raycast_distance_y
	elif move_direction.z > 0:
		wall_raycast.target_position.y = -wall_raycast_distance_y

	if _prev_is_on_floor != is_on_floor() and not is_on_floor():
		coyote_jump_timer.start(jump_coyote_time)
	_prev_is_on_floor = is_on_floor()

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
	if _is_wall_sliding:
		_skin.wall_slide()
	elif not is_on_floor() and velocity.y <= 0:
		_skin.fall()
	elif not is_on_floor() and velocity.y > 0:
		_skin.jump()
	elif is_on_floor():
		_coyote_jump_available = true
		coyote_jump_timer.stop()
		var ground_speed: float = velocity.length()
		_jump_count = 0
		if ground_speed > 1.0:
			_skin.move()
		else:
			_skin.idle()

func process_camera_zoom(delta: float) -> void:
	if not is_equal_approx(camera.position.x, _zoom_target):
		_zoom_target = clamp(_zoom_target, camera_zoom_min, camera_zoom_max)
		camera.position.x = lerp(camera.position.x, _zoom_target, zoom_sensitivity * delta)

func process_camera_limits() -> void:
	camera.global_position.z = clamp(camera.global_position.z, _camera_limit_right, _camera_limit_left)

## MUST be called in `_physics_process` to avoid desyncing which causes jittering
func process_camera_position(delta: float) -> void:

	# var camera_look_ahead_offset_target = velocity.normalized() * velocity.length() * .5

	# camera_look_ahead_offset = camera_look_ahead_offset.move_toward(camera_look_ahead_offset_target, delta*2)
	# print("Cam offset: ", camera_look_ahead_offset)
	# print("Vel len: ", velocity.length())

	# var target: Vector3 = camera_pivot.global_transform.origin + camera_look_ahead_offset
	var target: Vector3 = camera_pivot.global_transform.origin
	camera.global_transform.origin = lerp(camera.global_transform.origin, target, delta * camera_follow_speed)
	

func process_wall_slide(_move_direction: Vector3) -> void:
	if can_wall_slide() and not _is_wall_sliding and _move_direction != Vector3.ZERO and _wall_slide_allowed: # Start wall slide
		_is_wall_sliding = true
		velocity = Vector3.ZERO
		_gravity = gravity_wall_slide
		_jump_count = 0
	elif not can_wall_slide() and _is_wall_sliding: # JUST fell off wall
		reset_from_wall_slide()
	elif _is_wall_sliding: # Is actively wall sliding
		_gravity -= gravity_wall_slide_increment
func process_dust_particles() -> void:
	if not is_equal_approx(velocity.z, 0) and is_on_floor():
		dust_particles.emitting = true
	else:
		dust_particles.emitting = false

func process_after_image(delta) -> void:
	if after_image_active:
		_after_image_spawn_time_count += delta
		if _after_image_spawn_time_count >= after_image_spawn_time_max:
			create_after_image()
			_after_image_spawn_time_count = 0

func jump() -> void:
	if is_on_floor() or _coyote_jump_available or (_jump_count < jump_max):
		if _jump_count != 0: # air jumping
			jump_dust_particles.restart()
		_jump_count += 1
		_coyote_jump_available = false
		_skin.jump()
		var _jump_power: float = jump_power
		if _is_wall_sliding:
			_jump_power = wall_jump_power 
			velocity.z += (get_wall_normal().z * wall_push_power) # Push off away from wall if sliding
			_last_movement_direction = -_last_movement_direction # Flip direction character is facing

			_can_move = false
			wall_jump_timer.start(wall_jump_move_disable_duration)

		velocity.y = _jump_power

func on_coyote_jump_timer_timeout() -> void:
	_coyote_jump_available = false

## Returns true if wall_raycast is colliding, and character is not on floor
func can_wall_slide() -> bool:
	return wall_raycast.is_colliding() and not is_on_floor()

func sprint() -> void:
	_move_speed = move_speed_sprint
	_skin.animation_tree.set("parameters/TimeScale/scale", 1.25)

func reset_sprint() -> void:
	# TODO: Check if grounded or air
	_move_speed = move_speed_ground
	_skin.animation_tree.set("parameters/TimeScale/scale", 1.0)

func dash() -> void:
	after_image_active = true
	var raw_input: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var right_direction: Vector3 = camera.global_basis.x
	var move_direction: Vector3 = (right_direction * raw_input.x).normalized()
	velocity += (move_direction * 25)
	velocity.y += 10
	await get_tree().create_timer(.6).timeout
	after_image_active = false

func on_wall_jump_timer_timeout() -> void:
	_can_move = true

func on_prevent_wall_slide_timer_timeout() -> void:
	_wall_slide_allowed = true

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
	_is_wall_sliding = false
	_gravity = gravity_default
