extends Node

var hitstop_timer: Timer = Timer.new()

func _ready():
    process_mode = Node.PROCESS_MODE_ALWAYS

    hitstop_timer.autostart = false
    hitstop_timer.one_shot = true
    hitstop_timer.process_callback = Timer.TIMER_PROCESS_IDLE
    hitstop_timer.ignore_time_scale = true
    add_child(hitstop_timer)
    hitstop_timer.timeout.connect(on_hitstop_timer_timeout)

func apply_hitstop(_duration: float) -> void:
    Engine.time_scale = 0.1
    hitstop_timer.start(_duration)

func on_hitstop_timer_timeout() -> void:
    Engine.time_scale = 1.0