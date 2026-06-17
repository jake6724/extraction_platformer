class_name EnemyJumper extends Enemy

@export_group("Patrol")
@export var patrol_speed: float = 3.0
@export_group("Chase")
@export var chase_speed: float = 5.0
@export var escape_speed: float = 11.0
@export var speed_modifier_min: float = -1.0
@export var speed_modifier_max: float = 1.0
@export_group("Jump")
@export var jump_power: float = 25.0
@export var jump_power_modifier_min: float = -4.0
@export var jump_power_modifier_max: float = 4.0
@export var jump_windup_speed_scale_base: float = 1.5
@export var jump_windup_speed_scale_modifier_min: float = -0.3
@export var jump_windup_speed_scale_modifier_max: float = 0.3
@export var max_jump_trigger_distance: float = 7.0
@export var min_jump_trigger_distance: float = 5.0
var _jump_windup_speed_scale: float
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
@export var state_machine: StateMachineEnemy
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
@export var state_label: Label3D

var player: Player

func _ready():
	super()

	axis_lock_linear_x = true

	jump_power += randf_range(jump_power_modifier_min, jump_power_modifier_max)
	chase_speed += randf_range(speed_modifier_min, speed_modifier_max)
	escape_speed += randf_range(speed_modifier_min, speed_modifier_max)
	_jump_windup_speed_scale = jump_windup_speed_scale_base + randf_range(jump_windup_speed_scale_modifier_min, jump_windup_speed_scale_modifier_max)
	skin.jump_windup_speed_scale = _jump_windup_speed_scale

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

func _physics_process(_delta):
	pass
	# print(state_machine.state.name)

func get_x_locked_position(_position: Vector3) -> Vector3:
	var x_locked_position: Vector3 = _position
	x_locked_position.x = 0
	return x_locked_position

func get_jump_data(_target: Node3D) -> JumpData:
	var _jump_data: JumpData = JumpData.new()

	# Calc impulse
	var _x_locked_target_position: Vector3 = get_x_locked_position(_target.global_transform.origin)
	var _squared_discriminant: float = compute_jump_impulse_discriminant(_x_locked_target_position)
	var _impulse: Vector3 = get_jump_impulse(_x_locked_target_position, _squared_discriminant)
	# Calc status
	var _status: JumpData.Status = get_jump_trajectory_status(_impulse, _target)

	_jump_data.impulse = _impulse
	_jump_data.status = _status
	_jump_data.target_position = _x_locked_target_position
	_jump_data.squared_discriminant = _squared_discriminant
	return _jump_data

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
func get_jump_impulse(_target_position: Vector3, squared_discriminant: float, low_jump: bool=false) -> Vector3:
	if squared_discriminant == -1:
		return Vector3.ZERO

	var x_range: float = _target_position.z - global_transform.origin.z
	var initial_velocity: float = jump_power
	var inner_solution_operation: Callable = add_func if not low_jump else sub_func

	# Compute the value inside the highest-level parenthesis 
	# The +/- here:[(pow(initial_velocity, 2)) +/- square_root_discriminant)] determines where the high or low arc is used.
	var inner_solution: float = inner_solution_operation.call((pow(initial_velocity, 2)), squared_discriminant) / ((abs(gravity_default)) * x_range)
	# Compute final angle
	var angle: float = atan(inner_solution)
	if is_nan(inner_solution) or is_nan(angle):
		return Vector3.ZERO

	var direction_to_target: Vector3 = get_z_direction(_target_position)
	# Compute the direction vector based on angle. -sin = y amount, -cos = z amount (in this specific case, usually x) 
	var _direction = Vector3(-sin(angle), 0, -cos(angle)).normalized()
	# Compute the jump impulse, using the direction to the player to direct the z-axis of the jump
	# Re-order the direction vector so that x,y,z are all in their correct positions. Orient the z value with direction to player
	var jump_impulse_direction: Vector3 = Vector3(0, abs(_direction.x), abs(_direction.z) * sign(direction_to_target.z))
	var impulse = jump_impulse_direction * initial_velocity
	if show_debug: debug_draw_jump_trajectory(impulse, _target_position)
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

