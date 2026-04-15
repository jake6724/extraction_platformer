class_name AfterImage
extends Node3D

@export var animation_tree: AnimationTree
@export var animation_player: AnimationPlayer
@onready var state_machine : AnimationNodeStateMachinePlayback = animation_tree.get("parameters/StateMachine/playback")

func initialize(_skin: SophiaSkin) -> void:
	state_machine.travel(_skin.state_machine.get_current_node())
	global_position = _skin.mesh.global_position
	global_rotation = _skin.global_rotation
	# animation_tree.tree_root.playback
	await get_tree().create_timer(.1).timeout
	animation_tree.active = false
