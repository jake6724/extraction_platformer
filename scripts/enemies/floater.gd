class_name EnemyFloater
extends Enemy

@export var area_detect_player: Area3D
@export var area_attack: Area3D
var player: Player
var speed: float = 8.0
var can_move: bool = true
var stop_timer: Timer = Timer.new()
var stop_duration: float = 1.0
var attack_power: float = 30.0

func _ready():
	area_attack.area_entered.connect(on_area_attack_area_entered)
	area_detect_player.body_entered.connect(on_area_detect_player_body_entered)

	stop_timer.one_shot = false
	stop_timer.autostart = true
	add_child(stop_timer)
	stop_timer.timeout.connect(on_stop_timer_timeout)

func _physics_process(delta: float) -> void:
	if player and can_move:
		chase(delta, player)

func patrol(delta) -> void:
	pass

func chase(delta: float, _player: Player ) -> void:
	var _direction: Vector3 = global_position.direction_to(_player.global_position)
	global_position += (_direction * speed) * delta

## Attack
func on_area_attack_area_entered(_player_hurtbox: PlayerHurtbox) -> void: 
	if _player_hurtbox:
		# can_move = false
		stop_timer.start(stop_duration)
		_player_hurtbox.take_damage(global_position, attack_power)

func on_area_detect_player_body_entered(_player: Player) -> void:
	player = _player

func on_stop_timer_timeout() -> void:
	can_move = true
