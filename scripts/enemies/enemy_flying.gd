class_name EnemyFlying extends Enemy

# TODO: Maybe the enemy shuld have its own copy of the scents. OR maybe the enemy should create the scents in teh first place, instead
# of the player

@export var player: Player
@export_group("Stats")
@export var acceleration: float = 30.0
@export_group("Components")
@export var raycast_detect_top: RayCast3D
@export var raycast_detect_center: RayCast3D
@export var raycast_detect_bottom: RayCast3D
@export var area_detect_player: Area3D
@export var body_collider: CollisionShape3D
@export_group("Patrol")
@export var path_follow: PathFollow3D
@export var patrol_speed_scale: float = 0.1
@export var start_left_to_right: bool = true
@export_group("Chase")
@export var chase_speed_min: float = 8.0
@export var chase_speed_max: float = 10.0
@export var timer_chase_quit: Timer
@export var chase_quit_delay_min: float = 10.0
@export var chase_quit_delay_max: float = 15.0
@export var post_dash_chase_speed_scale: float = .25
var _chase_speed: float
var _post_dash_chase_speed: float
var _active_chase_speed: float
var _chase_quit_delay: float
@export_group("Dash")
@export var dash_initial_cooldown_duration_min: float = 1.0
@export var dash_initial_cooldown_duration_max: float = 2.0
@export var timer_dash_charge: Timer
@export var dash_charge_duration_min: float = .25
@export var dash_charge_duration_max: float = .5
@export var timer_dash_cooldown: Timer
@export var dash_cooldown_duration_min: float = 2.0
@export var dash_cooldown_duration_max: float = 5.0
@export var timer_post_dash: Timer
@export var post_dash_cooldown_duration_min: float = 1.0
@export var post_dash_cooldown_duration_max: float = 2.0
@export var dash_power: float = 35.0
@export var dash_range: float = 7.0
var _can_dash: bool = false
var _dash_velocity_reset_threshold: float = 4.0
@export_group("Combat")
@export var health: int = 3
@export_group("Debug")
@export var show_debug: bool = false
@export var move_indicator: MeshInstance3D
@export var last_seen_player_position_indicator: MeshInstance3D
@export var skin: EnemyCellBatSkin

enum State {PATROL, CHASE, IDLE, CHARGE, DASH,}
var current_state: State = State.PATROL

# Direction
var directions: Array[Vector3] = [] # Generated based on num_directions
var num_directions: float = 128.0
# Steering
var interest: Array[float]
var danger: Array[float]
# Danger Raycasts
var danger_raycasts: Array[RayCast3D]
var danger_raycast_length: float = 4
# LSP
var last_seen_player_position: Vector3
var last_seen_player_position_reached: bool = false
var last_seen_player_position_reached_threshold: float = .5
# Scents
var ignore_scents: Dictionary[Scent, Variant] = {}
var scent_reached_threshold: float = 2.0 # Could try diff values still

func _ready():
	super()
	directions = create_directions(num_directions)
	create_danger_raycasts()

	move_indicator.visible = show_debug
	last_seen_player_position_indicator.visible = show_debug

	if not start_left_to_right:
		patrol_speed_scale *= -1
		path_follow.progress_ratio = 0.99
		skin.flip_horizontal(true)
		skin.mirror_mesh(true)
	else:
		patrol_speed_scale *= 1
		path_follow.progress_ratio = 0.01
		skin.flip_horizontal(false)
		skin.mirror_mesh(false)

	area_detect_player.body_entered.connect(on_area_detect_player_body_entered)
	area_detect_player.body_exited.connect(on_area_detect_player_body_exited)
	
	_chase_speed = randf_range(chase_speed_min, chase_speed_max)
	_post_dash_chase_speed = _chase_speed * post_dash_chase_speed_scale
	_active_chase_speed = _chase_speed
	_chase_quit_delay = randf_range(chase_quit_delay_min, chase_quit_delay_max)
	timer_chase_quit.timeout.connect(on_timer_chase_quit_timeout)

	timer_dash_charge.timeout.connect(on_timer_dash_charge_timeout)
	timer_dash_cooldown.timeout.connect(on_timer_dash_cooldown_timeout)

	timer_post_dash.timeout.connect(on_timer_post_dash_timeout)

func _physics_process(delta):
	match current_state:
		State.PATROL: patrol(delta)
		State.CHASE: chase(delta)
		State.IDLE: idle(delta)
		State.CHARGE: pass
		State.DASH: dash(delta)
		_: push_error("EnemyFlying: invalid current_state. current_state = ", current_state)

