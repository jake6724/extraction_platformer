class_name EnemyJumper extends Enemy

"""
TODO:
- If taking a low jump (because of roof or fall cutoff), only calculate that jump once
"""

@export_group("General")
# @export var acceleration: float = 40
@export_group("Patrol")
@export var patrol_speed: float = 3.0
var _current_patrol_direction: Vector3 = Vector3(0,0,1)
@export_group("Chase")
@export var chase_speed: float = 5.0
@export var escape_speed: float = 11.0
@export var speed_modifier_min: float = -1.0
@export var speed_modifier_max: float = 1.0
@export var chase_quit_delay: float = 5.0
@export var timer_chase_quit: Timer
@export_group("Jump")
@export var jump_power: float = 25.0
@export var jump_power_modifier_min: float = -4.0
@export var jump_power_modifier_max: float = 4.0
@export var jump_windup_speed_scale_base: float = 1.5
@export var jump_windup_speed_scale_modifier_min: float = -0.3
@export var jump_windup_speed_scale_modifier_max: float = 0.3
@export var timer_jump_in_range: Timer
@export var jump_in_range_duration_requirement: float = 0.01
@export var max_jump_trigger_distance: float = 7.0
@export var min_jump_trigger_distance: float = 5.0
## Tracks the most recent jump impulse; used in apply_jump()
var _jump_impulse: Vector3
var is_on_terrain_enable_delay: float = 0.2
var _jump_windup_speed_scale: float
var _jump_target_position: Vector3
var is_targeting_player: bool 
@export_group("Climb")
var _climb_move_direction: Vector3
var _roof_platform: SmartPlatform
@export_group("Components")
@export var area_detect_player: Area3D
@export var collider_detect_player: CollisionShape3D
@export var area_chase_quit: Area3D
@export var raycast_floor_ahead: RayCast3D
@export var raycast_wall: RayCast3D
@export var raycast_floor: RayCast3D
@export var raycast_sight: RayCast3D
@export var raycast_ceiling: RayCast3D
@export var shapecast_jump: ShapeCast3D
@export_group("Debug")
@export var trajectory_debug_parent: Node
@export var show_debug: bool = true
@export var outer_range_left: MeshInstance3D
@export var outer_range_right: MeshInstance3D
@export var inner_range_left: MeshInstance3D
@export var inner_range_right: MeshInstance3D
## How many time steps into future to predict trajectory
@export var trajectory_debug_iterations: int = 128
## Takes the place of delta in velocity calculations. Lower values give more precision
@export var trajectory_debug_time_step: float = .0166

enum State {IDLE, PATROL, CHASE, CHARGE, AIR, LAND, HIT, CLIMB}
enum JumpStatus {SUCCESS, UNDER_ROOF, FALL_CUTOFF, ABOVE_PLATFORM, CLIMB}
var current_state: State = State.PATROL
var player: Player

func _ready():
	super()
	area_detect_player.body_entered.connect(on_area_detect_player_body_entered)
	area_detect_player.body_exited.connect(on_area_detect_player_body_exited)
	area_chase_quit.body_exited.connect(on_area_chase_quit_body_exited)
	timer_chase_quit.timeout.connect(on_timer_chase_quit_timeout)

	axis_lock_linear_x = true

	jump_power += randf_range(jump_power_modifier_min, jump_power_modifier_max)
	chase_speed += randf_range(speed_modifier_min, speed_modifier_max)
	escape_speed += randf_range(speed_modifier_min, speed_modifier_max)
	_jump_windup_speed_scale = jump_windup_speed_scale_base + randf_range(jump_windup_speed_scale_modifier_min, jump_windup_speed_scale_modifier_max)
	skin.jump_windup_speed_scale = _jump_windup_speed_scale

	skin.land_complete.connect(on_skin_land_complete)
	skin.jump_charge_complete.connect(on_skin_jump_charge_complete)

	collider_detect_player.shape.radius = min_jump_trigger_distance

	raycast_floor.enabled = false

	outer_range_left.position.z -= max_jump_trigger_distance
	outer_range_right.position.z += max_jump_trigger_distance
	inner_range_left.position.z -= min_jump_trigger_distance
	inner_range_right.position.z += min_jump_trigger_distance
	outer_range_left.visible = show_debug
	outer_range_right.visible = show_debug
	inner_range_left.visible = show_debug
	inner_range_right.visible = show_debug
	skin.run()

