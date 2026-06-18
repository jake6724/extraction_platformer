class_name EnemyHandStateJumpWindup extends StateEnemy

"""
TODO: What happens if the first jump impulse is invalid? Vec3.Zero
"""

var jump_data_1: JumpData
var jump_data_2: JumpData

var target: Node3D

var is_climbing: bool = false

var skip_second_jump_data_statuses: Array[JumpData.Status] = [JumpData.Status.UNDER_ROOF, JumpData.Status.ABOVE_PLATFORM]

func initialize(_owner) -> void:
	super(_owner)
	enemy.skin.jump_windup_complete.connect(on_jump_windup_complete)

func physics_update(delta: float) -> void:
	enemy.move_and_fall(delta, 0, Vector3.ZERO, 1000)

func enter(_previous_state_path: String, _data := {}) -> void:
	print("========= ENTERED JUMP WIND UP =========")
	enemy.set_state_label("JUMP WINDUP")
	# Fail and write error to console if missing data
	if not _data.has("target"):
		push_error(name, ": enter() called with incomplete _data; missing 'target' key. _data = ", _data)
		return
	else:
		is_climbing = _previous_state_path.to_lower() == "enemyhandstateclimb"
		print("_previous_state_path.to_lower(): ", _previous_state_path.to_lower())
		print("Is climbing = ", is_climbing)

		var continue_jump_windup: bool
		var z_direction_to_target: Vector3

		if is_climbing:
			target = enemy.player
			z_direction_to_target = enemy.get_z_direction(target.global_transform.origin)
			enemy.rotate_on_y(z_direction_to_target)
			jump_data_1 = get_jump_data(target)
			if jump_data_1.status == JumpData.Status.SUCCESS and jump_data_1.impulse != Vector3.ZERO:
				print("Climb jump found player")
				enemy.skin.jump_windup()
				return
			else:
				print("Is climbing jump to player failed. Going back to target jump")

		# Set the pre-windup impulse, start windup
		target = _data["target"]
		z_direction_to_target= enemy.get_z_direction(target.global_transform.origin)
		enemy.rotate_on_y(z_direction_to_target)
		jump_data_1 = get_jump_data(target)

		continue_jump_windup = modify_jump_data_by_status(jump_data_1, false)
		print("Jump_data_1 Status: ", enemy.get_jump_status_text(jump_data_1.status))
		print("Jump_data_1 Impulse: ", jump_data_1.impulse)
		if continue_jump_windup and jump_data_1.impulse != Vector3.ZERO:
			print("Jump continuing to windup")
			enemy.skin.jump_windup()
		else:
			print("Fist transition")
			transition_on_status(jump_data_1)

# Calculate post-windup impulse and select which impulse to use
func on_jump_windup_complete() -> void:
	# Set defaults
	var _impulse: Vector3 = jump_data_1.impulse
	var _status: JumpData.Status = jump_data_1.status

	# Just use first jump_data if climbing or if status code in in skip category
	if not is_climbing and not jump_data_1.status in skip_second_jump_data_statuses:
		jump_data_2 = get_jump_data(target) 

		# THE +++++Transition to chase from success+++++++ error is here! 
		# Calling transition on status from the second jump is an issue. If it 
		# fails in certain cases we just want to use the first jump, not give up like
		# we would if the first jump completely fails (if first fails we have no backup so more serious)
		
		if jump_data_2.impulse != Vector3.ZERO:
			var continue_jump_windup: bool = modify_jump_data_by_status(jump_data_2, true)
			if continue_jump_windup and jump_data_2.impulse != Vector3.ZERO:
				if jump_data_2.impulse != Vector3.ZERO:
					_impulse = jump_data_2.impulse
					_status = jump_data_2.status
				else:
					print("No jump angle from second jump")
			else:
				print("Second transition")
				transition_on_status(jump_data_2)
				return

	print("Jump status: ", enemy.get_jump_status_text(_status))
	print("_impulse: ", _impulse)
	if _impulse != Vector3.ZERO:
		apply_jump(_impulse)
		enemy.raycast_floor.enabled = false
		tranisition.emit("enemyhandstateair")
		return
	else:
		print("Final Impulse was ZERO; patrolling")
		tranisition.emit("enemyhandstatepatrol")

