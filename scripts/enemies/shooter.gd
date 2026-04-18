class_name Shooter
extends Node3D

const BULLET_SCENE: PackedScene = preload("res://scenes/enemies/Bullet.tscn")
@export var bullet_parent: Node
@export var power: float = 15.0
@export var attack_power: float = 50.0
@export var enabled: bool = true

func _ready():
	hide()

func fire() -> void:
	if enabled:
		var bullet: Bullet = BULLET_SCENE.instantiate()
		bullet_parent.add_child(bullet)
		bullet.global_position = global_position
		var launch_direction: Vector3 = -global_transform.basis.z
		bullet.launch(launch_direction, power, attack_power)
