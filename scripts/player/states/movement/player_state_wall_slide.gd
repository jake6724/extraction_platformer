class_name PlayerStateWallSlide extends PlayerState

func enter(_previous_state_path: String, _data := {}) -> void:
	set_movement_state_label()
	player._skin.wall_slide()

func physics_update(delta: float) -> void:
	var move_direction: Vector3
	if player.can_move: move_direction = player.input_handler.move_direction

	player.move_and_fall(delta, move_direction, player.move_speed_ground)
	player.update_character(delta, move_direction)
	player.move_and_slide()
