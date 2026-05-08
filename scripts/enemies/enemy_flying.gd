class_name EnemyFlying extends Enemy

@export var player: Player # TODO: Eventually this should be detected in an area3d
@export var move_indicator: MeshInstance3D
@export var raycast_player_detect: RayCast3D
@export var last_seen_player_position_indicator: MeshInstance3D

var can_spot_player: bool = true
@export var timer_spot_player: Timer
var can_spot_player_cooldown: float = 0.5

var directions: Array[Vector3] = [] # Generated based on num_directions
var num_directions: float = 32.0

var interest: Array[float]
var danger: Array[float]

var danger_raycasts: Array[RayCast3D]

var danger_distance: float = 4

var last_seen_player_position: Vector3
var last_seen_player_position_reached: bool = false
var last_seen_player_position_reached_threshold: float = .5

var ignore_scents: Dictionary[Scent, Variant] = {}


func _ready():
	directions = create_directions(num_directions)
	create_danger_raycasts()

	timer_spot_player.timeout.connect(on_timer_spot_player)

func on_timer_spot_player() -> void:
	can_spot_player = true

func _physics_process(delta):
	var target_point: Vector3
	raycast_player_detect.target_position = to_local(player.tracker.global_transform.origin)
	raycast_player_detect.force_raycast_update()
	
	# TODO: The biggest issue right now is when the enemy wants to reach last seen position, but it is stuck on a wall
	# Atleast with the scents they despawn and its goal changes which can help fix itself. can't do this with LSP
	# Maybe a timer? Or higher avoidance ?


	# Spotted player
	# Follow with steering
	if not raycast_player_detect.is_colliding(): # Only looks for terrain, if not hitting terrain there are no obstacles blocking view
		target_point = player.tracker.global_transform.origin
		last_seen_player_position = player.tracker.global_transform.origin
		last_seen_player_position_reached = false
		last_seen_player_position_indicator.get_surface_override_material(0).albedo_color = Color.GREEN
		ignore_scents.clear()

		# We don't care about any scents that spawned while we could see the player
		for scent in player.scents:
			ignore_scents.set(scent, null)

	# Can't see player, hasn't visited last seen position
	# Move to last seen position with steering

	raycast_player_detect.target_position = to_local(last_seen_player_position)
	raycast_player_detect.force_raycast_update()
	if not last_seen_player_position_reached and not raycast_player_detect.is_colliding():
		target_point = last_seen_player_position
		can_spot_player = false
		timer_spot_player.start(can_spot_player_cooldown)

	# Can't see player, HAS visited last seen position
	# Follow scent trail with steering
	elif player.scents.size() != 0:
		# Follow scent trail
		var closest_scent: Scent
		var closest: float = INF
		for scent in player.scents:
			if is_instance_valid(scent):
				var scent_distance: float = global_transform.origin.distance_to(scent.global_transform.origin)
				if scent not in ignore_scents and scent_distance < closest:
					closest_scent = scent
					closest = scent_distance

				if scent_distance <= 2:
					ignore_scents.set(scent, null)
		
		if closest_scent:
			print("Closest scent: ", closest_scent)
			target_point = closest_scent.global_transform.origin
		else:
			velocity = Vector3.ZERO
			return
	
	# Can't see player, no scent trail
	# Give up and stand still
	else:
		velocity = Vector3.ZERO
		return

	last_seen_player_position_indicator.global_transform.origin = last_seen_player_position

	if global_transform.origin.distance_to(last_seen_player_position) < last_seen_player_position_reached_threshold:
		last_seen_player_position_reached = true
		last_seen_player_position_indicator.get_surface_override_material(0).albedo_color = Color.DARK_GREEN

	interest = get_interest_weights(target_point)
	danger = get_danger_weights()
	
	# Reduce the value of interest directions that have danger
	for i in range(interest.size()):
		interest[i] -= danger[i]

	# Avoidance ? (increase value of interest directions OPPOSITE to those with danger)
	
	for i in range(interest.size()):
		var index: int
		var offset: int = directions.size()/2
		if i < interest.size()/2: 
			index = offset + i
		else: 
			index = directions.size() - i
		interest[index] += danger[i]

	#print("Interest: ", interest)
	#print(danger)

	var move_direction: Vector3 = get_move_direction()

	move_indicator.global_transform.origin = global_transform.origin + (move_direction * 3)

	#print("Move direction: ", move_direction)
	velocity = move_direction * 5

	move_and_slide()

func get_interest_weights(_target_point: Vector3) -> Array[float]:
	var _interest: Array[float]
	_interest.resize(directions.size())
	#print("_interest: ", _interest)
	var direction_to_player: Vector3 = global_transform.origin.direction_to(_target_point)
	for i in range(directions.size()):
		var weight: float = clampf(directions[i].dot(direction_to_player), 0, 1)
		_interest[i] = weight
	return _interest

func get_danger_weights() -> Array[float]:
	var _danger: Array[float]
	_danger.resize(directions.size())

	for i in range(directions.size()):
		if danger_raycasts[i].is_colliding():

			var collision_point: Vector3 = danger_raycasts[i].get_collision_point()
			var distance_to_collision: float = global_transform.origin.distance_to(collision_point)
			var distance_scale: float = distance_to_collision / danger_distance

			_danger[i] = 1.0 - (1 * distance_scale)
		
		else:
			_danger[i] = 0.0



	return _danger

func create_danger_raycasts() -> void:
	for i in range(directions.size()):
		# Create new raycast, position at enemy origin
		var new_raycast: RayCast3D = RayCast3D.new()
		add_child(new_raycast)
		new_raycast.global_transform.origin = global_transform.origin

		# Point and scale out raycast, configure
		new_raycast.target_position = directions[i] * danger_distance
		new_raycast.debug_shape_custom_color = Color.ORANGE_RED
		new_raycast.collision_mask = 4

		danger_raycasts.append(new_raycast)

func get_move_direction() -> Vector3:
	var selected_direction: Vector3 = Vector3.ZERO

	for i in directions.size():
		selected_direction += directions[i] * interest[i]
	selected_direction = selected_direction.normalized()

	return selected_direction

func create_directions(_num_directions: float) -> Array[Vector3]:
	var res: Array[Vector3]
	for i in range(num_directions):
		var angle: float = i * 2 * PI / num_directions
		var _direction: Vector3 = Vector3.UP.rotated(Vector3.RIGHT, angle).normalized()
		res.append(_direction)
		# print(_direction)
		# print(7/2)

	return res

# func normalize_directions(_directions: Array[Vector3]) -> Array[Vector3]:
# 	var res: Array[Vector3]
# 	for i in range(_directions.size()):
# 		res.append(_directions[i].normalized())
# 	return res
