class_name SpawnerFlying extends Spawner

@export var start_left_to_right: bool
# @export var spawn_timer: Timer

@onready var path: Path3D = $"Path3D"
@onready var path_follow: PathFollow3D = $"Path3D/PathFollow3D"

func _ready() -> void:
	indicator.hide()
	if is_initial_spawn:
		spawn_enemy()
	EnemySpawnManager.add_spawer(self)

func on_spawned_enemy_died(_enemy: Enemy) -> void:
	print("Spawned enemy died!")
	active = false
	_enemy.queue_free()
	EnemySpawnManager.start_spawn(self)

func spawn_enemy() -> void:
	active = true
	var new_enemy: Enemy = enemy_scene.instantiate()

	# Configure path follow progress
	if start_left_to_right:
		path_follow.progress_ratio = 0.99
		new_enemy.patrol_speed_scale *= -1
	else:
		path_follow.progress_ratio = 0.01

	path_follow.add_child(new_enemy)
	# new_enemy.global_transform.origin = global_transform.origin
	new_enemy.configure_spawn(path_follow)
	new_enemy.died.connect(on_spawned_enemy_died)
