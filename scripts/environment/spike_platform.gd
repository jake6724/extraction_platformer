class_name SpikePlatform
extends AnimatableBody3D

@export var spike_area: Area3D
var attack_power: float = 20
var attack_direction: Vector3

func _ready():
    spike_area.area_entered.connect(on_spike_area_area_entered)
    attack_direction = get_attack_direction()

func _input(event):
    if Input.is_action_just_pressed("x"):
        flip()

func on_spike_area_area_entered(_intruder: Node3D) -> void:
    if _intruder is PlayerHurtbox:
        _intruder.take_damage(global_position, attack_power, attack_direction)

func flip() -> void:
    var rotate_tween: Tween = get_tree().create_tween()
    var target_rotation_x: float = rotation_degrees.x + 180
    rotate_tween.tween_property(self, "rotation_degrees:x", target_rotation_x, .5)
    await rotate_tween.finished
    attack_direction = get_attack_direction()

func get_attack_direction() -> Vector3:
    return (global_transform.basis.y).normalized().snappedf(1)