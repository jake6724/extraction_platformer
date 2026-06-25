extends Node

var time_elapsed: float = 0.0
var seconds: int = 0
var minutes: int = 0
var milliseconds: int = 0
var time_text: String

func _physics_process(delta: float) -> void:
    time_elapsed += delta
    minutes = int(time_elapsed)/60
    seconds = int(time_elapsed)%60
    milliseconds = int((time_elapsed - int(time_elapsed)) * 100)
    time_text = "%02d:%02d:%02d" % [minutes, seconds, milliseconds]