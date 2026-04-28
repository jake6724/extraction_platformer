class_name PlayerState extends State

const MOVEMENT_IDLE = "PlayerStateIdle"
const MOVEMENT_RUN = "PlayerStateRun"
const MOVEMENT_AIR_MOVE = "PlayerStateAirMove"
var movement_state_debug_strings: Dictionary[String, String] = {
    MOVEMENT_IDLE: "Idle",
    MOVEMENT_RUN: "Run",
    MOVEMENT_AIR_MOVE: "AirMove"
}

const ACTION_INACTIVE = "PlayerStateInactive"
var action_state_debug_stings: Dictionary[String, String] = {
    ACTION_INACTIVE: "Inactive",
}

var player: Player

func _ready() -> void:
	await owner.ready
	player = owner as Player
	assert(player != null, "The PlayerState state type must be used only in the player scene. It needs the owner to be a Player node.")

func set_movement_state_label() -> void:
	player.state_movement_label.text = movement_state_debug_strings[name]

func set_action_state_label() -> void:
	player.state_action_label.text = action_state_debug_stings[name]