func _physics_process(delta):
	#print_state()
	match current_state:
		State.IDLE: idle(delta)
		State.PATROL: patrol(delta)
		State.CHASE: chase(delta)
		State.CHARGE: charge(delta)
		State.AIR: air(delta)
		State.CLIMB: climb(delta)
		State.HIT: pass

func idle(delta: float) -> void:
	var velocity_y: float = velocity.y
	velocity = velocity.move_toward(Vector3.ZERO, delta*acceleration)
	velocity.x = 0
	velocity.y = move_toward(velocity_y, gravity_default, delta * gravity_acceleration)
	move_and_slide()

func charge(delta: float) -> void:
	var velocity_y: float = velocity.y
	velocity = Vector3.ZERO
	velocity.x = 0
	velocity.y = move_toward(velocity_y, gravity_default, delta * gravity_acceleration)
	move_and_slide()

func patrol(delta: float) -> void:
	if not is_on_floor():
		move_and_fall(delta, patrol_speed, _current_patrol_direction, acceleration)
		return 

	# Patrol in a direction until a wall found or end of platform reached
	if is_floor_ahead() and not is_wall_ahead():
		move_and_fall(delta, patrol_speed, _current_patrol_direction, acceleration)
	# Turn around
	else:
		_current_patrol_direction *= -1
		rotate_on_y(_current_patrol_direction)
		return

## The goal of chase is to get into a position where a jump can be triggered.
func chase(delta: float) -> void:
	# enable_enemy_collisions_1_frame()
	var z_direction_to_player: float = player.global_transform.origin.z - global_transform.origin.z
	var _direction_to_player: Vector3 = Vector3(0,0,z_direction_to_player).normalized()

	var x_locked_position: Vector3 = global_transform.origin
	x_locked_position.x = 0
	var distance_to_player: float = x_locked_position.distance_to(get_x_locked_player_position())

	# Take a jump if no where left to run
	if not is_floor_ahead() or is_wall_ahead():
		rotate_on_y(-_direction_to_player)
		_jump_target_position = player.global_transform.origin
		start_jump_charge()

	# Too close to player, move away
	if distance_to_player < min_jump_trigger_distance:
		rotate_on_y(-_direction_to_player)
		move_and_fall(delta, escape_speed, -_direction_to_player, acceleration)
		timer_jump_in_range.stop()
	# Too far from player, move toward
	elif distance_to_player > max_jump_trigger_distance:
		rotate_on_y(_direction_to_player)
		move_and_fall(delta, chase_speed, _direction_to_player, acceleration)
		timer_jump_in_range.stop()
	# In jump range
	else:
		_jump_target_position = player.global_transform.origin
		is_targeting_player = true
		start_jump_charge()

func start_climb() -> void:
	current_state = State.CLIMB
	_climb_move_direction = Vector3(0,0,[-1,1].pick_random())
	_roof_platform = raycast_sight.get_collider()
	print(_climb_move_direction)
	print(_roof_platform.left_edge_point)
	print(_roof_platform.right_edge_point)

