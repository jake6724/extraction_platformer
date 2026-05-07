class_name SpinTurret
extends CharacterBody3D

@export var shooters: Array[Shooter]
@export var shoot_timer: Timer
@export var shoot_delay: float = 2.0
@export var rotate_timer: Timer 
@export var rotate_delay: float = .75
@export var enabled: bool = true
@export var spin_offset: float = 45
@export var spin_duration_normal: float = 0.25
@export var spin_out_offset: float = 1080 + spin_offset
@export var spin_duration_long: float = .75
@export var start_rotated: bool = false

func _ready():
	shoot_timer.timeout.connect(on_shoot_timer_timeout)
	rotate_timer.timeout.connect(on_rotate_timer_timeout)
	if enabled:
		shoot_timer.start(shoot_delay)
	if start_rotated:
		rotation_degrees.x = spin_offset

func on_shoot_timer_timeout() -> void:
	fire_shooters()
	rotate_timer.start(rotate_delay)

func fire_shooters() -> void:
	if enabled:
		for shooter: Shooter in shooters:
			shooter.fire()

func on_rotate_timer_timeout() -> void:
	spin(spin_offset, spin_duration_normal)

func spin(rotation_amount: float, spin_duration: float) -> void:
	var rotate_tween: Tween = get_tree().create_tween()
	var target_rotation_x: float = rotation_degrees.x + rotation_amount
	rotate_tween.set_ease(Tween.EASE_IN_OUT)
	rotate_tween.tween_property(self, "rotation_degrees:x", target_rotation_x, spin_duration)
	if enabled: shoot_timer.start(shoot_delay)

func spin_out() -> void:
	shoot_timer.stop()
	spin(spin_out_offset, spin_duration_long)

## Override
func take_damage(_direction, _power) -> void:
	pass
