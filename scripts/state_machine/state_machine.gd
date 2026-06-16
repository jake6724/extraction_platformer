class_name StateMachine extends Node

@export var initial_state: State = null
@onready var state: State = (func get_initial_state() -> State:
	return initial_state if initial_state != null else get_child(0)
).call()

var states: Dictionary[String, State]

func _ready() -> void:
	await owner.ready # Ensure player is available, this will allow State.initialize() to reference player components
	for state_node: State in find_children("*", "State"):
		state_node.tranisition.connect(transition_state)
		state_node.initialize(owner)
		states[state_node.name.to_lower()] = state_node
	state.enter("")

func connect_to_input_signals() -> void:
	owner.input_handler.jump_triggered.connect(_unhandled_input)

func _unhandled_input(event: InputEvent) -> void:
	state.handle_input(event)

func _process(delta: float) -> void:
	state.update(delta)

func _physics_process(delta: float) -> void:
	state.physics_update(delta)

func transition_state(target_state_name: String, data: Dictionary = {}) -> void:
	target_state_name = target_state_name.to_lower()
	if not states.has(target_state_name):
		printerr(owner.name + ": Trying to transition to state " + target_state_name + " but it does not exist.")
		return

	var previous_state_path := state.name
	state.exit()
	state = states[target_state_name]
	state.enter(previous_state_path, data)