func patrol(delta: float) -> void:
	path_follow.progress_ratio += (delta * patrol_speed_scale)
	if is_equal_approx(path_follow.progress_ratio, 1.0):
		patrol_speed_scale *= -1
		path_follow.progress_ratio = .99
		skin.flip_horizontal(true)
		skin.mirror_mesh(true)
	elif is_equal_approx(path_follow.progress_ratio, 0.0):
		patrol_speed_scale *= -1
		path_follow.progress_ratio = .01
		skin.flip_horizontal(false)
		skin.mirror_mesh(false)

func chase(delta: float) -> void:
	var move_target_point: Vector3 = get_move_target_point()
	interest = get_interest_weights(move_target_point)
	danger = get_danger_weights()
	
	# Reduce the value of interest directions that have danger
	for i in range(interest.size()):
		interest[i] -= danger[i]

	# Avoidance (increase value of interest directions OPPOSITE to those with danger)
	for i in range(interest.size()):
		var index: int
		var offset: int = directions.size()/2
		if i < interest.size()/2: 
			index = offset + i
		else: 
			index = directions.size() - i
		interest[index] += danger[i]

	var move_direction: Vector3 = get_move_direction()
	velocity = velocity.move_toward(move_direction * _active_chase_speed, delta * acceleration)
	velocity.x = 0

	var flip: bool = move_direction.z > 0
	skin.flip_horizontal(flip)
	skin.mirror_mesh(flip)

	move_and_collide(velocity * delta)
	global_transform.origin.x = 0

	# Update debug indicators
	move_indicator.global_transform.origin = global_transform.origin + (velocity.normalized() * 2)
	last_seen_player_position_indicator.global_transform.origin = last_seen_player_position
	if is_last_seen_position_reached():
		last_seen_player_position_reached = true
		last_seen_player_position_indicator.get_surface_override_material(0).albedo_color = Color.DARK_GREEN

	# Try to dash at the player
	if _can_dash and is_target_visible(player.tracker.global_transform.origin):
		var x_locked_position: Vector3 = Vector3(0, global_transform.origin.y, global_transform.origin.z)
		var x_locked_player_position: Vector3 = Vector3(0, player.tracker.global_transform.origin.y, player.tracker.global_transform.origin.z)
		if x_locked_position.distance_to(x_locked_player_position) < dash_range:
			current_state = State.CHARGE
			var charge_time: float = randf_range(dash_charge_duration_min, dash_charge_duration_max)
			timer_dash_charge.start(charge_time)
			flash_mesh_repeat(charge_time, 5, Color.WHITE)
			_can_dash = false

func on_timer_dash_charge_timeout() -> void:
	var x_locked_position: Vector3 = Vector3(0, global_transform.origin.y, global_transform.origin.z)
	var x_locked_player_position: Vector3 = Vector3(0, player.tracker.global_transform.origin.y, player.tracker.global_transform.origin.z)
	apply_dash(x_locked_position, x_locked_player_position)

func apply_dash(start_position: Vector3, target_position: Vector3) -> void:
	current_state = State.DASH
	var dash_direction: Vector3 = start_position.direction_to(target_position)
	velocity = dash_power * dash_direction
	set_collision_with_enemies(false)

	_active_chase_speed = _post_dash_chase_speed

func set_collision_with_enemies(_disabled: bool) -> void:
	set_collision_mask_value(2, _disabled)

func start_dash_cooldown(_min, _max) -> void:
	var dash_cooldown: float = randf_range(_min, _max)
	timer_dash_cooldown.start(dash_cooldown)

func dash(delta: float) -> void:
	move_and_collide(velocity * delta)
	velocity = velocity.move_toward(Vector3.ZERO, delta * acceleration)
	if velocity.length() < _dash_velocity_reset_threshold:
		start_dash_cooldown(dash_cooldown_duration_min, dash_cooldown_duration_max)
		current_state = State.CHASE
		set_collision_with_enemies(true)
		var post_dash_cooldown_duration: float = randf_range(post_dash_cooldown_duration_min, post_dash_cooldown_duration_max)
		timer_post_dash.start(post_dash_cooldown_duration)

func on_timer_dash_cooldown_timeout() -> void:
	_can_dash = true
	flash_mesh_repeat(.5, 3, Color.GREEN)

func on_timer_post_dash_timeout() -> void:
	_active_chase_speed = _chase_speed

## Do not move, but constantly check to see if can see player. If so, return to chasing
func idle(_delta: float) -> void:
	if is_target_visible(player.tracker.global_transform.origin):
		current_state = State.CHASE

