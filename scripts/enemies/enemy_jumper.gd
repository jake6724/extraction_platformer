class_name EnemyJumper extends Enemy

"""
When patrolling, should they pass thru eachother?
"""

@export_group("General")
# @export var acceleration: float = 40
@export_group("Patrol")
@export var patrol_speed: float = 3.0
var _current_patrol_direction: Vector3 = Vector3(0,0,1)
@export_group("Chase")
@export var chase_speed: float = 5.0
@export var escape_speed: float = 11.0
@export var chase_quit_delay: float = 5.0
@export var timer_chase_quit: Timer
@export_group("Jump")
@export var jump_power: float = 25.0
@export var jump_power_modifier_min: float = -4.0
@export var jump_power_modifier_max: float = 4.0
@export var timer_jump_in_range: Timer
@export var jump_in_range_duration_requirement: float = 0.01
@export var max_jump_trigger_distance: float = 7.0
@export var min_jump_trigger_distance: float = 5.0
## Tracks the most recent jump impulse; used in apply_jump()
var _jump_impulse: Vector3
var _player_position_at_jump_trigger: Vector3
var is_on_terrain_enable_delay: float = 0.2
@export_group("Components")
@export var area_detect_player: Area3D
@export var collider_detect_player: CollisionShape3D
@export var area_chase_quit: Area3D
@export var raycast_floor_ahead: RayCast3D
@export var raycast_wall: RayCast3D
@export var raycast_floor: RayCast3D
@export var shapecast_jump: ShapeCast3D
@export_group("Debug")
@export var trajectory_debug_parent: Node
@export var show_debug: bool = true
@export var outer_range_left: MeshInstance3D
@export var outer_range_right: MeshInstance3D
@export var inner_range_left: MeshInstance3D
@export var inner_range_right: MeshInstance3D
## How many time steps into future to predict trajectory
@export var trajectory_debug_iterations: int = 128
## Takes the place of delta in velocity calculations. Lower values give more precision
@export var trajectory_debug_time_step: float = .0166

enum State {IDLE, PATROL, CHASE, CHARGE, AIR, LAND, HIT}
var current_state: State = State.PATROL
var player: Player

func _ready():
	super()
	area_detect_player.body_entered.connect(on_area_detect_player_body_entered)
	area_detect_player.body_exited.connect(on_area_detect_player_body_exited)
	area_chase_quit.body_exited.connect(on_area_chase_quit_body_exited)
	timer_chase_quit.timeout.connect(on_timer_chase_quit_timeout)

	axis_lock_linear_x = true

	jump_power += randf_range(jump_power_modifier_min, jump_power_modifier_max)

	# timer_jump_in_range.timeout.connect(start_jump_charge)

	skin.land_complete.connect(on_skin_land_complete)
	skin.jump_charge_complete.connect(on_skin_jump_charge_complete)

	collider_detect_player.shape.radius = min_jump_trigger_distance

	raycast_floor.enabled = false

	outer_range_left.position.z -= max_jump_trigger_distance
	outer_range_right.position.z += max_jump_trigger_distance
	inner_range_left.position.z -= min_jump_trigger_distance
	inner_range_right.position.z += min_jump_trigger_distance
	outer_range_left.visible = show_debug
	outer_range_right.visible = show_debug
	inner_range_left.visible = show_debug
	inner_range_right.visible = show_debug
	skin.run()

func _physics_process(delta):
	#print_state()
	match current_state:
		State.IDLE: idle(delta)
		State.PATROL: patrol(delta)
		State.CHASE: chase(delta)
		State.AIR: air(delta)
		State.HIT: pass

func idle(delta: float) -> void:
	velocity = velocity.move_toward(Vector3.ZERO, delta*acceleration)
	velocity.x = 0
	velocity.y = move_toward(velocity.y, gravity_default, delta * gravity_acceleration)
	move_and_slide()

func patrol(delta: float) -> void:
	# Patrol in a direction until a wall found or end of platform reached
	if is_floor_ahead() and not is_wall_ahead():
		move_and_fall(delta, patrol_speed, _current_patrol_direction, acceleration)
	# Turn around
	else:
		_current_patrol_direction *= -1
		rotate_on_y(_current_patrol_direction)
		return
		
