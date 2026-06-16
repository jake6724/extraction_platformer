class_name EnemySkin extends Node3D

@export var mesh: MeshInstance3D
@export var mesh_parent: Node3D
@export var animation_player: AnimationPlayer

## Flip mesh parent along Z-axis
func flip_horizontal(_flip: bool) -> void:
	var target_angle: float
	if _flip:
		target_angle = Vector3.BACK.signed_angle_to(Vector3(0,0,-1), Vector3.UP)
	else:
		target_angle = Vector3.BACK.signed_angle_to(Vector3(0,0,1), Vector3.UP)
	mesh_parent.global_rotation.y = target_angle

## Mirror mesh on X axis
func mirror_mesh(_flip) -> void:
	if _flip:
		mesh_parent.scale = Vector3(-1,1,1)
	else:
		mesh_parent.scale = Vector3(1,1,1)
