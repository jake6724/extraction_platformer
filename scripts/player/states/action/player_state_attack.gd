class_name PlayerStateAttack extends PlayerState

func enter(_previous_state_path: String, _data := {}) -> void:
	set_action_state_label()
	player.attack()
	finished.emit(ACTION_INACTIVE, {})

# func handle_input(event: InputEvent) -> void:
# 	if event.is_action("attack") and event.is_pressed() and not event.is_echo():
# 		player.attack()