func climb(delta: float) -> void:
	# Get out from under any platforms
	if raycast_ceiling.is_colliding():
		# print("Under the roof")
		rotate_on_y(_climb_move_direction)
		move_and_fall(delta, chase_speed, _climb_move_direction, acceleration)
		return
	
	var distance_to_left_edge: float = abs(_roof_platform.left_edge_point.z - global_transform.origin.z)
	var distance_to_right_edge: float = abs(_roof_platform.right_edge_point.z - global_transform.origin.z)
	# print("_climb_move_direction: ", _climb_move_direction)
	# print("distance_to_left_edge: ", distance_to_left_edge)
	# print("distance_to_right_edge: ", distance_to_right_edge)
	if _climb_move_direction.z == -1: # Moving right
		if distance_to_right_edge > 4 and distance_to_right_edge < 6:
			# Try to jump to player before jumping to ledge
			_jump_target_position = player.global_transform.origin
			is_targeting_player = true
			_jump_impulse = get_valid_jump()
			if _jump_impulse != Vector3.LEFT and _jump_impulse != Vector3.ZERO:
				current_state = State.CHARGE
				jump_windup()
				return

			# Couldn't jump to player, jump to ledge
			_jump_target_position = _roof_platform.right_edge_point
			is_targeting_player = false
			start_jump_charge()
			return

	elif _climb_move_direction.z == 1: # Moving left:
		if distance_to_left_edge > 4 and distance_to_left_edge < 6:
			# Try to jump to player before jumping to ledge
			_jump_target_position = player.global_transform.origin
			is_targeting_player = true
			_jump_impulse = get_valid_jump()
			if _jump_impulse != Vector3.LEFT and _jump_impulse != Vector3.ZERO:
				current_state = State.CHARGE
				jump_windup()
				return

			# Couldn't jump to player, jump to ledge
			_jump_target_position = _roof_platform.right_edge_point
			is_targeting_player = false
			start_jump_charge()
			return

	move_and_fall(delta, chase_speed, _climb_move_direction, acceleration)

func air(delta: float) -> void:
	velocity.y = move_toward(velocity.y, gravity_default, delta * gravity_acceleration)
	velocity.x = 0
	move_and_slide()

	if is_on_terrain():
		current_state = State.IDLE
		raycast_floor.enabled = false
		skin.land()
		clear_debug_trajectory_points()

## Connected to [skin.land_complete]; called once skin land animation has finished
## Tranisitions to post jumping behavior
func on_skin_land_complete() -> void:
	current_state = State.CHASE # TODO: Check for target and do idle, patrol, or chase 
	skin.run()
	enable_enemy_collisions_1_frame()

func on_area_detect_player_body_entered(_player: Player) -> void:
	if current_state == State.PATROL:
		player = _player
		current_state = State.CHASE
		skin.run()
	timer_chase_quit.stop() # Always cancel chase quitting process if they walk into attack range

func on_area_detect_player_body_exited(_player: Player) -> void:
	# If patrolling, try to jump when player exits 
	if current_state == State.PATROL:
		start_jump_charge()

func start_jump_charge() -> void:
	current_state = State.CHARGE
	_jump_impulse = get_valid_jump()
	if _jump_impulse == Vector3.LEFT: # Enemy is above platform and will transition to patrol
		return
	if _jump_impulse != Vector3.ZERO:
		jump_windup()

func jump_windup() -> void:
	rotate_on_y(get_direction_to_player(player))
	skin.jump() # Plays jump wind-up animations, triggers on_skin_jump_charge_complete() when windup complete

## Connected to [skin.jump_charge_complete]; called once skin jump windup animation has finished.
## Triggers actual jump physics
func on_skin_jump_charge_complete() -> void:
	var temp_jump_impulse: Vector3 = get_valid_jump()
	if temp_jump_impulse == Vector3.LEFT:
		return 
	elif temp_jump_impulse != Vector3.ZERO:
		_jump_impulse = temp_jump_impulse
	apply_jump()

func get_x_locked_position(_position: Vector3) -> Vector3:
	var x_locked_position: Vector3 = _position
	x_locked_position.x = 0
	return x_locked_position

func get_valid_jump() -> Vector3:
	var _x_locked_target_position: Vector3 = get_x_locked_position(_jump_target_position)
	var _squared_discriminant: float = compute_jump_impulse_discriminant(_x_locked_target_position)
	var _res_jump_impulse: Vector3 = get_jump_impulse(_x_locked_target_position, _squared_discriminant)

	var jump_check_result: JumpStatus = get_jump_trajectory_status(_res_jump_impulse)
	print_jump_failure(jump_check_result)

	match jump_check_result:
		JumpStatus.UNDER_ROOF: _res_jump_impulse = get_jump_impulse(_x_locked_target_position, _squared_discriminant, true)
		JumpStatus.FALL_CUTOFF: _res_jump_impulse = get_jump_impulse(_x_locked_target_position, _squared_discriminant, true)
		JumpStatus.CLIMB: 
			start_climb()
			return Vector3.LEFT
		JumpStatus.ABOVE_PLATFORM: 
			current_state = State.PATROL
			skin.run()
			_current_patrol_direction = get_direction_to_player(player)
			rotate_on_y(_current_patrol_direction)
			clear_debug_trajectory_points()
			return Vector3.LEFT

	return _res_jump_impulse