func is_last_seen_position_reached() -> bool:
	var from: Vector3 = Vector3(0, global_transform.origin.y, global_transform.origin.z)
	var to: Vector3 = Vector3(0, last_seen_player_position.y, last_seen_player_position.z)
	global_transform.origin.distance_to(last_seen_player_position)
	return from.distance_to(to) < last_seen_player_position_reached_threshold 

func get_move_target_point() -> Vector3:
	var _move_target_point: Vector3
	# Can see player
	if is_target_visible(player.tracker.global_transform.origin):
		# Update last seen position for use later
		_move_target_point = player.tracker.global_transform.origin
		last_seen_player_position = player.tracker.global_transform.origin
		last_seen_player_position_reached = false
		last_seen_player_position_indicator.get_surface_override_material(0).albedo_color = Color.GREEN
		
		# Discard any scents spawned before we saw the player, 
		# except the last one (always want atleast 1 available to follow)
		for scent in player.scents.slice(1,player.scents.size(),1):
			ignore_scents.set(scent, null)
			scent.mesh.get_surface_override_material(0).albedo_color = Color.PINK

		# Issues erasing old scents (https://github.com/godotengine/godot/issues/110511)
		# for scent in ignore_scents.keys():
		# 	if not is_instance_valid(scent):
		# 		ignore_scents.erase(scent)

	# Cannot see player, hasn't visited LSP. Move to LSP
	elif not last_seen_player_position_reached and is_target_visible(last_seen_player_position):
		timer_chase_quit.start(_chase_quit_delay)
		_move_target_point = last_seen_player_position
		last_seen_player_position_indicator.get_surface_override_material(0).albedo_color = Color.DARK_GREEN

	# Cannot see player, HAS visited LSP, OR cannot see LSP. Follow scent trail
	elif player.scents.size() != 0:
		# Set debug values
		timer_chase_quit.start(_chase_quit_delay)
		last_seen_player_position_reached = true
		last_seen_player_position_indicator.get_surface_override_material(0).albedo_color = Color.PALE_GREEN

		# Find closest scent position and follow
		_move_target_point = get_closest_scent_position(player)
	
	# Can't see player, no scent trail. Return empty Vector3
	else:
		current_state = State.IDLE
		_move_target_point = Vector3()

	return _move_target_point

## Checks if each raycast (top, center, bottom) can see the target position. The raycasts are not looking for the target, they only collide with
## terrain and have infinite range. If no collisions are found, then it is possible to see that location.
## Returns positive if target IS visible, false otherwise.
## Updates the `target_position` of each detection raycast and calls `force_raycast_update()` on each BEFORE checking for collisions
func is_target_visible(_move_target_point) -> bool:
	set_detection_raycasts_target(_move_target_point)
	return not raycast_detect_top.is_colliding() and not raycast_detect_bottom.is_colliding() and not raycast_detect_center.is_colliding()

## Set the `target_position` of each detection raycast and call `force_raycast_update()` on each
func set_detection_raycasts_target(_move_target_point: Vector3) -> void:
	raycast_detect_top.target_position = to_local(_move_target_point)
	raycast_detect_bottom.target_position = to_local(_move_target_point)
	raycast_detect_center.target_position = to_local(_move_target_point)
	raycast_detect_top.force_raycast_update()
	raycast_detect_bottom.force_raycast_update()
	raycast_detect_center.force_raycast_update()

## Calculate the weight for each direction based on the dot product of that direction and player position.
## The move direct a direction points to the player, the higher the weight
func get_interest_weights(_move_target_point: Vector3) -> Array[float]:
	var _interest: Array[float]
	_interest.resize(directions.size())
	var direction_to_player: Vector3 = global_transform.origin.direction_to(_move_target_point)
	for i in range(directions.size()):
		var weight: float = clampf(directions[i].dot(direction_to_player), 0, 1)
		_interest[i] = weight
	return _interest

## Calculate the weight for each direction based on whether that direction will lead to an obstacle. The distance to an obstacle
## determines how strong that direction is weighted as danger (closer to obstacle, higher danger weight)
func get_danger_weights() -> Array[float]:
	var _danger: Array[float]
	_danger.resize(directions.size())
	for i in range(directions.size()):
		if danger_raycasts[i].is_colliding():
			var collision_point: Vector3 = danger_raycasts[i].get_collision_point()
			var distance_to_collision: float = global_transform.origin.distance_to(collision_point)
			var distance_scale: float = distance_to_collision / danger_raycast_length
			var weight: float = 1 - (1 * distance_scale)
			_danger[i] = weight
		else:
			_danger[i] = 0.0
	return _danger

