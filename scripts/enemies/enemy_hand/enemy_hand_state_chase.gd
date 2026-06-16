class_name EnemyHandStateChase extends StateEnemy

func enter(_previous_state_path: String, _data := {}) -> void:
	enemy.set_state_label("CHASE")
	enemy.skin.run()

func physics_update(delta: float) -> void:
	chase(delta)

func chase(delta: float) -> void:
	# enable_enemy_collisions_1_frame()
	var z_direction_to_player: float = enemy.player.global_transform.origin.z - enemy.global_transform.origin.z
	var _direction_to_player: Vector3 = Vector3(0,0,z_direction_to_player).normalized()

	var x_locked_position: Vector3 = enemy.global_transform.origin
	x_locked_position.x = 0
	var distance_to_player: float = x_locked_position.distance_to(enemy.get_x_locked_position(enemy.player.global_transform.origin))

	# Take a jump if no where left to run
	if not enemy.is_floor_ahead() or enemy.is_wall_ahead():
		enemy.rotate_on_y(-_direction_to_player)
		tranisition.emit("enemyhandstatejumpwindup", {"target": enemy.player})

	# Too close to player, move away
	if distance_to_player < enemy.min_jump_trigger_distance:
		enemy.rotate_on_y(-_direction_to_player)
		enemy.move_and_fall(delta, enemy.escape_speed, -_direction_to_player, enemy.acceleration)
	# Too far from player, move toward
	elif distance_to_player > enemy.max_jump_trigger_distance:
		enemy.rotate_on_y(_direction_to_player)
		enemy.move_and_fall(delta, enemy.chase_speed, _direction_to_player, enemy.acceleration)
	# In jump range
	else:
		tranisition.emit("enemyhandstatejumpwindup", {"target": enemy.player})
