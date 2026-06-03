class_name Enemy
extends CharacterBody3D

@export var mesh: MeshInstance3D
@export var area_attack: Area3D
var attack_power: float = 15.0
var base_color: Color
@export var gravity_default: float = -30
# @export var gravity_acceleration: float = 45.0
@export var gravity_acceleration: float = 30
@export var skin: EnemySkin
@export var health: int = 3
@export var timer_hitstun: Timer

func _ready():
	base_color = mesh.get_active_material(0).albedo_color
	area_attack.area_entered.connect(on_area_attack_area_entered)
	timer_hitstun.timeout.connect(stop_hitstun)

func _physics_process(delta):
	velocity = velocity.move_toward(Vector3.ZERO, delta * 30)
	velocity.x = 0
	move_and_slide()

## Attack
func on_area_attack_area_entered(_player_hurtbox: PlayerHurtbox) -> void: 
	if _player_hurtbox:
		_player_hurtbox.take_damage(global_position, attack_power)
		
func take_damage_old(_direction, _power, _damage) -> void:
	velocity = _direction * _power
	flash_mesh_color()

func take_damage(_direction: Vector3, _power: float, _damage: int, _hitstun_duration: float) -> void:
	velocity = _direction * _power
	flash_mesh()
	health -= _damage
	if health <= 0:
		die()
	else:
		start_hitstun(_hitstun_duration)

func flash_mesh_color() -> void:
	var flash_tween: Tween = get_tree().create_tween()
	var mesh_material: StandardMaterial3D = mesh.get_active_material(0)
	flash_tween.tween_property(mesh_material, "albedo_color", base_color, .25).from(Color.YELLOW)

func die() -> void:
	queue_free()

## Flash skin mesh using shader
func flash_mesh() -> void:
	# Get the base material (shared)
	var base_mat: Material = skin.mesh.get_active_material(0)
	# Get the next-pass flash material
	var flash_mat: ShaderMaterial = base_mat.next_pass
	# Flash with tween
	var flash_tween: Tween = get_tree().create_tween()
	flash_tween.tween_property(flash_mat, "shader_parameter/flash", 0.0, .1).from(3.0)

func flash_mesh_repeat(_total_duration: float, flash_amount: int, flash_color: Color = Color.WHITE) -> void:
	var interval: float = (_total_duration / flash_amount) / 2
	var flash_tween: Tween = get_tree().create_tween()

	var base_mat: Material = skin.mesh.get_active_material(0)
	var flash_mat: ShaderMaterial = base_mat.next_pass
	flash_mat.set_shader_parameter("custom_color", flash_color)

	flash_tween.set_loops(flash_amount)
	flash_tween.tween_property(flash_mat, "shader_parameter/flash", 3.0, 0.0)
	flash_tween.tween_interval(interval)
	flash_tween.tween_property(flash_mat, "shader_parameter/flash", 0.0, 0.0)
	flash_tween.tween_interval(interval)

func face_mesh(_move_direction: Vector3) -> void:
	var flip: bool = _move_direction.z > 0
	skin.flip_horizontal(flip)
	skin.mirror_mesh(flip)

func rotate_on_y(_direction: Vector3) -> void:
	var target_angle: float = Vector3.BACK.signed_angle_to(_direction, Vector3.UP)
	global_rotation.y = target_angle

func face_all(_direction: Vector3) -> void:
	face_mesh(_direction)
	rotate_on_y(_direction)
	
func start_hitstun(_hitstun_duration: float) -> void:
	timer_hitstun.start(_hitstun_duration)
	flash_mesh_repeat(_hitstun_duration, 5)
	area_attack.monitoring = false

func stop_hitstun() -> void:
	area_attack.monitoring = true
