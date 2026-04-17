class_name SpikePlatform
extends AnimatableBody3D

@export var spike_area: Area3D
var attack_power: float = 20

func _input(event):
    if Input.is_action_just_pressed("x"):
        flip()

func _ready():
    spike_area.area_entered.connect(on_spike_area_area_entered)

func on_spike_area_area_entered(_intruder: Node3D) -> void:
    if _intruder is PlayerHurtbox:
        _intruder.take_damage(global_position, attack_power)

func flip() -> void:
    var rotate_tween: Tween = get_tree().create_tween()
    var target_rotation_x: float = rotation_degrees.x + 180
    rotate_tween.tween_property(self, "rotation_degrees:x", target_rotation_x, .5)