## Create danger raycasts which are used for steering/collision avoidance. The number of raycasts
## is the same as `num_directions`
func create_danger_raycasts() -> void:
	for i in range(directions.size()):
		# Create new raycast, position at enemy origin
		var new_raycast: RayCast3D = RayCast3D.new()
		add_child(new_raycast)
		new_raycast.global_transform.origin = global_transform.origin

		# Point and scale out raycast, configure
		new_raycast.target_position = directions[i] * danger_raycast_length
		new_raycast.debug_shape_custom_color = Color.ORANGE_RED
		new_raycast.collision_mask = 4
		danger_raycasts.append(new_raycast)

## Calculate move direction, using `interest` to weight each possible direction and returning the average
func get_move_direction() -> Vector3:
	var selected_direction: Vector3 = Vector3.ZERO
	for i in directions.size():
		selected_direction += directions[i] * interest[i]
	selected_direction = selected_direction.normalized()
	return selected_direction

## Create `directions` array based on `num_directions`. Direction are spread evenly around a circle and normalized
func create_directions(_num_directions: float) -> Array[Vector3]:
	var res: Array[Vector3]
	for i in range(num_directions):
		var angle: float = i * 2 * PI / num_directions
		var _direction: Vector3 = Vector3.UP.rotated(Vector3.RIGHT, angle).normalized()
		res.append(_direction)
	return res

## Return the closest player scent. Check if Player.scents is populated BEFORE using this function, or it may return an empy Scent object
func get_closest_scent_position(_player: Player) -> Vector3:
	var closest_scent_position: Vector3
	var closest_scent: Scent # Only used for debug
	var closest: float = INF
	for scent in player.scents:
		if is_instance_valid(scent):
			var scent_distance: float = global_transform.origin.distance_to(scent.global_transform.origin)
			if scent not in ignore_scents:
				scent.mesh.get_surface_override_material(0).albedo_color = Color.YELLOW
				if (scent_distance < closest) and is_target_visible(scent.global_transform.origin):
					closest_scent_position = scent.global_transform.origin
					closest_scent = scent
					closest = scent_distance

				if scent_distance <= scent_reached_threshold: # Ignore this scent in the future if it close enough to it
					ignore_scents.set(scent, null)
					scent.mesh.get_surface_override_material(0).albedo_color = Color.PINK
			else:
				scent.mesh.get_surface_override_material(0).albedo_color = Color.PINK
	if is_instance_valid(closest_scent): closest_scent.mesh.get_surface_override_material(0).albedo_color = Color.RED
	return closest_scent_position

## Flash skin mesh using shader
func flash_mesh() -> void:
	# Get the base material (shared)
	var base_mat: Material = skin.mesh.get_active_material(0)
	# Get the next-pass flash material
	var flash_mat: ShaderMaterial = base_mat.next_pass
	# Flash with tween
	var flash_tween: Tween = get_tree().create_tween()
	flash_tween.tween_property(flash_mat, "shader_parameter/flash", 0.0, .1).from(3.0)

func flash_mesh_repeat(_total_duration: float, flash_amount: int, flash_color: Color) -> void:
	var interval: float = (_total_duration / flash_amount) / 2
	var flash_tween: Tween = get_tree().create_tween()

	var base_mat: Material = skin.mesh.get_active_material(0)
	var flash_mat: ShaderMaterial = base_mat.next_pass
	flash_mat.set_shader_parameter("custom_color", flash_color)

	flash_tween.set_loops(flash_amount)
	flash_tween.tween_property(flash_mat, "shader_parameter/flash", 3.0, 0.0)
	flash_tween.tween_interval(interval)
	flash_tween.tween_property(flash_mat, "shader_parameter/flash", 0.0, 0.0)
	flash_tween.tween_interval(interval)

## TODO: This should go back into Enemy.gd
func take_damage(_direction, _power, _damage) -> void:
	velocity = _direction * _power
	flash_mesh()
	health -= _damage
	if health < 0:
		die()

func on_area_detect_player_body_entered(_player: Player) -> void:
	if current_state == State.PATROL:
		player = _player

		if timer_dash_cooldown.time_left <= 0: # Don't restart if already cooling down
			start_dash_cooldown(dash_initial_cooldown_duration_min, dash_initial_cooldown_duration_max)
		current_state = State.CHASE

func on_area_detect_player_body_exited(_player: Player) -> void:
	pass

func on_timer_chase_quit_timeout() -> void:
	current_state = State.IDLE
