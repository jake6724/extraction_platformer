class_name Spawner extends Node3D

@export var spawn_on_start: bool = false
@export var direction_mode: DirectionMode
@export var spawn_group: int = 0
@export_range(0.5,10,.5) var spawn_delay: float = 5.0
@export var enemy_scene: PackedScene
@export var indicator: MeshInstance3D
var active: bool

enum DirectionMode {
	## Start patrol moving left to right.
	START_LEFT,
	## Start patrol moving right to left
	START_RIGHT, 
	## Randomly select patrol direction; continue to use this option for all future spawns.
	RANDOM_START,
	## Randomly select patrol direction; re-select this direction for all future spawns.
	RANDOM_ALWAYS
}

func _ready() -> void:
	indicator.hide()
	if spawn_on_start:
		spawn_enemy()
	EnemySpawnManager.add_spawer(self)

func on_spawned_enemy_died(_enemy: Enemy) -> void:
	active = false
	_enemy.queue_free()
	EnemySpawnManager.start_spawn(self)

func spawn_enemy() -> void:
	pass

func is_player_in_range() -> bool:
	var res: bool = false
	return res