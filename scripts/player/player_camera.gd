class_name PlayerCamera
extends Camera3D

@export var camera_pivot: Node3D
## Controls camera zoom. This value is the camera's initial zoom (based on Camera3D's size property if orthographic), and it modified by zoom_step.
@export var zoom_target: float = 16
## Controls how close the camera can get to the player
@export var zoom_min: float = 5
## Controls how far the camera can get from the player
@export var zoom_max: float = 30
@export_range(1, 20, 1) var zoom_sensitivity: float = 3
@export_range(.1, 10, .1) var zoom_step: float = 1
## Multiplier controlling the strength of the camera's lerp to player's position. Lower values will cause the camera to trail behind the player's current position more.
@export var camera_follow_speed: float = 15
var camera_limit_left: float
var camera_limit_right: float 
## Do not change; this does not affect zoom. For ortho Camera3D, zoom is controlled with size but the camera X still needs to start far enough away to avoid clipping forward into the world
var _camera_x_position: float = 8.0
const MOVE_DIRECTION_THRESHOLD: float = 0.2

var curr_power: float
var shake_offset: Vector2 = Vector2.ZERO
@export var power: float = 5
@export var decay: float = 20


func initialize() -> void:
	global_transform.origin = camera_pivot.global_transform.origin
	rotation_degrees.y = 90
	position.x = _camera_x_position

## Set by the level
func set_limits(left_limit: Vector3, right_limit: Vector3) -> void:
	camera_limit_left = left_limit.z
	camera_limit_right = right_limit.z

func update(delta: float) -> void:
	process_position(delta)
	process_zoom(delta)
	process_limits()
	process_shake(delta)

## MUST be called in `_physics_process` to avoid desyncing which causes jittering
func process_position(delta: float) -> void:
	# Do not update X-axis, just Y and Z based on camera_pivot's transform
	var target_z: float = camera_pivot.global_transform.origin.z
	var target_y: float = camera_pivot.global_transform.origin.y
	global_transform.origin.z = lerp(global_transform.origin.z, target_z, delta * camera_follow_speed)
	global_transform.origin.y = lerp(global_transform.origin.y, target_y, delta * camera_follow_speed)

func process_zoom(delta: float) -> void:
	if not is_equal_approx(size, zoom_target):
		zoom_target = clamp(zoom_target, zoom_min, zoom_max)
		size = lerp(size, zoom_target, zoom_sensitivity * delta)

func process_limits() -> void:
	global_position.z = clamp(global_position.z, camera_limit_right, camera_limit_left)

func process_shake(delta: float) -> void:
	# Handle camera shake if power left
	if curr_power > .1:
		curr_power = snappedf(lerpf(curr_power, 0, decay * delta), 0.01)
		shake_offset = get_random_offset()
	else:
		shake_offset = Vector2.ZERO

	h_offset = shake_offset.x
	v_offset = shake_offset.y

func get_random_offset() -> Vector2:
	return Vector2(randf_range(-curr_power, curr_power), randf_range(-curr_power, curr_power))

func apply_shake(power_scale: float) -> void:
	var new_power: float = power * power_scale
	if new_power >= curr_power:
		curr_power = new_power

# func _input(event):
# 	if Input.is_action_just_pressed("x"):
# 		apply_shake(.05)