func get_jump_trajectory_status(_impulse: Vector3, _target: Node3D) -> JumpData.Status: 
	var target_is_player: bool = _target is Player
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
				var collision_object: Object = shapecast_jump.get_collider(0)
				print("collision_object: ", collision_object)

				# Trajectory hits player without anything in the way, this is a valid jump and stop early
				if collision_object is Player:
					print("SELECTED EARLY SUCCESS")
					return JumpData.Status.SUCCESS

				else:
					print("Collision occurred with terrain")
					raycast_sight.target_position = to_local(get_x_locked_position(_target.global_transform.origin))
					raycast_sight.force_raycast_update()

					# Arc Up intersected
					if _impulse.y > 0:
						# Check if under a platform and should perform low jump instead
						if (_target.global_transform.origin.y < collision_object.global_transform.origin.y) and (global_transform.origin.y < collision_object.global_transform.origin.y):
							return JumpData.Status.UNDER_ROOF
						else:
							print("SELECTED CLIMB")
							return JumpData.Status.CLIMB

					# Arc Down intersected
					elif _impulse.y < 0:
						if target_is_player:
							if (_target.global_transform.origin.y < collision_object.global_transform.origin.y) and (global_transform.origin.y < collision_object.global_transform.origin.y):
								print("SELECTED FALL_CUTOFF")
								return JumpData.Status.FALL_CUTOFF
							else:
								if is_above_player():
									print("SELECTED ABOVE_PLATFORM")
									return JumpData.Status.ABOVE_PLATFORM
						else:
							print("Jump arc intersected down, and target WAS NOT player")
							return JumpData.Status.SUCCESS

					else:
						push_error("This should not be taken. _impulse.y = ", _impulse.y)
						return JumpData.Status.SUCCESS
		else:
			count += 1
		_impulse.y = move_toward(_impulse.y, gravity_default, local_timestep * gravity_acceleration)

	print("SELECTED FINAL SUCCESS")
	return JumpData.Status.SUCCESS

## Adjust jump_data's impulse value based on its trajectory and obstacles along its path.
## Returns a bool which describes whether to continue with jump wind up. Certain jump statuses
## Trigger a transition to a different state, and no further action should occur in this state
func modify_jump_data_by_status(_jump_data: JumpData) -> bool:
	match _jump_data.status:
		JumpData.Status.SUCCESS: 
			return true
		JumpData.Status.UNDER_ROOF: 
			_jump_data.impulse = get_jump_impulse(_jump_data.target_position, _jump_data.squared_discriminant, true)
			return true
		JumpData.Status.FALL_CUTOFF: 
			_jump_data.impulse = get_jump_impulse(_jump_data.target_position, _jump_data.squared_discriminant, true)
			return true
		JumpData.Status.CLIMB:
			clear_debug_trajectory_points()
			# tranisition.emit("enemyhandstateclimb") 
			return false
		JumpData.Status.ABOVE_PLATFORM: 
			clear_debug_trajectory_points()
			# tranisition.emit("enemyhandstatepatrol") 
			return false
		_: 
			push_error("Unknown _jump_status")
			return false

func get_z_direction(target_position: Vector3) -> Vector3:
	# var zdirection_to_target: float = target_position.z - global_transform.origin.z
	# var direction_to_target: Vector3 = Vector3(0,0,zdirection_to_target).normalized()

	var direction: Vector3 = global_transform.origin.direction_to(target_position)
	direction.x = 0
	direction.y = 0
	direction = direction.normalized()

	return direction

func is_floor_ahead() -> bool:
	return raycast_floor_ahead.is_colliding()

func is_wall_ahead() -> bool:
	return raycast_wall.is_colliding()

func is_on_terrain() -> bool:
	return true if raycast_floor.is_colliding() else false

func add_func(a: float, b: float) -> float:
	return a + b

func sub_func(a: float, b: float) -> float:
	return a - b

func get_jump_status_text(_status: JumpData.Status) -> String:
	var _text: String
	match _status:
		JumpData.Status.SUCCESS: _text="Success"
		JumpData.Status.UNDER_ROOF: _text="Under Roof"
		JumpData.Status.FALL_CUTOFF: _text="Fall Cutoff"
		JumpData.Status.CLIMB: _text="Climb"
		JumpData.Status.ABOVE_PLATFORM: _text="Above Platform"
	return _text

func clear_debug_trajectory_points() -> void:
	await get_tree().create_timer(1).timeout
	DebugTools.clear_source_debugs(self)

func is_under_ceiling() -> bool:
	return true

func is_above_player() -> bool:
	return global_transform.origin.y > (player.global_transform.origin.y + 3)

func is_same_height_as_target(_target: Node3D) -> bool: 
	var diff: float = abs(global_transform.origin.y - _target.global_transform.origin.y)
	return diff < .5

func set_state_label(_text: String) -> void:
	state_label.text = _text
