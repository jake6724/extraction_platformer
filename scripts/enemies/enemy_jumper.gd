class_name EnemyJumper extends Enemy


# TODO: Wind up, then jump. It should be similar to a dash
# TODO: Multiple types of jumps? High or low ? 

var player: Player

@export var jump_timer: Timer
@export var jump_delay_min: float = .25
@export var jump_delay_max: float = 1.0
@export var jump_power_min: float
@export var jump_power_max: float

@export var jump_height_min: float =20
@export var jump_height_max: float = 25
@export var jump_distance_min: float = 15
@export var jump_distance_max: float = 20

@export var area_detect_player: Area3D
@export var area_chase_quit: Area3D

@export var timer_chase_quit: Timer
@export var chase_quit_delay: float = 5.0

var jump_direction: Vector3
var jumping: bool = false

@export var ground_speed: float = 7.0
@export var acceleration: float = 40

@export var raycast_floor: RayCast3D
@export var raycast_wall: RayCast3D

@export var patrol_speed: float = 3.0
@export var chase_speed: float = 3.0
@export var escape_speed_multiplier: float = 2.7

@export var max_jump_trigger_distance: float = 7.0
@export var min_jump_trigger_distance: float = 5.0

@export var timer_jump_in_range: Timer
@export var jump_in_range_duration_requirement: float = 0.01

var _player_position_at_jump_trigger: Vector3

@export var outer_range_left: MeshInstance3D
@export var outer_range_right: MeshInstance3D
@export var inner_range_left: MeshInstance3D
@export var inner_range_right: MeshInstance3D

enum State {IDLE, PATROL, CHASE, CHARGE, AIR, LAND, HIT}
var current_state: State = State.PATROL

var current_patrol_direction: Vector3 = Vector3(0,0,1)

func _ready():
	super()
	jump_timer.timeout.connect(on_jump_timer_timeout)
	area_detect_player.body_entered.connect(on_area_detect_player_body_entered)
	area_detect_player.body_exited.connect(on_area_detect_player_body_exited)
	area_chase_quit.body_exited.connect(on_area_chase_quit_body_exited)
	timer_chase_quit.timeout.connect(on_timer_chase_quit_timeout)

	timer_jump_in_range.timeout.connect(on_timer_jump_in_range_timeout)

	skin.land_complete.connect(on_skin_land_complete)
	skin.jump_charge_complete.connect(on_skin_jump_complete)

	outer_range_left.position.z -= max_jump_trigger_distance
	outer_range_right.position.z += max_jump_trigger_distance
	inner_range_left.position.z -= min_jump_trigger_distance
	inner_range_right.position.z += min_jump_trigger_distance

	skin.run()

func _physics_process(delta):
	match current_state:
		State.IDLE: idle(delta)
		State.PATROL: patrol(delta)
		State.CHASE: chase(delta)
		# State.CHARGE: charge(delta)
		State.AIR: air(delta)
		State.LAND: land(delta)
		State.HIT: pass

# TODO: Determine if they should avoid each other or walk through each other
# They could have their own layer and pass through other enemy types
func patrol(delta: float) -> void:
	# Patrol until a wall found or end of platform reached
	if is_floor_ahead() and not is_wall_ahead():
		move_and_fall(delta, patrol_speed, current_patrol_direction)
	# Turn around
	else:
		current_patrol_direction *= -1
		rotate_on_y(current_patrol_direction)
		return
		
