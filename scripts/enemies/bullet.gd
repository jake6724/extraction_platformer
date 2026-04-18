class_name Bullet
extends CharacterBody3D

@export var mesh: MeshInstance3D
@export var collider: CollisionShape3D
@export var area_player_detect: Area3D
@export var collider_player_detect: CollisionShape3D
@export var trail_particles: GPUParticles3D
@export var explode_particles: GPUParticles3D

var move_power
var attack_power
var collision_count: int = 0
var collision_max: int = 2

func _ready():
	area_player_detect.area_entered.connect(on_area_player_detect_area_entered)

func launch(_direction: Vector3, _move_power: float, _attack_power: float) -> void:
	move_power = _move_power
	attack_power = _attack_power
	velocity = _direction * move_power
	look_at(velocity, Vector3.UP, false)

func _physics_process(delta):
	var collision: KinematicCollision3D = move_and_collide(velocity * delta)
	if collision:
		collision_count += 1
		if collision_count >= collision_max:
			explode()
		velocity = velocity.bounce(collision.get_normal())

func on_area_player_detect_area_entered(player_hurtbox: PlayerHurtbox) -> void:
	player_hurtbox.take_damage(global_position, attack_power)

func explode() -> void:
	mesh.hide()
	trail_particles.hide()
	collider.set_deferred("disabled", true)
	collider_player_detect.set_deferred("disabled", true)

	explode_particles.restart()
	explode_particles.finished.connect(die)

func die() -> void:
	queue_free()