func compute_jump_impulse_discriminant(_x_locked_target_position: Vector3) -> float:
	var initial_velocity: float = jump_power
	var x_range: float = _x_locked_target_position.z - global_transform.origin.z
	var y_range: float = _x_locked_target_position.y - global_transform.origin.y

	# Compute the products in the discriminant
	var g_x_squared: float = (abs(gravity_default)) * (pow(x_range, 2))
	var two_y_v_squared: float = 2 * y_range * (pow(initial_velocity, 2))
	if is_nan(g_x_squared) or is_nan(two_y_v_squared):
		return -1
	# Compute discriminant and its sqrt
	var discriminant: float = (pow(initial_velocity, 4)) - ((abs(gravity_default)) * (g_x_squared + two_y_v_squared))
	var square_root_discriminant: float = sqrt(discriminant)
	if is_nan(discriminant) or is_nan(square_root_discriminant):
		return -1
	return square_root_discriminant

## Based on "Angle θ required to hit coordinate (x, y)" section of https://en.wikipedia.org/wiki/Projectile_motion
func get_jump_impulse(_player_position: Vector3, squared_discriminant: float, low_jump: bool=false) -> Vector3:
	if squared_discriminant == -1:
		return Vector3.ZERO

	var x_range: float = _player_position.z - global_transform.origin.z
	var initial_velocity: float = jump_power
	var inner_solution_operation: Callable = add_func if not low_jump else sub_func

	# Compute the value inside the highest-level parenthesis 
	# The +/- here:[(pow(initial_velocity, 2)) +/- square_root_discriminant)] determines where the high or low arc is used.
	var inner_solution: float = inner_solution_operation.call((pow(initial_velocity, 2)), squared_discriminant) / ((abs(gravity_default)) * x_range)
	# Compute final angle
	var angle: float = atan(inner_solution)
	if is_nan(inner_solution) or is_nan(angle):
		return Vector3.ZERO

	var _direction_to_player: Vector3 = get_direction_to_player(player)
	# Compute the direction vector based on angle. -sin = y amount, -cos = z amount (in this specific case, usually x) 
	var _direction = Vector3(-sin(angle), 0, -cos(angle)).normalized()
	# Compute the jump impulse, using the direction to the player to direct the z-axis of the jump
	# Re-order the direction vector so that x,y,z are all in their correct positions. Orient the z value with direction to player
	var jump_impulse_direction: Vector3 = Vector3(0, abs(_direction.x), abs(_direction.z) * sign(_direction_to_player.z))
	var impulse = jump_impulse_direction * initial_velocity
	if show_debug: debug_draw_jump_trajectory(impulse, _player_position)
	return impulse

func debug_draw_jump_trajectory(_impulse: Vector3, _player_position: Vector3) -> void:
	var curr_position: Vector3 = global_transform.origin	
	# Place a debug mesh at the target position
	DebugTools.create_debug_sphere(self, _player_position, .3, .6, Color.ORANGE)

	# Place a debug mesh along the jump impulse's trajectory
	for i in range(trajectory_debug_iterations):
		# Increment placement position based on trajectory's path at next time step
		curr_position += (_impulse * trajectory_debug_time_step)
		DebugTools.create_debug_sphere(self, curr_position, .15, .3, Color.RED)
		_impulse.y = move_toward(_impulse.y, gravity_default, trajectory_debug_time_step * gravity_acceleration)

