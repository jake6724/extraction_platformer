class_name EnemyHandStateClimb extends StateEnemy

var smart_platform: SmartPlatform = null
var selected_edge: SmartPlatform.Edge = SmartPlatform.Edge.LEFT
var edge_options: Array[SmartPlatform.Edge] = [SmartPlatform.Edge.LEFT, SmartPlatform.Edge.RIGHT]
var direction_to_edge: Vector3

var left_checked: bool = false
var right_checked: bool = false

var jump_triggered: bool = false

func enter(_previous_state_path: String, _data := {}) -> void:
	enemy.set_state_label("CLIMB")
	smart_platform = get_target()
	selected_edge = edge_options.pick_random()
	if not smart_platform: # If can't find a smart platform between them, lose aggro and start patrolling
		tranisition.emit("enemyhandstatepatrol") 
		print("COULD NOT FIND A SMART PLATFORM")
		return
	
	var edge_position: Vector3 = smart_platform.edges[selected_edge].global_transform.origin
	direction_to_edge = enemy.get_z_direction(edge_position)
	#print(direction_to_edge)

func exit() -> void:
	smart_platform = null
	jump_triggered = false

func physics_update(delta: float) -> void:
	if smart_platform and not jump_triggered:
		reposition(delta)
		if can_jump():
			jump_triggered = true
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
	#print("Repositioning")
	enemy.move_and_fall(delta, enemy.chase_speed, direction_to_edge, enemy.acceleration)

func can_jump() -> bool:	
	if enemy.raycast_ceiling.is_colliding():
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

# func climb_jump() -> void:
# 	var target = smart_platform.edges[selected_edge]
# 	var z_direction_to_target: Vector3 = enemy.get_z_direction(target.global_transform.origin)
# 	enemy.rotate_on_y(z_direction_to_target)

# 	var jump_data_1 = enemy.get_jump_data(target)
# 	modify_jump_data_by_status(jump_data_1)
# 	if continue_jump_windup: # No else for this; the match in modify_jump_data_by_status will handle calling transition
# 		enemy.skin.jump_windup()
