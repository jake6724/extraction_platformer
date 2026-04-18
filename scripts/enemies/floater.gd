class_name EnemyFloater
extends Enemy

@export var area_detect_player: Area3D
@export var area_attack: Area3D

var player: Player
## Move speed when chasing the player
@export var chase_speed: float = 8.0
## Move speed when patrolling
@export var patrol_speed: float = 3.0
var can_move: bool = true
var stop_timer: Timer = Timer.new()
@export var chase_timer: Timer

## How long to stop after hitting the player. 0 is allowed, enemy will not stop after hitting
@export_range(0,2,.1) var stop_duration: float = 1.0
var attack_power: float = 30.0

var start_point: Vector3
var end_point: Vector3
var target_point: Vector3
var target_direction: Vector3
## Distance from starting point that enemy will patrol along the z-axis. Positive values will patrol to the left first, negative to the right
@export var patrol_range: float = 20.0
@export var patrol_raycast: RayCast3D

func _ready():
	area_attack.area_entered.connect(on_area_attack_area_entered)
	area_detect_player.body_entered.connect(on_area_detect_player_body_entered)

	stop_timer.one_shot = false
	stop_timer.autostart = true
	add_child(stop_timer)
	stop_timer.timeout.connect(on_stop_timer_timeout)

	start_point = global_position
	end_point = start_point + Vector3(0,0,patrol_range)
	target_point = end_point
	target_direction = start_point.direction_to(end_point)

	# Check that end-point is accessible, limit range if not
	await get_tree().process_frame
	patrol_raycast.target_position = to_local(end_point)
	patrol_raycast.force_raycast_update()
	if patrol_raycast.is_colliding():
		end_point = patrol_raycast.get_collision_point()
		end_point.z -= (patrol_range * .1)
		end_point.z = snappedf(end_point.z,1)
		target_point = end_point

func _physics_process(delta: float) -> void:
	if can_move:
		if player:
			chase(delta, player)
		else:
			patrol(delta)

func patrol(delta) -> void:
	global_position += (target_direction * patrol_speed) * delta
	if global_position.is_equal_approx(target_point):
		if target_point == end_point:
			target_point = start_point
			target_direction = end_point.direction_to(start_point)
		else:
			target_point = end_point
			target_direction = start_point.direction_to(end_point)

func chase(delta: float, _player: Player ) -> void:
	var _direction: Vector3 = global_position.direction_to(_player.global_position)
	global_position += (_direction * chase_speed) * delta

## Attack
func on_area_attack_area_entered(_player_hurtbox: PlayerHurtbox) -> void: 
	if _player_hurtbox:
		_player_hurtbox.take_damage(global_position, attack_power)
		if stop_duration > 0:
			can_move = false
			stop_timer.start(stop_duration)

func on_area_detect_player_body_entered(_player: Player) -> void:
	player = _player

func on_stop_timer_timeout() -> void:
	can_move = true