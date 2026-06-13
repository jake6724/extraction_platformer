class_name EnemySkinCube extends EnemySkin


func walk() -> void:
	animation_player.play("Walk")

func run() -> void:
	animation_player.play("Run")

func hurt() -> void:
	animation_player.play("Hurt")

func skid() -> void:
	animation_player.play("Skid")
