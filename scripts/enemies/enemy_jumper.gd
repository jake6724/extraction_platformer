class_name EnemyJumper extends Enemy


# TODO: Wind up, then jump. It should be similar to a dash
# TODO: Multiple types of jumps? High or low ? 

var player: Player

@export var jump_timer: Timer
@export var jump_delay_min: float = .25
@export var jump_delay_max: float = 1.0
@export var jump_power_min: float
@export var jump_power_max: float

@export var jump_height_min: float =20
@export var jump_height_max: float = 25
@export var jump_distance_min: float = 15
@export var jump_distance_max: float = 20

@export var area_detect_player: Area3D
@export var area_chase_quit: Area3D

@export var timer_chase_quit: Timer
@export var chase_quit_delay: float = 5.0

var jump_direction: Vector3
var jumping: bool = false

@export var ground_speed: float = 7.0
@export var acceleration: float = 40

enum State {IDLE, PATROL, CHASE, CHARGE, AIR, LAND, HIT}
var current_state: State = State.IDLE

func _ready():
	super()
	jump_timer.timeout.connect(on_jump_timer_timeout)
	area_detect_player.body_entered.connect(on_area_detect_player_body_entered)
	area_detect_player.body_exited.connect(on_area_detect_player_body_exited)
	area_chase_quit.body_exited.connect(on_area_chase_quit_body_exited)
	timer_chase_quit.timeout.connect(on_timer_chase_quit_timeout)

	skin.land_complete.connect(on_skin_land_complete)

	skin.idle()

func _physics_process(delta):
	match current_state:
		State.IDLE: idle(delta)
		State.PATROL: pass
		State.CHASE: chase(delta)
		State.CHARGE: pass
		State.AIR: air(delta)
		State.LAND: land(delta)
		State.HIT: pass

func on_area_detect_player_body_entered(_player: Player) -> void:
	if current_state == State.IDLE or current_state == State.PATROL:
		player = _player
		current_state = State.CHASE
		skin.run()
		var jump_delay: float = randf_range(jump_delay_min, jump_delay_max)
		jump_timer.start(jump_delay)
	timer_chase_quit.stop() # Always cancel chase quitting process if they walk into attack range

## Time to start a jump windup
func on_jump_timer_timeout() -> void:
	current_state = State.CHARGE
	skin.jump()
	flash_mesh_repeat(1.1, 3)
	await get_tree().create_timer(1.1).timeout
	apply_jump()

## Apply jump impulse, transition to air
func apply_jump() -> void:
	var impulse: Vector3 = (get_direction_to_player(player) * 10) + Vector3(0,15,0)
	velocity = impulse
	current_state = State.AIR
	skin.air()

func idle(delta: float) -> void:
	velocity = velocity.move_toward(Vector3.ZERO, delta*acceleration)
	velocity.x = 0
	velocity.y = move_toward(velocity.y, gravity_default, delta * gravity_acceleration)
	move_and_slide()

func air(delta: float) -> void:
	velocity.y = move_toward(velocity.y, gravity_default, delta * gravity_acceleration)
	velocity.x = 0
	move_and_slide()

	if is_on_floor():
		current_state = State.LAND
		skin.land()

func charge(delta: float) -> void:
	pass

func land(delta: float) -> void:
	velocity = velocity.move_toward(Vector3.ZERO, delta*acceleration*10)
	move_and_collide(velocity * delta)

func on_skin_land_complete() -> void:
	current_state = State.CHASE # TODO: Check for target and do idle, patrol, or chase 
	skin.run()

func chase(delta: float) -> void:
	var z_direction_to_player: float = player.global_transform.origin.z - global_transform.origin.z
	var _direction_to_player: Vector3 = Vector3(0,0,z_direction_to_player).normalized()

	velocity = velocity.move_toward(_direction_to_player * ground_speed, delta * acceleration)
	velocity.x = 0
	velocity.y = move_toward(velocity.y, gravity_default, delta * gravity_acceleration)

	face_mesh(_direction_to_player)
	move_and_slide()

func on_area_chase_quit_body_exited(_player: Player) -> void:
	if not timer_chase_quit.time_left > 0:
		timer_chase_quit.start(chase_quit_delay)

func on_timer_chase_quit_timeout() -> void:
	current_state = State.IDLE
	skin.idle()
	player = null

func get_direction_to_player(_player: Player) -> Vector3:
	var z_direction_to_player: float = _player.global_transform.origin.z - global_transform.origin.z
	var _direction_to_player: Vector3 = Vector3(0,0,z_direction_to_player).normalized()
	print(_direction_to_player)
	return _direction_to_player

func can_attack() -> bool:
	if area_detect_player.get_overlapping_bodies().size() > 0:
		return true
	else:
		return false

func on_area_detect_player_body_exited(_player: Player) -> void:
	pass
