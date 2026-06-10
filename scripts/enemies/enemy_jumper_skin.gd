class_name EnemyJumperSkin extends EnemySkin

var jump_windup_speed_scale: float # Set by EnemyJumper

signal land_complete
signal jump_charge_complete

func run() -> void:
    animation_player.play("Run")
    
func idle() -> void:
    animation_player.play("Idle")

func jump() -> void:
    animation_player.speed_scale = jump_windup_speed_scale
    animation_player.play("Jump")
    await animation_player.animation_finished
    animation_player.speed_scale = 1.0

func air() -> void:
    animation_player.play("Air")

func land() -> void:
    animation_player.speed_scale = jump_windup_speed_scale
    animation_player.play("Landing")
    await animation_player.animation_finished
    animation_player.speed_scale = 1.0

func emit_land_complete() -> void:
    land_complete.emit()

func emit_jump_charge_complete() -> void:
    jump_charge_complete.emit()