## The goal of chase is to get into a position where a jump can be triggered.
func chase(delta: float) -> void:
	var z_direction_to_player: float = player.global_transform.origin.z - global_transform.origin.z
	var _direction_to_player: Vector3 = Vector3(0,0,z_direction_to_player).normalized()

	var x_locked_player_position: Vector3 = player.global_transform.origin
	x_locked_player_position.x = 0
	var x_locked_position: Vector3 = global_transform.origin
	x_locked_position.x = 0
	var distance_to_player: float = x_locked_position.distance_to(x_locked_player_position)
	# Player in range of jump

	# Too close to player, move away
	if distance_to_player < min_jump_trigger_distance:
		rotate_on_y(-_direction_to_player)
		move_and_fall(delta, chase_speed * escape_speed_multiplier, -_direction_to_player)
		timer_jump_in_range.stop()
	# Too far from player, move toward
	elif distance_to_player > max_jump_trigger_distance:
		rotate_on_y(_direction_to_player)
		move_and_fall(delta, chase_speed, _direction_to_player)
		timer_jump_in_range.stop()
	# In jump range
	else:
		on_timer_jump_in_range_timeout()
		# if timer_jump_in_range.is_stopped():
		# 	timer_jump_in_range.start(jump_in_range_duration_requirement)

	# if distance_to_player >= min_jump_trigger_distance and distance_to_player <= max_jump_trigger_distance:
	# 	current_state = State.IDLE
	# 	_player_position_at_jump_trigger = x_locked_player_position
	# 	charge()
	# 	return
	# # Player out of range
	# else:
	# 	print("OUT OF RANGE!")
	# 	move_and_fall(delta, chase_speed, _direction_to_player)
	# 	face_mesh(_direction_to_player)

	# velocity = velocity.move_toward(_direction_to_player * ground_speed, delta * acceleration)
	# velocity.x = 0
	# velocity.y = move_toward(velocity.y, gravity_default, delta * gravity_acceleration)

	# face_mesh(_direction_to_player)
	# move_and_slide()

## Wrapper for basic movement. Adds gravity and calls `move_and_slide()`
func move_and_fall(delta: float, _move_speed: float, _move_direction: Vector3) -> void:
	var velocity_y = velocity.y
	velocity = velocity.move_toward(_move_direction * _move_speed, delta * acceleration)
	velocity.y = move_toward(velocity_y, gravity_default, delta * gravity_acceleration)
	velocity.x = 0
	move_and_slide()

func on_area_detect_player_body_entered(_player: Player) -> void:
	if current_state == State.IDLE or current_state == State.PATROL:
		player = _player
		current_state = State.CHASE
		skin.run()
		# var jump_delay: float = randf_range(jump_delay_min, jump_delay_max)
		# jump_timer.start(jump_delay)
	timer_chase_quit.stop() # Always cancel chase quitting process if they walk into attack range

func on_timer_jump_in_range_timeout() -> void:
	var x_locked_player_position: Vector3 = player.global_transform.origin
	x_locked_player_position.x = 0
	current_state = State.IDLE
	_player_position_at_jump_trigger = x_locked_player_position
	charge()

## Time to start a jump windup
func on_jump_timer_timeout() -> void:
	current_state = State.CHARGE
	skin.jump()
	flash_mesh_repeat(1.1, 3)
	await get_tree().create_timer(1.1).timeout
	apply_jump()

## Apply jump impulse, transition to air
func apply_jump() -> void:

	var initial_velocity: float = 20
	var x_range: float = player.global_transform.origin.z - global_transform.origin.z
	var y_range: float = player.global_transform.origin.y - global_transform.origin.y

	var g_x_squared: float = (abs(gravity_default)) * (pow(x_range, 2))
	var two_y_v_squared: float = 2 * y_range * (pow(initial_velocity, 2))

	var discriminant: float = (pow(initial_velocity, 4)) - ((abs(gravity_default)) * (g_x_squared + two_y_v_squared))
	var square_root_discriminant: float = sqrt(discriminant)
	var inner_solution: float = ((pow(initial_velocity, 2)) + square_root_discriminant) / ((abs(gravity_default)) * x_range)
	var angle_plus: float = atan(inner_solution)

	var _direction_to_player: Vector3 = get_direction_to_player(player)
	var _direction = Vector3(-sin(angle_plus), 0, -cos(angle_plus)).normalized()
	var jump_impulse_direction: Vector3 = Vector3(0, abs(_direction.x), abs(_direction.z) * sign(_direction_to_player.z))
	var impulse = jump_impulse_direction * initial_velocity

	print("x_range: ", x_range)
	print("y_range: ", y_range)

	print("g_x_squared: ", g_x_squared)
	print("two_y_v_squared: ", two_y_v_squared)
	print("discriminant: ", discriminant)
	print("square_root_discriminant: ", square_root_discriminant)
	print("inner_solution: ", inner_solution)

	print("_direction: ", _direction)
	print("jump_impulse_direction: ", jump_impulse_direction)
	print("angle_plus (to degree): ", rad_to_deg(angle_plus))
	print("impulse: ", impulse)

	velocity = impulse
	current_state = State.AIR
	skin.air()

	debug_draw_jump_trajectory(impulse)


	# var angle_minus: float = (initial_velocity**2) - under_root_value




	# var horizontal_distance: float = global_transform.origin.distance_to(player.global_transform.origin)
	# var angle: float = 0.5 * asin( (gravity_default  * horizontal_distance) / (launch_power ** 2))
	# print(rad_to_deg(angle))
	# var angle_vector: Vector3 = Vector3.FORWARD.rotated(Vector3.RIGHT, angle).normalized()
	# var impulse: Vector3 = angle_vector * launch_power
	# velocity = impulse
	# current_state = State.AIR
	# skin.air()

	# # var _direction_to_player: Vector3 = get_direction_to_player(player)
	# var _direction_to_player: Vector3 = global_transform.origin.direction_to(_player_position_at_jump_trigger)
	# var impulse: Vector3 = (_direction_to_player * 10) + Vector3(0,15,0)
	# velocity = impulse
	# rotate_on_y(_direction_to_player)
	# current_state = State.AIR
	# skin.air()

