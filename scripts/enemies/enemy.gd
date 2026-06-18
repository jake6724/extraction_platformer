class_name Enemy
extends CharacterBody3D

# @export var mesh: MeshInstance3D
@export var area_attack: Area3D
var attack_power: float = 15.0
var base_color: Color
@export var gravity_default: float = -30
# @export var gravity_acceleration: float = 45.0
@export var gravity_acceleration: float = 30
@export var skin: EnemySkin
@export var health: int = 3
@export var timer_hitstun: Timer
@export var acceleration: float = 40
@export var body_collider: CollisionShape3D

func _ready():
	# base_color = mesh.get_active_material(0).albedo_color
	area_attack.area_entered.connect(on_area_attack_area_entered)
	timer_hitstun.timeout.connect(stop_hitstun)

func _physics_process(delta):
	velocity = velocity.move_toward(Vector3.ZERO, delta * 30)
	velocity.x = 0
	move_and_slide()

## Wrapper for basic movement. Adds gravity and calls `move_and_slide()`
func move_and_fall(delta: float, _move_speed: float, _move_direction: Vector3, _acceleration: float) -> void:
	var velocity_y = velocity.y
	velocity = velocity.move_toward(_move_direction * _move_speed, delta * _acceleration)
	velocity.y = move_toward(velocity_y, gravity_default, delta * gravity_acceleration)
	velocity.x = 0
	move_and_slide()

## Similar to move and fall, but only adds gravity and does not affect movement on Z-axis. Uses 
## gravity_acceleration internally
func fall(delta: float) -> void:
	velocity.y = move_toward(velocity.y, gravity_default, delta * gravity_acceleration)
	velocity.x = 0
	move_and_slide()

## Attack
func on_area_attack_area_entered(_player_hurtbox: PlayerHurtbox) -> void: 
	if _player_hurtbox:
		_player_hurtbox.take_damage(global_position, attack_power)

func take_damage(_direction: Vector3, _power: float, _damage: int, _hitstun_duration: float) -> void:
	velocity = _direction * _power
	flash_mesh()
	health -= _damage
	if health <= 0:
		die()
	else:
		start_hitstun(_hitstun_duration)

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

func set_collisions_with_enemies(_value: bool) -> void:
	set_collision_mask_value.call_deferred(2, _value)

func enable_enemy_collisions_1_frame() -> void:
	set_collision_mask_value(2, true)
	await get_tree().process_frame
	set_collision_mask_value(2, false)