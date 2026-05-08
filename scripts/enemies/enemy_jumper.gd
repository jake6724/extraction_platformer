class_name EnemyJumper extends Enemy

@export var jump_timer: Timer
@export var jump_delay_min: float = .25
@export var jump_delay_max: float = 1
@export var jump_power_min: float
@export var jump_power_max: float

@export var jump_height_min: float =20
@export var jump_height_max: float = 25
@export var jump_distance_min: float = 15
@export var jump_distance_max: float = 20

@export var area_detect_player: Area3D
# var player: Player
var jump_direction: Vector3
var jumping: bool = false

func _ready():
	super()
	jump_timer.timeout.connect(on_jump_timer_timeout)
	area_detect_player.body_entered.connect(on_area_detect_player_body_entered)
	area_detect_player.body_exited.connect(on_area_detect_player_body_exited)

func _physics_process(delta):
	velocity = velocity.move_toward(Vector3.ZERO, delta*15)
	velocity.x = 0
	velocity.y = move_toward(velocity.y, gravity_default, delta*45)

	if is_on_floor():
		jumping = false
	else:
		jumping = true

	move_and_slide()

func jump() -> void:
	# var _direction = global_transform.origin.direction_to(player.global_transform.origin)
	var impulse: Vector3 = (jump_direction * (randf_range(jump_distance_min, jump_distance_max))) + Vector3(0,randf_range(jump_height_min, jump_height_max), 0)
	velocity = impulse

func on_area_detect_player_body_entered(_player: Player) -> void:
	# player = _player
	if not jumping:
		jump_direction = global_transform.origin.direction_to(_player.global_transform.origin)
		jump_timer.start(randf_range(jump_delay_min, jump_delay_max))

func on_area_detect_player_body_exited(_player: Player) -> void:
	pass
	# player = null
	# jump_timer.stop()

func on_jump_timer_timeout() -> void:
	jump()
	await get_tree().create_timer(3).timeout
	jump_timer.start(randf_range(jump_delay_min, jump_delay_max))
