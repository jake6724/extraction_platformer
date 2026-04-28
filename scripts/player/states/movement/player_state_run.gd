class_name PlayerStateRun extends PlayerState

func enter(_previous_state_path: String, _data := {}) -> void:
	set_movement_state_label()

func physics_update(delta: float) -> void:
	var move_direction: Vector3
	if player.can_move: move_direction = player.input_handler.move_direction

	player.move_and_fall(delta, move_direction, player.move_speed_ground)
	player.update_character(delta, move_direction)
	player.move_and_slide()

	if move_direction.is_equal_approx(Vector3.ZERO) or not player.can_move:
		finished.emit(MOVEMENT_IDLE, {})
	elif not player.is_on_floor():
		finished.emit(MOVEMENT_AIR_MOVE, {})

func handle_input(event: InputEvent) -> void:
	if event.is_action("jump") and event.is_pressed() and not event.is_echo():
		player.jump()
