class_name Bullet
extends CharacterBody3D

@export var mesh: MeshInstance3D
@export var collider: CollisionShape3D
@export var trail_particles: GPUParticles3D
@export var explode_particles: GPUParticles3D

var power # Set in launch()
var collision_count: int = 0
var collision_max: int = 2

func launch(_direction: Vector3, _power: float) -> void:
	velocity = _direction * _power
	look_at(velocity, Vector3.UP, false)
	power = _power

func _physics_process(delta):
	var collision: KinematicCollision3D = move_and_collide(velocity * delta)
	if collision:
		collision_count += 1
		if collision_count >= collision_max:
			explode()
		velocity = velocity.bounce(collision.get_normal())

func explode() -> void:
	mesh.hide()
	trail_particles.hide()
	collider.set_deferred("disabled", true)

	explode_particles.restart()
	explode_particles.finished.connect(die)

func die() -> void:
	queue_free()
