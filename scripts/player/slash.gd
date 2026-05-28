class_name Slash extends Node3D

@export var animation_player: AnimationPlayer
@export var parent: Player

func slash() -> void:
	print("Playing slash")
	animation_player.play("slash")