class_name EnemyFlying extends Enemy

@export var player: Player # TODO: Eventually this should be detected in an area3d
@export_group("Stats")
@export var acceleration = 30
@export var speed = 8
@export_group("Components")
@export var raycast_detect_top: RayCast3D
@export var raycast_detect_center: RayCast3D
@export var raycast_detect_bottom: RayCast3D
@export_group("Debug")
@export var show_debug: bool = false
@export var move_indicator: MeshInstance3D
@export var last_seen_player_position_indicator: MeshInstance3D

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

func _physics_process(delta):
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
	velocity = velocity.move_toward(move_direction * speed, delta * acceleration)
	velocity.x = 0

	move_and_slide()

	# Update debug indicators
	move_indicator.global_transform.origin = global_transform.origin + (velocity.normalized() * 2)
	last_seen_player_position_indicator.global_transform.origin = last_seen_player_position
	if global_transform.origin.distance_to(last_seen_player_position) < last_seen_player_position_reached_threshold:
		last_seen_player_position_reached = true
		last_seen_player_position_indicator.get_surface_override_material(0).albedo_color = Color.DARK_GREEN

	print(ignore_scents.size())

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
		_move_target_point = last_seen_player_position

	# Cannot see player, HAS visited LSP, OR cannot see LSP. Follow scent trail
	elif player.scents.size() != 0:
		# Set debug values
		last_seen_player_position_reached = true
		last_seen_player_position_indicator.get_surface_override_material(0).albedo_color = Color.PALE_GREEN

		# Find closest scent position and follow
		_move_target_point = get_closest_scent_position(player)
	
	# Can't see player, no scent trail. Return empty Vector3
	else:
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
