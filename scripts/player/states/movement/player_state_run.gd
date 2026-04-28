class_name PlayerStateRun extends PlayerState

func enter(_previous_state_path: String, _data := {}) -> void:
    set_movement_state_label()

# func physics_update(_delta: float) -> void:
#     print("In run now")