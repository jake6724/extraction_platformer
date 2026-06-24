class_name Spawner extends Node3D

@export var is_initial_spawn: bool = false
@export var spawn_group: int = 0
@export_range(0.5,10,.5) var spawn_delay: float = 1.0
@export var enemy_scene: PackedScene
@export var indicator: MeshInstance3D
var active: bool

func on_spawned_enemy_died(_enemy: Enemy) -> void:
	pass

func spawn_enemy() -> void:
	pass

func is_player_in_range() -> bool:
	var res: bool = false
	return res