## The goal of chase is to get into a position where a jump can be triggered.
func chase(delta: float) -> void:
	# enable_enemy_collisions_1_frame()
	var z_direction_to_player: float = player.global_transform.origin.z - global_transform.origin.z
	var _direction_to_player: Vector3 = Vector3(0,0,z_direction_to_player).normalized()

	var x_locked_player_position: Vector3 = player.global_transform.origin
	x_locked_player_position.x = 0
	var x_locked_position: Vector3 = global_transform.origin
	x_locked_position.x = 0
	var distance_to_player: float = x_locked_position.distance_to(x_locked_player_position)

	# Take a jump if no where left to run
	if not is_floor_ahead() or is_wall_ahead():
		rotate_on_y(-_direction_to_player)
		start_jump_charge()

	# Too close to player, move away
	if distance_to_player < min_jump_trigger_distance:
		rotate_on_y(-_direction_to_player)
		move_and_fall(delta, escape_speed, -_direction_to_player, acceleration)
		timer_jump_in_range.stop()
	# Too far from player, move toward
	elif distance_to_player > max_jump_trigger_distance:
		rotate_on_y(_direction_to_player)
		move_and_fall(delta, chase_speed, _direction_to_player, acceleration)
		timer_jump_in_range.stop()
	# In jump range
	else:
		start_jump_charge()

func air(delta: float) -> void:
	velocity.y = move_toward(velocity.y, gravity_default, delta * gravity_acceleration)
	velocity.x = 0
	move_and_slide()

	if is_on_terrain():
		print("Terrain hit!")
		current_state = State.IDLE
		# set_collisions_with_enemies(true)
		raycast_floor.enabled = false
		skin.land()
		clear_debug_trajectory_points()

func on_area_detect_player_body_entered(_player: Player) -> void:
	if current_state == State.PATROL:
		player = _player
		current_state = State.CHASE
		skin.run()
	timer_chase_quit.stop() # Always cancel chase quitting process if they walk into attack range

func start_jump_charge() -> void:
	var x_locked_player_position: Vector3 = get_x_locked_player_position()
	x_locked_player_position.x = 0
	current_state = State.IDLE
	# _player_position_at_jump_trigger = x_locked_player_position
	_jump_impulse = get_jump_impulse(x_locked_player_position)
	charge()

func charge() -> void:
	rotate_on_y(get_direction_to_player(player))
	# set_collisions_with_enemies(false)
	skin.jump()

## Connected to [skin.jump_charge_complete]; called once skin jump windup animation has finished.
## Triggers actual jump physics
func on_skin_jump_charge_complete() -> void:
	var temp_jump_impulse: Vector3 = get_jump_impulse(get_x_locked_player_position())
	if temp_jump_impulse != Vector3.ZERO:
		_jump_impulse = temp_jump_impulse
	apply_jump()

## Apply jump impulse, transition to air. Impulse used is `_jump_impulse`
func apply_jump() -> void:
	rotate_on_y(get_direction_to_player(player))
	if _jump_impulse != Vector3.ZERO:
		velocity = _jump_impulse
		current_state = State.AIR
		skin.air()
		await get_tree().create_timer(is_on_terrain_enable_delay).timeout
		raycast_floor.enabled = true
	else:
		current_state = State.CHASE

## Connected to [skin.land_complete]; called once skin land animation has finished
## Tranisitions to post jumping behavior
func on_skin_land_complete() -> void:
	current_state = State.CHASE # TODO: Check for target and do idle, patrol, or chase 
	skin.run()
	enable_enemy_collisions_1_frame()

## Based on "Angle θ required to hit coordinate (x, y)" section of https://en.wikipedia.org/wiki/Projectile_motion
func get_jump_impulse(_player_position: Vector3) -> Vector3:
	var initial_velocity: float = jump_power
	# Store the player's position and distances. The z distance is used as x here
	var target_position: Vector3 = _player_position
	var x_range: float = player.global_transform.origin.z - global_transform.origin.z
	var y_range: float = player.global_transform.origin.y - global_transform.origin.y

	# Compute the products in the discriminant
	var g_x_squared: float = (abs(gravity_default)) * (pow(x_range, 2))
	var two_y_v_squared: float = 2 * y_range * (pow(initial_velocity, 2))
	if is_nan(g_x_squared) or is_nan(two_y_v_squared):
		return Vector3.ZERO
	# Compute discriminant and its sqrt
	var discriminant: float = (pow(initial_velocity, 4)) - ((abs(gravity_default)) * (g_x_squared + two_y_v_squared))
	var square_root_discriminant: float = sqrt(discriminant)
	# Compute the value inside the highest-level parenthesis 
	# The +/- here:[(pow(initial_velocity, 2)) +/- square_root_discriminant)] determines where the high or low arc is used.
	var inner_solution: float = ((pow(initial_velocity, 2)) + square_root_discriminant) / ((abs(gravity_default)) * x_range)
	# Compute final angle
	var angle: float = atan(inner_solution)
	if is_nan(discriminant) or is_nan(square_root_discriminant) or is_nan(inner_solution) or is_nan(angle):
		return Vector3.ZERO

	var _direction_to_player: Vector3 = get_direction_to_player(player)
	# Compute the direction vector based on angle. -sin = y amount, -cos = z amount (in this specific case, usually x) 
	var _direction = Vector3(-sin(angle), 0, -cos(angle)).normalized()
	# Compute the jump impulse, using the direction to the player to direct the z-axis of the jump
	# Re-order the direction vector so that x,y,z are all in their correct positions. Orient the z value with direction to player
	var jump_impulse_direction: Vector3 = Vector3(0, abs(_direction.x), abs(_direction.z) * sign(_direction_to_player.z))
	var impulse = jump_impulse_direction * initial_velocity
	is_jump_trajectory_clear(impulse)
	if show_debug: debug_draw_jump_trajectory(impulse, target_position)
	return impulse

