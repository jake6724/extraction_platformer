# Singleton
extends Node

var spawners: Dictionary[PackedScene, Dictionary] = {}

func add_spawer(_spawner: Spawner) -> void:
	if spawners.has(_spawner.enemy_scene):
		if spawners[_spawner.enemy_scene].has(_spawner.spawn_group):
			spawners[_spawner.enemy_scene][_spawner.spawn_group].append(_spawner)
		else:
			spawners[_spawner.enemy_scene][_spawner.spawn_group] = []
			spawners[_spawner.enemy_scene][_spawner.spawn_group].append(_spawner)
	else:
		spawners[_spawner.enemy_scene] = {}
		spawners[_spawner.enemy_scene][_spawner.spawn_group] = []
		spawners[_spawner.enemy_scene][_spawner.spawn_group].append(_spawner)

func start_spawn(_spawner: Spawner) -> void:
	print("Start spawn")
	var timer: Timer = Timer.new()
	timer.autostart = false
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(on_spawn_timer_timeout.bind(_spawner))
	timer.start(_spawner.spawn_delay)

func on_spawn_timer_timeout(_spawner: Spawner) -> void:
	var selected_spawner: Spawner = get_valid_spawner(_spawner)
	if selected_spawner:
		selected_spawner.spawn_enemy()
	else:
		print("No where to spawn")

func get_valid_spawner(_spawner: Spawner) -> Spawner:
	var selected_spawner: Spawner = null
	var group_list: Array = spawners[_spawner.enemy_scene][_spawner.spawn_group].duplicate()
	while selected_spawner == null and group_list.size() > 0:
		var s: Spawner = group_list.pick_random()
		if not s.active and not s.is_player_in_range():
			selected_spawner = s
		else:
			group_list.erase(s)    

	return selected_spawner
