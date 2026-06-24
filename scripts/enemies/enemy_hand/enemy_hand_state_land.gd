class_name EnemyHandStateLand extends StateEnemy

func initialize(_owner: Enemy) -> void:
	super(owner)
	enemy.skin.land_complete.connect(on_enemy_skin_land_complete)

func enter(_previous_state_path: String, _data := {}) -> void:
	enemy.set_state_label("LAND")
	enemy.skin.land()

func physics_update(delta: float) -> void:
	enemy.move_and_fall(delta, 0, Vector3.ZERO, enemy.acceleration*1.5)

func on_enemy_skin_land_complete() -> void:
	tranisition.emit("enemyhandstatechase")