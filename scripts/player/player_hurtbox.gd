class_name PlayerHurtbox
extends Area3D

signal hit

func take_damage(attacker_position: Vector3, attacker_power: float=20) -> void:
    print("Player take_damage")
    var _direction = -global_position.direction_to(attacker_position)
    var _impulse: Vector3 = _direction * attacker_power
    hit.emit(_impulse)