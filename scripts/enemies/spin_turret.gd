class_name SpinTurret
extends Enemy

@export var shooters: Array[Shooter]
@export var shoot_timer: Timer
@export var shoot_delay: float = 2.0
@export var rotate_timer: Timer 
@export var rotate_delay: float = .75

func _ready():
    shoot_timer.timeout.connect(on_shoot_timer_timeout)
    rotate_timer.timeout.connect(on_rotate_timer_timeout)
    shoot_timer.start(shoot_delay)

func on_shoot_timer_timeout() -> void:
    fire_shooters()
    rotate_timer.start(rotate_delay)

func fire_shooters() -> void:
    for shooter: Shooter in shooters:
        shooter.fire()

func on_rotate_timer_timeout() -> void:
    spin()

func spin() -> void:
    var rotate_tween: Tween = get_tree().create_tween()
    var target_rotation_x: float = rotation_degrees.x + 360 + 45
    rotate_tween.set_ease(Tween.EASE_IN_OUT)
    rotate_tween.tween_property(self, "rotation_degrees:x", target_rotation_x, .25)
    shoot_timer.start(shoot_delay)