func get_jump_data(_target: Node3D) -> JumpData:
	var _jump_data: JumpData = JumpData.new()

	# Calc impulse
	var _x_locked_target_position: Vector3 = enemy.get_x_locked_position(_target.global_transform.origin)
	var _squared_discriminant: float = enemy.compute_jump_impulse_discriminant(_x_locked_target_position)
	var _impulse: Vector3 = enemy.get_jump_impulse(_x_locked_target_position, _squared_discriminant)
	# Calc status
	var _status: JumpData.Status = enemy.get_jump_trajectory_status(_impulse, _target)

	_jump_data.impulse = _impulse
	_jump_data.status = _status
	_jump_data.target_position = _x_locked_target_position
	_jump_data.squared_discriminant = _squared_discriminant
	return _jump_data

## Adjust jump_data's impulse value based on its trajectory and obstacles along its path.
## Returns a bool which describes whether to continue with jump wind up. Certain jump statuses
## Trigger a transition to a different state, and no further action should occur in this state
func modify_jump_data_by_status(_jump_data: JumpData, second_jump_data: bool=false) -> bool:
	match _jump_data.status:
		JumpData.Status.SUCCESS: 
			# return _jump_data.impulse != Vector3.ZERO
			return true
		JumpData.Status.UNDER_ROOF: 
			_jump_data.impulse = enemy.get_jump_impulse(_jump_data.target_position, _jump_data.squared_discriminant, true)
			return true
		JumpData.Status.FALL_CUTOFF: 
			_jump_data.impulse = enemy.get_jump_impulse(_jump_data.target_position, _jump_data.squared_discriminant, true)
			return true
		JumpData.Status.ABOVE_PLATFORM: 
			# Find a jump point in the direction of player, but at the same level as enemy; low jump to it
			var z_direction_to_target = enemy.get_z_direction(target.global_transform.origin)
			var new_target_position: Vector3 = enemy.global_transform.origin + Vector3(0,1.5,(z_direction_to_target.z * 8))
			_jump_data.impulse = enemy.get_jump_impulse(new_target_position, enemy.compute_jump_impulse_discriminant(new_target_position), true)
			if enemy.show_debug: 
				DebugTools.create_debug_sphere(enemy,  new_target_position, .5, 1, Color.GREEN)
				enemy.debug_draw_jump_trajectory(_jump_data.impulse, target.global_transform.origin)
			return true
		JumpData.Status.CLIMB:
			enemy.clear_debug_trajectory_points()
			tranisition.emit("enemyhandstateclimb") 
			return false
		_: 
			push_error("Unknown _jump_status")
			return false

# Transition to a new state based on the status of _jump_data. Not all options will cause a transition
func transition_on_status(_jump_data: JumpData) -> void:
	print("Transition jump status: ", enemy.get_jump_status_text(_jump_data.status))
	match _jump_data.status:
		JumpData.Status.SUCCESS: 
			print("++++++++++++++++++++++++Transition to chase from success++++++++++++++++++++++++++")
			# tranisition.emit("enemyhandstatechase", {"trigger_jump_delay": .25})
			tranisition.emit("enemyhandstatepatrol")
		JumpData.Status.UNDER_ROOF: push_error("Trying to transition on status that does not require it: ", enemy.get_jump_status_text(_jump_data.status))
		JumpData.Status.FALL_CUTOFF: push_error("Trying to transition on status that does not require it: ", enemy.get_jump_status_text(_jump_data.status))
		JumpData.Status.ABOVE_PLATFORM: push_error("Trying to transition on status that does not require it: ", enemy.get_jump_status_text(_jump_data.status))
		JumpData.Status.CLIMB:
			if is_climbing: tranisition.emit("enemyhandstatepatrol")
			else: tranisition.emit("enemyhandstateclimb")
		_: push_error("Trying to transition on unknown jump_status")

func apply_jump(_impulse) -> void:
	if _impulse != Vector3.ZERO:
		enemy.velocity = _impulse
