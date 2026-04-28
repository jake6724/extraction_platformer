class_name PlayerStateIdle extends PlayerState

func enter(_previous_state_path: String, _data := {}) -> void:
	set_movement_state_label()

func physics_update(_delta: float) -> void:
	if not player.input_handler.move_direction.is_equal_approx(Vector3.ZERO):
		finished.emit(MOVEMENT_RUN,{})