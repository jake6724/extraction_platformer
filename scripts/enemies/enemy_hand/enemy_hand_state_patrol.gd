class_name EnemyHandStatePatrol extends StateEnemy

var _current_patrol_direction: Vector3 = Vector3(0,0,1)

var can_detect_player: bool = false

func initialize(_owner: Enemy) -> void:
	super(_owner)
	enemy.area_detect_player.body_entered.connect(on_area_detect_player_body_entered)
	enemy.area_detect_player.body_exited.connect(on_area_detect_player_body_exited)

func enter(_previous_state_path: String, _data := {}) -> void:
	enemy.rotate_on_y(_current_patrol_direction)
	can_detect_player = true
	enemy.set_state_label("PATROL")
	enemy.skin.run()

func exit() -> void:
	can_detect_player = false

func physics_update(delta: float) -> void:
	patrol(delta)

func patrol(delta: float) -> void:
	if not enemy.is_on_floor():
		enemy.move_and_fall(delta, enemy.patrol_speed, _current_patrol_direction, enemy.acceleration)
		return 

	# Patrol in a direction until a wall found or end of platform reached
	if enemy.is_floor_ahead() and not enemy.is_wall_ahead():
		enemy.move_and_fall(delta, enemy.patrol_speed, _current_patrol_direction, enemy.acceleration)
	# Turn around
	else:
		_current_patrol_direction *= -1
		enemy.rotate_on_y(_current_patrol_direction)
		return

func on_area_detect_player_body_entered(_player: Player) -> void:
	if can_detect_player:
		enemy.player = _player
		tranisition.emit("enemyhandstatechase")

func on_area_detect_player_body_exited(_player: Player) -> void:
	if can_detect_player:
		print("XXXXXXXXXXXXXXXXXJumping because of area exitXXXXXXXXXXXXXXXXXXXXXXXXXXXX")
		tranisition.emit("enemyhandstatejumpwindup", {"target": _player})
