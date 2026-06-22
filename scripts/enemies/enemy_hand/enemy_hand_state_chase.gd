class_name EnemyHandStateChase extends StateEnemy

var can_trigger_jump: bool = true
var timer_trigger_jump_delay = Timer.new()

var timer_quit_chase: Timer = Timer.new()

func _ready():
	timer_trigger_jump_delay.one_shot = true
	timer_trigger_jump_delay.autostart = false
	add_child(timer_trigger_jump_delay)
	timer_trigger_jump_delay.timeout.connect(on_timer_trigger_jump_delay_timeout)
	
	timer_quit_chase.one_shot = true
	timer_quit_chase.autostart = false
	add_child(timer_quit_chase)
	timer_quit_chase.timeout.connect(on_timer_quit_chase_timeout)

func enter(_previous_state_path: String, _data := {}) -> void:
	var z_direction_to_player: float = enemy.player.global_transform.origin.z - enemy.global_transform.origin.z
	enemy.rotate_on_y(Vector3(0,0,z_direction_to_player))
	if _data.has("trigger_jump_delay"):
		can_trigger_jump = false
		timer_trigger_jump_delay.start(_data["trigger_jump_delay"])
	enemy.set_state_label("CHASE")
	enemy.skin.run()

func exit() -> void:
	timer_trigger_jump_delay.stop()
	timer_quit_chase.stop()

func on_timer_trigger_jump_delay_timeout() -> void:
	can_trigger_jump = true

func on_timer_quit_chase_timeout() -> void:
	print("QUIT TIMER TRIGGERED")
	tranisition.emit("enemyhandstatepatrol")

func physics_update(delta: float) -> void:
	chase(delta)

func chase(delta: float) -> void:
	# enable_enemy_collisions_1_frame()
	var z_direction_to_player: float = enemy.player.global_transform.origin.z - enemy.global_transform.origin.z
	var _direction_to_player: Vector3 = Vector3(0,0,z_direction_to_player).normalized()

	var x_locked_position: Vector3 = enemy.global_transform.origin
	x_locked_position.x = 0
	var distance_to_player: float = x_locked_position.distance_to(enemy.get_x_locked_position(enemy.player.global_transform.origin))

	var height_difference: float = abs(enemy.player.global_transform.origin.y - enemy.global_transform.origin.y)

	if timer_quit_chase.is_stopped() and height_difference > enemy._max_jump_height:
		print("Start quitting")
		timer_quit_chase.start(enemy.quit_delay)
		return

	if height_difference <= enemy._max_jump_height:
		timer_quit_chase.stop()
	
	# Take a jump if no where left to run
	if not enemy.is_floor_ahead() or enemy.is_wall_ahead():
		enemy.rotate_on_y(-_direction_to_player)
		print("JUMPED CAUSE I GOT NO WHERE ELSE TO BE")
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
		print("JUMP IN CHASE RANGE")
		# if can_trigger_jump:
		tranisition.emit("enemyhandstatejumpwindup", {"target": enemy.player})
