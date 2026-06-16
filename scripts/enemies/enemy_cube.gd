class_name EnemyCube extends Enemy

# @export var raycast_floor: RayCast3D
# @export var raycast_wall: RayCast3D
# @export var raycast_wall_dash: RayCast3D
# var _current_patrol_direction: Vector3 = Vector3(0,0,1)
# @export var patrol_speed: float = 3.0
# @export var dash_speed: float = 15.0
# @export var area_detect_player: Area3D
# @export var hop_back_horizontal_power: float = 3.0
# @export var hop_back_vertical_power: float = 3.0
# @export var dash_reset_idle_duration: float = 1.0 # How long after dashing to idle
# @export var timer_dash_reset: Timer

# var _post_air_state: EnemyState

# enum EnemyState {IDLE, PATROL, HOP, DASH, CHARGE, AIR, LAND, HIT}
# var current_state: EnemyState = EnemyState.PATROL
# var player: Player

@export var raycast_floor_ahead: RayCast3D
@export var raycast_wall: RayCast3D

@export var patrol_speed: float = 3.0
var _current_patrol_direction: Vector3 = Vector3(0,0,1)

func _ready():
	skin.animation_player.speed_scale = 1.4
	skin.run()

func _physics_process(delta):
	patrol(delta)

func patrol(delta: float) -> void:
	# Patrol in a direction until a wall found or end of platform reached
	if is_floor_ahead() and not is_wall_ahead():
		move_and_fall(delta, patrol_speed, _current_patrol_direction, acceleration)
		face_all(_current_patrol_direction)
	# Turn around
	else:
		_current_patrol_direction *= -1
		face_all(_current_patrol_direction)
		return

func is_floor_ahead() -> bool:
	return raycast_floor_ahead.is_colliding()

func is_wall_ahead() -> bool:
	return raycast_wall.is_colliding()

# func _ready():
# 	area_detect_player.body_entered.connect(on_player_detected)
# 	timer_dash_reset.timeout.connect(on_timer_dash_reset_timeout)

# func _physics_process(delta):
# 	#print_state()
# 	match current_state:
# 		EnemyState.IDLE: idle(delta)
# 		EnemyState.PATROL: patrol(delta)
# 		EnemyState.DASH: dash(delta)
# 		EnemyState.AIR: air(delta)
# 		# EnemyState.HIT: pass

# func idle(delta: float) -> void:
# 	velocity = velocity.move_toward(Vector3.ZERO, delta*acceleration)
# 	velocity.x = 0
# 	velocity.y = move_toward(velocity.y, gravity_default, delta * gravity_acceleration)
# 	move_and_slide()

# func patrol(delta: float) -> void:
# 	# Patrol in a direction until a wall found or end of platform reached
# 	if is_floor_ahead() and not is_wall_ahead():
# 		move_and_fall(delta, patrol_speed, _current_patrol_direction, acceleration)
# 	# Turn around
# 	else:
# 		_current_patrol_direction *= -1
# 		rotate_on_y(_current_patrol_direction)
# 		return

# func air(delta: float) -> void:
# 	velocity.y = move_toward(velocity.y, gravity_default, delta * gravity_acceleration)
# 	velocity.x = 0
# 	move_and_slide()
# 	if is_on_floor():
# 		current_state = _post_air_state

# func hop_back() -> void:
# 	var impulse: Vector3 = -_current_patrol_direction * hop_back_horizontal_power + Vector3(0,hop_back_vertical_power,0)
# 	velocity = impulse
# 	current_state = EnemyState.AIR

# func dash(delta: float) -> void:
# 	move_and_fall(delta, dash_speed, _current_patrol_direction, acceleration)
# 	if raycast_wall_dash.is_colliding():
# 		timer_dash_reset.start(dash_reset_idle_duration)
# 		_post_air_state = EnemyState.IDLE
# 		hop_back()
# 	elif not raycast_floor.is_colliding():
# 		timer_dash_reset.start(dash_reset_idle_duration)
# 		current_state = EnemyState.IDLE

# func on_timer_dash_reset_timeout() -> void:
# 	current_state = EnemyState.PATROL

# func on_player_detected(_player: Player) -> void:
# 	if current_state == EnemyState.PATROL:
# 		_post_air_state = EnemyState.DASH
# 		hop_back()

# func check_player_in_range() -> void:
# 	pass

# func is_floor_ahead() -> bool:
# 	return raycast_floor.is_colliding()

# func is_wall_ahead() -> bool:
# 	return raycast_wall.is_colliding()
