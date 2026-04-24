class_name TestLevel
extends Node3D

@export var player: Player
@export var left_boundary: Marker3D
@export var right_boundary: Marker3D

func _ready():
	player.camera.set_limits(left_boundary.global_position, right_boundary.global_position)