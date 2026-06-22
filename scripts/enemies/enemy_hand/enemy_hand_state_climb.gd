class_name EnemyHandStateClimb extends StateEnemy

## CHeck both ways when reposition, if the first doesnt work. If both dont work, patrol

var smart_platform: SmartPlatform = null
var selected_edge: SmartPlatform.Edge = SmartPlatform.Edge.LEFT
var edge_options: Array[SmartPlatform.Edge] = [SmartPlatform.Edge.LEFT, SmartPlatform.Edge.RIGHT]
var direction_to_edge: Vector3

var initial_direction_checked: bool = false

# var left_checked: bool = false
# var right_checked: bool = false

var jump_triggered: bool = false
var state_active: bool = true

func enter(_previous_state_path: String, _data := {}) -> void:
	print("----------------------------ENTERED CLIMB---------------------------------")
	state_active = true
	jump_triggered = false
	enemy.set_state_label("CLIMB")
	smart_platform = get_target()
	selected_edge = edge_options.pick_random()
	if not smart_platform: # If can't find a smart platform between them, lose aggro and start patrolling
		print("COULD NOT FIND A SMART PLATFORM")
		tranisition.emit("enemyhandstatepatrol") 
		state_active = false
		return
	
	var edge_position: Vector3 = smart_platform.edges[selected_edge].global_transform.origin
	direction_to_edge = enemy.get_z_direction(edge_position)

func exit() -> void:
	print("+++-------------------------EXITED CLIMB------------------------------+++")
	smart_platform = null
	jump_triggered = false
	state_active = false

func physics_update(delta: float) -> void:
	if state_active:
		if smart_platform and not jump_triggered:
			reposition(delta)
			if can_jump():
				jump_triggered = true
				print("!CLIMB CAN JUMP!")
				tranisition.emit("enemyhandstatejumpwindup", {"target": smart_platform.edges[selected_edge]})
				return

func get_target() -> SmartPlatform:
	enemy.raycast_sight.target_position = enemy.raycast_sight.to_local(enemy.get_x_locked_position(enemy.player.global_transform.origin))
	enemy.raycast_sight.force_raycast_update()
	if enemy.raycast_sight.is_colliding():
		var collision_object: Object = enemy.raycast_sight.get_collider()
		if collision_object is SmartPlatform:
			return collision_object
	return null

func reposition(delta: float) -> void:
	print("Repositioning")
	enemy.move_and_fall(delta, enemy.chase_speed, direction_to_edge, enemy.acceleration)
	if enemy.is_wall_ahead() or not enemy.is_floor_ahead():
		if not initial_direction_checked:
			print("CLIMB REPOSITION HIT OBSTACLE, SWITCHING!")
			initial_direction_checked = true
			direction_to_edge *= -1
			if selected_edge == SmartPlatform.Edge.LEFT:
				selected_edge = SmartPlatform.Edge.RIGHT
			else:
				selected_edge = SmartPlatform.Edge.LEFT
			enemy.rotate_on_y(direction_to_edge)
		else:
			state_active = false
			print("CLIMB HIT OBSTACLE IN EACH DIRECTION: GIVING UP!")
			tranisition.emit("enemyhandstatepatrol")

func can_jump() -> bool:	
	if enemy.raycast_ceiling.is_colliding() or not smart_platform:
		return false
	
	var distance_to_selected_edge = enemy.global_transform.origin.distance_to(smart_platform.edges[selected_edge].global_transform.origin)
	
	if distance_to_selected_edge > 8 and distance_to_selected_edge < 16:
		print("IN RANGE TO JUMP CLIMB")
		return true

	return false

func get_selected_edge(_smart_platform: SmartPlatform, _selected_edge: SmartPlatform.Edge) -> Node3D:
	if _selected_edge == SmartPlatform.Edge.LEFT:
		return _smart_platform.left_edge
	else:
		return _smart_platform.right_edge
