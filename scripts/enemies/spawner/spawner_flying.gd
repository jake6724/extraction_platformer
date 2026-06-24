class_name SpawnerFlying extends Spawner

@onready var path: Path3D = $"Path3D"
@onready var path_follow: PathFollow3D = $"Path3D/PathFollow3D"

var start_right_to_left: bool

func _ready() -> void:
	match direction_mode:
		DirectionMode.START_RIGHT: start_right_to_left = true
		DirectionMode.START_LEFT: start_right_to_left = false
		DirectionMode.RANDOM_START: start_right_to_left = randf() > 0.5
		DirectionMode.RANDOM_ALWAYS: start_right_to_left = randf() > 0.5
	super()

func on_spawned_enemy_died(_enemy: Enemy) -> void:
	active = false
	_enemy.queue_free()
	EnemySpawnManager.start_spawn(self)

func spawn_enemy() -> void:
	active = true
	var new_enemy: Enemy = enemy_scene.instantiate()

	if direction_mode == DirectionMode.RANDOM_ALWAYS:
		start_right_to_left = randf() > 0.5

	# Configure path follow progress
	if start_right_to_left:
		path_follow.progress_ratio = 0.99
		new_enemy.patrol_speed_scale *= -1
	else:
		path_follow.progress_ratio = 0.01

	path_follow.add_child(new_enemy)
	# new_enemy.global_transform.origin = global_transform.origin
	new_enemy.configure_spawn(path_follow)
	new_enemy.died.connect(on_spawned_enemy_died)