func debug_draw_jump_trajectory(_jump_impulse: Vector3) -> void:
	var iterations: int = 256
	var time_step: float = .01666
	
	for i in range(iterations):
		var new_mesh: MeshInstance3D = MeshInstance3D.new()

		var new_sphere_mesh: SphereMesh = SphereMesh.new()
		new_sphere_mesh.radius = 0.25
		new_sphere_mesh.height = 0.5
		new_sphere_mesh.radial_segments = 32
		new_sphere_mesh.rings = 16

		new_mesh.mesh = new_sphere_mesh
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color.RED
		new_mesh.material_override = material
		add_child(new_mesh)

		new_mesh.global_transform.origin = global_transform.origin + (_jump_impulse * time_step)
		_jump_impulse.y += gravity_default * time_step

		#velocity.y = move_toward(velocity.y, gravity_default, delta * gravity_acceleration)

		# var _jump_impulse_y: float = _jump_impulse.y + (i * .01666 * gravity_default)
		# var curr_jump_impulse: Vector3 = _jump_impulse
		# curr_jump_impulse.y = _jump_impulse_y
		# var iteration_position: Vector3 = global_transform.origin + curr_jump_impulse
		# new_mesh.global_transform.origin = iteration_position

func idle(delta: float) -> void:
	velocity = velocity.move_toward(Vector3.ZERO, delta*acceleration)
	velocity.x = 0
	velocity.y = move_toward(velocity.y, gravity_default, delta * gravity_acceleration)
	move_and_slide()

func air(delta: float) -> void:
	velocity.y = move_toward(velocity.y, gravity_default, delta * gravity_acceleration)
	velocity.x = 0
	move_and_slide()

	if is_on_floor():
		current_state = State.IDLE
		skin.land()

func charge() -> void:
	rotate_on_y(get_direction_to_player(player))
	skin.jump()

func land(delta: float) -> void:
	velocity = velocity.move_toward(Vector3.ZERO, delta*acceleration*10)
	move_and_collide(velocity * delta)

func on_skin_land_complete() -> void:
	current_state = State.CHASE # TODO: Check for target and do idle, patrol, or chase 
	skin.run()

func on_skin_jump_complete() -> void:
	apply_jump()

func on_area_chase_quit_body_exited(_player: Player) -> void:
	pass
	# if not timer_chase_quit.time_left > 0:
	# 	timer_chase_quit.start(chase_quit_delay)

func on_timer_chase_quit_timeout() -> void:
	pass
	# current_state = State.IDLE
	# skin.idle()
	# player = null

func get_direction_to_player(_player: Player) -> Vector3:
	var z_direction_to_player: float = _player.global_transform.origin.z - global_transform.origin.z
	var _direction_to_player: Vector3 = Vector3(0,0,z_direction_to_player).normalized()
	# print(_direction_to_player)
	return _direction_to_player

func can_attack() -> bool:
	if area_detect_player.get_overlapping_bodies().size() > 0:
		return true
	else:
		return false

func on_area_detect_player_body_exited(_player: Player) -> void:
	pass

func is_floor_ahead() -> bool:
	return raycast_floor.is_colliding()

func is_wall_ahead() -> bool:
	return raycast_wall.is_colliding()
