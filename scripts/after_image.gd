## NO LONGER USED
## couldnt find a way to match the current animation of the play skin here, so instead just 
## ended up duplicating the player skin and overriding materials in Player.create_after_image()

class_name AfterImage
extends Node3D

@export var animation_tree: AnimationTree
@export var animation_player: AnimationPlayer
@onready var state_machine : AnimationNodeStateMachinePlayback = animation_tree.get("parameters/StateMachine/playback")

func initialize(_skin: SophiaSkin) -> void:
	# state_machine.start(_skin.state_machine.get_current_node())

	print(animation_tree.get_node("AnimationNodeAnimation"))


	var state_name: StringName = _skin.state_machine.get_current_node()
	var state_playback_position: float = state_machine.get_current_play_position()
	animation_tree.active = false

	# animation_player.play(state_name)
	# animation_player.seek(state_playback_position)

	# state_machine.start(state_name, false)
	global_position = _skin.mesh.global_position
	global_rotation = _skin.global_rotation
	# animation_tree.tree_root.playback
	await get_tree().create_timer(.1).timeout
	animation_tree.active = false
