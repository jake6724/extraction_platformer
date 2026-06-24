class_name SpawnerCube extends Spawner

var _initial_patrol_direction: Vector3

func _ready() -> void:
	match direction_mode:
		DirectionMode.START_RIGHT: _initial_patrol_direction = Vector3(0,0,-1)
		DirectionMode.START_LEFT: _initial_patrol_direction = Vector3(0,0,1)
		DirectionMode.RANDOM_START: _initial_patrol_direction = Vector3(0,0,[1,-1].pick_random())
		DirectionMode.RANDOM_ALWAYS: _initial_patrol_direction = Vector3(0,0,[1,-1].pick_random())
	super()

func spawn_enemy() -> void:
	active = true
	var new_enemy: Enemy = enemy_scene.instantiate()
	add_child(new_enemy)
	
	if direction_mode == DirectionMode.RANDOM_ALWAYS:
		_initial_patrol_direction = Vector3(0,0,[1,-1].pick_random())

	new_enemy.configure_spawn(_initial_patrol_direction)
	new_enemy.died.connect(on_spawned_enemy_died)
	new_enemy.global_transform.origin = global_transform.origin

func on_spawned_enemy_died(_enemy: Enemy) -> void:
	super(_enemy)