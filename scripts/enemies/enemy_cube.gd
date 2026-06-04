class_name EnemyCube extends Enemy

@export var raycast_floor: RayCast3D
@export var raycast_wall: RayCast3D
var _current_patrol_direction: Vector3 = Vector3(0,0,1)
@export var patrol_speed: float = 4.0

enum State {IDLE, PATROL, CHASE, CHARGE, AIR, LAND, HIT}
var current_state: State = State.PATROL
var player: Player

func _physics_process(delta):
	#print_state()
	match current_state:
		# State.IDLE: idle(delta)
		State.PATROL: patrol(delta)
		# State.CHASE: chase(delta)
		# State.AIR: air(delta)
		# State.LAND: land(delta)
		# State.HIT: pass

func patrol(delta: float) -> void:
	# Patrol in a direction until a wall found or end of platform reached
	if is_floor_ahead() and not is_wall_ahead():
		move_and_fall(delta, patrol_speed, _current_patrol_direction, acceleration)
	# Turn around
	else:
		_current_patrol_direction *= -1
		rotate_on_y(_current_patrol_direction)
		return

func is_floor_ahead() -> bool:
	return raycast_floor.is_colliding()

func is_wall_ahead() -> bool:
	return raycast_wall.is_colliding()