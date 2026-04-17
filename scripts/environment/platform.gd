class_name Platform
extends StaticBody3D

@export var player: Player
@export var collider: CollisionShape3D
@export var area_body_detect: Area3D

# TODO: Optimize by creating a parent manager class which does this for each platform manually
# TODO: Optimize by only calling this function when play moves, not physics tick

func _physics_process(_delta):
	if player.global_position.y >= global_position.y:
		var bodies: Array = area_body_detect.get_overlapping_bodies() # Don't turn on collider if player is still inside the platform
		if bodies.size() == 0:
			collider.set_deferred("disabled", false)
	else:
		collider.set_deferred("disabled", true)