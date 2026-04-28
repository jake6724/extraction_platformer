class_name PlayerStateInactive extends PlayerState

func enter(_previous_state_path: String, _data := {}) -> void:
	set_action_state_label()