func get_jump_trajectory_status(_impulse: Vector3) -> JumpStatus: 
	var curr_position: Vector3 = global_transform.origin
	var prev_position: Vector3
	var local_timestep: float = 0.016
	var local_iterations: int = 128
	var count: int = 0
	var count_target: int = 1

	var initial_iterations: int = 2
	for i in range(initial_iterations):
		curr_position += (_impulse * local_timestep)
		_impulse.y = move_toward(_impulse.y, gravity_default, local_timestep * gravity_acceleration)

	prev_position = curr_position

	for i in range(local_iterations):
		curr_position += (_impulse * local_timestep)
		if count == count_target:
			count = 0
			if show_debug: DebugTools.create_debug_sphere(self, curr_position, .2, .4, Color.PURPLE)
			# Shapecast from the previous trajectory position  to the next. This will sweep along the arc
			shapecast_jump.global_transform.origin = prev_position
			shapecast_jump.target_position = to_local(curr_position) - shapecast_jump.transform.origin
			shapecast_jump.force_shapecast_update()
			prev_position = curr_position
			#await get_tree().create_timer(.05).timeout
			if shapecast_jump.is_colliding():
				print("Shapecast collision: ", shapecast_jump.get_collider(0))

				# Trajectory hits player without anything in the way, this is a valid jump and stop early
				if shapecast_jump.get_collider(0) is Player:
					return JumpStatus.SUCCESS

				raycast_sight.target_position = to_local(get_x_locked_player_position())
				raycast_sight.force_raycast_update()

				# Arc Up intersected
				if _impulse.y > 0:
					# Check if under a platform and should perform low jump instead
					if not raycast_sight.is_colliding():
						return JumpStatus.UNDER_ROOF
					else:
						return JumpStatus.CLIMB

				# Arc Down intersected
				elif _impulse.y < 0 and is_targeting_player:					
					if not raycast_sight.is_colliding():
						return JumpStatus.FALL_CUTOFF
					else:
						if is_above_player():
							return JumpStatus.ABOVE_PLATFORM
		else:
			count += 1
		_impulse.y = move_toward(_impulse.y, gravity_default, local_timestep * gravity_acceleration)

	return JumpStatus.SUCCESS

## Apply jump impulse, transition to air. Impulse used is `_jump_impulse`
func apply_jump() -> void:
	rotate_on_y(get_direction_to_player(player))
	if _jump_impulse != Vector3.ZERO:
		velocity = _jump_impulse
		current_state = State.AIR
		skin.air()
		await get_tree().create_timer(is_on_terrain_enable_delay).timeout
		raycast_floor.enabled = true
	else:
		current_state = State.CHASE

func get_direction_to_player(_player: Player) -> Vector3:
	var z_direction_to_player: float = _player.global_transform.origin.z - global_transform.origin.z
	var _direction_to_player: Vector3 = Vector3(0,0,z_direction_to_player).normalized()
	return _direction_to_player

func is_floor_ahead() -> bool:
	return raycast_floor_ahead.is_colliding()

func is_wall_ahead() -> bool:
	return raycast_wall.is_colliding()

func print_state() -> void:
	var _text: String
	match current_state:
		State.IDLE: _text = "IDLE"
		State.CHASE: _text = "CHASE"
		State.AIR: _text = "AIR"
		State.LAND: _text = "LAND"
		State.HIT: _text = "HIT"
	print(_text)

func get_x_locked_player_position() -> Vector3:
	var x_locked_player_position: Vector3 = player.tracker.global_transform.origin
	x_locked_player_position.x = 0
	return x_locked_player_position

func is_on_terrain() -> bool:
	return true if raycast_floor.is_colliding() else false

func add_func(a: float, b: float) -> float:
	return a + b

func sub_func(a: float, b: float) -> float:
	return a - b

func print_jump_failure(jf: JumpStatus) -> void:
	var _text: String
	match jf:
		JumpStatus.SUCCESS: _text="Success"
		JumpStatus.UNDER_ROOF: _text="Under Roof"
		JumpStatus.FALL_CUTOFF: _text="Fall Cutoff"
		JumpStatus.CLIMB: _text="Climb"
		JumpStatus.ABOVE_PLATFORM: _text="Above Platform"
		_: push_error("Jump Failure: ", jf, " not defined")
	print("JumpStatus: ", _text)

func clear_debug_trajectory_points() -> void:
	await get_tree().create_timer(1).timeout
	DebugTools.clear_source_debugs(self)


func on_area_chase_quit_body_exited(_player: Player) -> void:
	pass

func on_timer_chase_quit_timeout() -> void:
	pass

func is_under_ceiling() -> bool:
	return true

# func is_same_height_as_player() -> bool:
# 	var height_diff
# 	return abs(global_transform.origin.y - player.global_transform.origin.y) > 3

func is_above_player() -> bool:
	return global_transform.origin.y > (player.global_transform.origin.y + 3)
