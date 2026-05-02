class_name PlayerStateIdle extends PlayerState

func enter(_previous_state_path: String, _data := {}) -> void:
	set_movement_state_label()

func physics_update(delta: float) -> void:
	player.move_and_fall(delta, Vector3.ZERO, player.move_speed_ground)
	player.update_character(delta, Vector3.ZERO)
	player.move_and_slide()

	if not player.input_handler.move_direction.is_equal_approx(Vector3.ZERO):
		if player.is_on_floor():
			finished.emit(MOVEMENT_RUN,{})
		else:
			finished.emit(MOVEMENT_AIR_MOVE,{})

func handle_input(event: InputEvent) -> void:
	if event.is_action("jump") and event.is_pressed() and not event.is_echo():
		player.jump()