class_name EnemyHandStateJumpWindup extends StateEnemy

"""
TODO: What happens if the first jump impulse is invalid? Vec3.Zero
"""

var jump_data_1: JumpData
var jump_data_2: JumpData

var target: Node3D

func initialize(_owner) -> void:
	super(_owner)
	enemy.skin.jump_windup_complete.connect(on_jump_windup_complete)

func physics_update(delta: float) -> void:
	enemy.move_and_fall(delta, 0, Vector3.ZERO, enemy.acceleration)

func enter(_previous_state_path: String, _data := {}) -> void:
	enemy.set_state_label("JUMP WINDUP")
	# Fail and write error to console if missing data
	if not _data.has("target"):
		push_error(name, ": enter() called with incomplete _data; missing 'target' key. _data = ", _data)
		return
	# Set the pre-windup impulse, start windup
	else:
		target = _data["target"]
		jump_data_1 = get_jump_data(target)
		var continue_jump_windup: bool = modify_jump_data_by_status(jump_data_1)
		if continue_jump_windup:
			enemy.skin.jump_windup()

# Calculate post-windup impulse and select which impulse to use
func on_jump_windup_complete() -> void:
	var _impulse: Vector3 = jump_data_1.impulse
	var _status: JumpData.Status = jump_data_1.status
	if jump_data_1.status != JumpData.Status.UNDER_ROOF: # This could be an array if more than one quick-fails
		jump_data_2 = get_jump_data(target)
		var continue_jump_windup: bool = modify_jump_data_by_status(jump_data_2)
		if continue_jump_windup and jump_data_2.impulse != Vector3.ZERO:
			_impulse = jump_data_2.impulse
			_status = jump_data_2.status

	print("Jump status: ", enemy.get_jump_status_text(_status))
	apply_jump(_impulse)
	enemy.raycast_floor.enabled = false
	tranisition.emit("enemyhandstateair")

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
func modify_jump_data_by_status(_jump_data: JumpData) -> bool:
	match _jump_data.status:
		JumpData.Status.SUCCESS: return true
		JumpData.Status.UNDER_ROOF: 
			_jump_data.impulse = enemy.get_jump_impulse(_jump_data.target_position, _jump_data.squared_discriminant, true)
			return true
		JumpData.Status.FALL_CUTOFF: 
			_jump_data.impulse = enemy.get_jump_impulse(_jump_data.target_position, _jump_data.squared_discriminant, true)
			return true
		JumpData.Status.CLIMB:
			enemy.clear_debug_trajectory_points()
			tranisition.emit("enemyhandstateclimb") 
			return false
		JumpData.Status.ABOVE_PLATFORM: 
			enemy.clear_debug_trajectory_points()
			tranisition.emit("enemyhandstatepatrol") 
			return false
		_: 
			push_error("Unknown _jump_status")
			return false

func apply_jump(_impulse) -> void:
	if _impulse != Vector3.ZERO:
		enemy.velocity = _impulse