class_name EnemyHandStateJumpWindup extends StateEnemy

var jump_data_1: JumpData
var jump_data_2: JumpData

var target: Node3D

var is_climbing: bool = false

var skip_second_jump_data_statuses: Array[JumpData.Status] = [JumpData.Status.UNDER_ROOF, JumpData.Status.ABOVE_PLATFORM, JumpData.Status.CLIMB]

func initialize(_owner) -> void:
	super(_owner)
	enemy.skin.jump_windup_complete.connect(on_jump_windup_complete)

func physics_update(delta: float) -> void:
	enemy.move_and_fall(delta, 0, Vector3.ZERO, 1000)

func enter(_previous_state_path: String, _data := {}) -> void:
	enemy.set_state_label("JUMP WINDUP")
	# Fail and write error to console if missing data
	if not _data.has("target"):
		printerr(name, ": enter() called with incomplete _data; missing 'target' key. _data = ", _data)
		return
	else:
		is_climbing = _previous_state_path.to_lower() == "enemyhandstateclimb"
		var continue_jump_windup: bool
		var z_direction_to_target: Vector3

		if is_climbing:
			target = enemy.player
			z_direction_to_target = enemy.get_z_direction(target.global_transform.origin)
			enemy.rotate_on_y(z_direction_to_target)
			jump_data_1 = get_jump_data(target)
			if jump_data_1.status == JumpData.Status.SUCCESS and jump_data_1.impulse != Vector3.ZERO:
				enemy.skin.jump_windup()
				return

		# Set the pre-windup impulse, start windup
		target = _data["target"]
		z_direction_to_target= enemy.get_z_direction(target.global_transform.origin)
		enemy.rotate_on_y(z_direction_to_target)
		jump_data_1 = get_jump_data(target)

		# Make sure jump_data_1 is always a valid option; if it isn't transition out
		continue_jump_windup = can_continue_from_jump_data_status(jump_data_1)
		if continue_jump_windup and jump_data_1.impulse != Vector3.ZERO:
			enemy.skin.jump_windup()
		else:
			trigger_jump_data_transition(jump_data_1)

# Calculate post-windup impulse and select which impulse to use
func on_jump_windup_complete() -> void:
	# This jump should always be valid; it will either be a new jump_data with a status
	# that does not require a transition, or the first jump data which has already tranisitioned out
	# if required
	var final_jump_data: JumpData = get_final_jump_data(jump_data_1)
	apply_jump(final_jump_data.impulse)
	enemy.raycast_floor.enabled = false
	tranisition.emit("enemyhandstateair")

## Adjust jump_data's impulse value based on its trajectory and obstacles along its path.
## Returns a bool which describes whether to continue with jump wind up. If true, continue with windup.
## If false, call [trigger_jump_data_transition] and pass the jump data; this will trigger the correct
## transition out. If jump can continue but needs modifications, do so here immeadiately.
func can_continue_from_jump_data_status(_jump_data: JumpData) -> bool:
	match _jump_data.status:
		JumpData.Status.SUCCESS: 
			return true
		JumpData.Status.UNDER_ROOF: 
			_jump_data.impulse = enemy.get_jump_impulse(_jump_data.target_position, _jump_data.squared_discriminant, true)
			return true
		JumpData.Status.FALL_CUTOFF: 
			_jump_data.impulse = enemy.get_jump_impulse(_jump_data.target_position, _jump_data.squared_discriminant, true)
			return true
		JumpData.Status.ABOVE_PLATFORM: 
			_jump_data.impulse = get_low_jump_impulse_in_player_direction()
			return true
		JumpData.Status.FAILED_IMPULSE:
			_jump_data.impulse = get_low_jump_impulse_in_player_direction()
			return true
		JumpData.Status.CLIMB:
			return false
		_: 
			push_error("Unknown _jump_status")
			return false

func get_final_jump_data(_jump_data_1: JumpData) -> JumpData:
	if is_climbing or _jump_data_1.status in skip_second_jump_data_statuses:
		return _jump_data_1
	
	var _jump_data_2: JumpData = get_jump_data(target) 
	if _jump_data_2.impulse == Vector3.ZERO:
		return _jump_data_1

	else:
		var continue_jump_windup: bool = can_continue_from_jump_data_status(_jump_data_2)
		if continue_jump_windup: # Do not use this jump if it requires a transition out, just the first
			return _jump_data_2
		else:
			return _jump_data_1

func trigger_jump_data_transition(_jump_data: JumpData) -> void:
	match _jump_data.status:
		JumpData.Status.CLIMB:
			enemy.clear_debug_trajectory_points()
			if is_climbing: tranisition.emit("enemyhandstatepatrol") # Don't transition back into climb if already climbing
			else: tranisition.emit("enemyhandstateclimb") 
		_: 
			push_error("Trying to transition on a JumpStatus that does not require it. JumpData.Status= ", enemy.get_jump_status_text(_jump_data.status))

func get_jump_data(_target: Node3D) -> JumpData:
	var _jump_data: JumpData = JumpData.new()

	# Calc impulse
	var _x_locked_target_position: Vector3 = enemy.get_x_locked_position(_target.global_transform.origin)
	var _squared_discriminant: float = enemy.compute_jump_impulse_discriminant(_x_locked_target_position)
	var _impulse: Vector3 = enemy.get_jump_impulse(_x_locked_target_position, _squared_discriminant)
	if _impulse == Vector3.ZERO:
		_jump_data.impulse = _impulse
		_jump_data.status = JumpData.Status.FAILED_IMPULSE
		_jump_data.target_position = _x_locked_target_position
		_jump_data.squared_discriminant = _squared_discriminant
		return _jump_data

	# Calc status
	var _status: JumpData.Status = enemy.get_jump_trajectory_status(_impulse, _target)

	_jump_data.impulse = _impulse
	_jump_data.status = _status
	_jump_data.target_position = _x_locked_target_position
	_jump_data.squared_discriminant = _squared_discriminant
	return _jump_data

func apply_jump(_impulse) -> void:
	if _impulse != Vector3.ZERO:
		enemy.velocity = _impulse

func get_low_jump_impulse_in_player_direction() -> Vector3:
	var z_direction_to_target = enemy.get_z_direction(target.global_transform.origin)
	var new_target_position: Vector3 = enemy.global_transform.origin + Vector3(0,1.5,(z_direction_to_target.z * 8))
	var _impulse = enemy.get_jump_impulse(new_target_position, enemy.compute_jump_impulse_discriminant(new_target_position), true)
	if enemy.show_debug: 
		DebugTools.create_debug_sphere(enemy, new_target_position, .5, 1, Color.GREEN)
		enemy.debug_draw_jump_trajectory(_impulse, target.global_transform.origin)
	return _impulse