func debug_draw_jump_trajectory(_impulse: Vector3, _target_positon: Vector3) -> void:
	var curr_position: Vector3 = global_transform.origin	
	# Place a debug mesh at the target position
	var target_mesh = create_debug_mesh(.3, .6, Color.ORANGE)
	trajectory_debug_parent.add_child(target_mesh)
	target_mesh.global_transform.origin = _target_positon

	# Place a debug mesh along the jump impulse's trajectory
	for i in range(trajectory_debug_iterations):
		var new_mesh = create_debug_mesh()
		trajectory_debug_parent.add_child(new_mesh)
		# Increment placement position based on trajectory's path at next time step
		curr_position += (_impulse * trajectory_debug_time_step)
		new_mesh.global_transform.origin = curr_position
		_impulse.y = move_toward(_impulse.y, gravity_default, trajectory_debug_time_step * gravity_acceleration)

func clear_debug_trajectory_points() -> void:
	await get_tree().create_timer(1).timeout
	for child in trajectory_debug_parent.get_children():
		child.queue_free()

func create_debug_mesh(_radius: float=0.1, _height: float=0.2, _color: Color=Color.RED) -> MeshInstance3D:
	# Initialize mesh instance, create and configure sphere mesh
	var new_mesh: MeshInstance3D = MeshInstance3D.new()
	var new_sphere_mesh: SphereMesh = SphereMesh.new()
	new_sphere_mesh.radius = _radius
	new_sphere_mesh.height = _height
	new_sphere_mesh.radial_segments = 8
	new_sphere_mesh.rings = 4
	# Assign sphere mesh to mesh instance, create and add material
	new_mesh.mesh = new_sphere_mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = _color
	new_mesh.material_override = material
	return new_mesh

func is_jump_trajectory_clear(_impulse: Vector3) -> void: 
	pass
	# var curr_position: Vector3 = global_transform.origin
	# var local_timestep: float = 0.016
	# var local_iterations: int = 128
	# var count: int = 0
	# var count_target: int = 2

	# for i in range(local_iterations):
	# 	curr_position += (_impulse * local_timestep)
	# 	if count == count_target:
	# 		count = 0
	# 		var new_mesh = create_debug_mesh(.3, .6, Color.PURPLE)
	# 		trajectory_debug_parent.add_child(new_mesh)
	# 		new_mesh.global_transform.origin = curr_position

	# 		shapecast_jump.target_position = to_local(curr_position)
	# 		shapecast_jump.force_shapecast_update()
	# 		if shapecast_jump.is_colliding():
	# 			print("Shapecast collision: ", shapecast_jump.get_collider(0))


	# 	else:
	# 		count += 1
		
	# 	_impulse.y = move_toward(_impulse.y, gravity_default, local_timestep * gravity_acceleration)

func on_area_chase_quit_body_exited(_player: Player) -> void:
	pass
	# if not timer_chase_quit.time_left > 0:
	# 	timer_chase_quit.start(chase_quit_delay)

func on_timer_chase_quit_timeout() -> void:
	pass
	# current_state = State.IDLE
	# skin.idle()
	# player = null

func get_direction_to_player(_player: Player) -> Vector3:
	var z_direction_to_player: float = _player.global_transform.origin.z - global_transform.origin.z
	var _direction_to_player: Vector3 = Vector3(0,0,z_direction_to_player).normalized()
	return _direction_to_player

func on_area_detect_player_body_exited(_player: Player) -> void:
	pass

func is_floor_ahead() -> bool:
	return raycast_floor_ahead.is_colliding()

func is_wall_ahead() -> bool:
	return raycast_wall.is_colliding()

func print_state() -> void:
	var _text: String
	match current_state:
		State.IDLE: _text = "IDLE"
		State.CHASE: _text = "CHASE"
		State.AIR: _text = "AIR"
		State.LAND: _text = "LAND"
		State.HIT: _text = "HIT"
	print(_text)

func get_x_locked_player_position() -> Vector3:
	var x_locked_player_position: Vector3 = player.global_transform.origin
	x_locked_player_position.x = 0
	return x_locked_player_position

func is_on_terrain() -> bool:
	return true if raycast_floor.is_colliding() else false