class_name InputHandler extends Node

var right_direction: Vector3 = Vector3.FORWARD
var move_direction: Vector3

signal jump_triggered
signal attack_triggered
signal slide_triggered
signal slide_released

func _input(event):
	if event.is_action("jump") and event.is_pressed() and not event.is_echo():
		jump_triggered.emit()

	if event.is_action("attack") and event.is_pressed() and not event.is_echo():
		attack_triggered.emit()

	if event.is_action("slide") and event.is_pressed() and not event.is_echo():
		slide_triggered.emit()
	
	if event.is_action_released("slide") and not event.is_echo():
		slide_released.emit()

func _physics_process(_delta):
	var raw_input: Vector2 = Vector2.ZERO
	move_direction = Vector3.ZERO
	raw_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	move_direction = (right_direction * raw_input.x)
	move_direction.y = 0.0 # Player will never give up-and-down move input. Jumping and falling with handle this
	move_direction = move_direction.normalized() # This is just intended to be a direction vector so it needs to be normalized