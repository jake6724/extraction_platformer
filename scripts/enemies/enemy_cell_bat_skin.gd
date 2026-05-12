class_name EnemyCellBatSkin extends Node3D

@export var animation_player: AnimationPlayer
@export var mesh: MeshInstance3D
func _ready():
    animation_player.play("Idle")