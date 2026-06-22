class_name Slash extends Node3D

@export var animation_player: AnimationPlayer
@export var parent: Player

func slash() -> void:
	animation_player.play("slash")