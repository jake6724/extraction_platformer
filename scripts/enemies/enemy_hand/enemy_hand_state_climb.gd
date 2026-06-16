class_name EnemyHandStateClimb extends StateEnemy

func enter(_previous_state_path: String, _data := {}) -> void:
    enemy.set_state_label("CLIMB")