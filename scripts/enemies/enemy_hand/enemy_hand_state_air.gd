class_name EnemyHandStateAir extends StateEnemy

var _is_on_terrain_enable_delay: float = 0.2

func enter(_previous_state_path: String, _data := {}) -> void:
	enemy.set_state_label("AIR")
	await get_tree().create_timer(_is_on_terrain_enable_delay).timeout
	enemy.raycast_floor.enabled = true

func exit() -> void:
	enemy.raycast_floor.enabled = false

func physics_update(delta: float) -> void:
	enemy.fall(delta)

	if enemy.is_on_terrain():
		enemy.raycast_floor.enabled = false
		enemy.clear_debug_trajectory_points()
		tranisition.emit("enemyhandstateland")
