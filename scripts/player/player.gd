class_name Player
extends CharacterBody3D

"""
Variables that start with _ (such as _move_speed) are internal variables that keep track of something at runtime and aren't intended to be edited.
Anything that starts with @export can be modified to change player stats.

Some internal variables have a corresponding @export var which controls their initial value (example: _gravity and gravity_default)
"""

@export_category("Player Settings")
@export_group("Movement")
@export var move_speed_ground: float = 8.0
@export var move_speed_air: float = 8.0
@export var move_speed_sprint: float = 16.0
@export var move_speed_attack: float = 2.5
## Multiplier controlling how quickly the player reaches their intended velocity. Lowering this value will make the character appear more slippery.
@export var acceleration: float = 70
@export var slide_acceleration: float = 2.0
## Multipler controlling how quickly the player mesh rotates to face the forward direction. In a sidescroller, only affects speed the player changes from left to right.
@export var rotation_speed: float = 12.0
var _move_speed: float
var _active_acceleration: float

@export_group("Jump")
@export var jump_power: float = 15
@export var jump_max: int = 2
@export var timer_jump_coyote: Timer
@export_range(0,1,.1) var jump_coyote_time: float = .25
var can_move: bool = true
var is_moving_down: bool = false
var _prev_is_on_floor: bool = true
var _jump_count: int = 0
var _coyote_jump_available: bool = true

@export_group("Gravity & Falling")
## Gravity applied to the player in most cases.
@export var gravity_default: float = -30
## Gravity applied to the player when wall sliding
@export var gravity_wall_slide: float = -2
## How much [code]gravity_wall_slide[/code] increases per frame while wall sliding.
@export var gravity_wall_slide_increment: float = 0.09
## Multiplier controlling how fast gravity is applied. Lower [code]gravity_scale[/code] will accelerate the player to terminal velocity slower. Does not control the max amount of gravity applied.
@export var gravity_scale: float = 1.0
## Fastest real-velocity character can fall. This will continuously limit the max player fall speed.
@export var min_y_velocity: float = -15
## Fastest real-velocity character can rise. If a 1 time impulse (such as jump_power) is applied, this will cap it and the extra power will be discarded.
@export var max_y_velocity: float = INF
var _gravity: float

@export_group("Camera & Mouse")
## NOTE: Most of the camera settings are in player_camera.gd, or the inspector panel of the player's camera in Player.tscn
@export_range(0, 1.0) var mouse_sensitivty: float = 0.25
@export var camera: PlayerCamera
@export var camera_pivot: Node3D
var _last_movement_direction: Vector3 = Vector3.BACK
const MOVE_DIRECTION_THRESHOLD: float = 0.2

@export_group("After Image")
@export var after_image_parent: Node
@export var after_image_spawn_time_max: float = .08
@export var after_image_active: bool = false
var _after_image_spawn_time_count: float 

@export_group("Wall Slide")
@export var wall_push_power: float = 35
@export var wall_jump_power: float = 12.0
## Controls duration after wall jumping that all movement is disabled.
@export var wall_jump_move_disable_duration: float = .1
@export var wall_raycast_top: RayCast3D
@export var wall_raycast_bottom: RayCast3D
## Do not change this variable without a good reason. Controls the range that the wall slide raycast looks for a wall, and needs to fit with the player's capsule collider.
@export var wall_raycast_distance_y: float = .35
@export var timer_wall_slide: Timer
@export var timer_prevent_wall_slide: Timer # Used to prevent wall sliding after move_down out of wallslide
@export var timer_wall_jump_coyote: Timer
@export_range(0.0,1.0,0.05) var wall_jump_coyote_time: float = 0.15
## How long player is unable to wall slide after falling (pressing down) off wall. Does not affecting ability to move, just the ability to lock onto the wall.
@export_range(0.0,1.0,0.05) var prevent_wall_slide_duration: float = 0.2
var _is_wall_sliding: bool = false
var _wall_slide_allowed: bool = true
var _coyote_wall_jump_available: bool = false
## Set each time the player starts wall_slide, remains available to allow for wall jump coyote time
var _wall_slide_normal: Vector3

@export_group("Slide")
var _is_sliding: bool = false

@export_group("Combat")
@export var timer_attack_slow: Timer
@export var area_attack_forward: Area3D
@export var area_attack_down: Area3D
@export var hitbox_forward: CollisionShape3D
@export var hitbox_down1: CollisionShape3D
@export var hitbox_down2: CollisionShape3D
@export var hitbox_down3: CollisionShape3D
@onready var attack_areas: Dictionary[Attack, Area3D] = {Attack.FORWARD: area_attack_forward, Attack.DOWN: area_attack_down}
@export var pogo_power: float = 17
@export var attack_down_power: float = 20
@export var attack_forward_power: float = 10
@export var hitstop_duration: float = 0.15
@export var timer_invulnerable: Timer
@export var invulnerable_duration: float = .7
@export var default_attack_hitstun_duration: float = .5
var _invulnerable: bool = false
var curr_attack_type: Attack
enum Attack {FORWARD, DOWN}

@export_group("Boost & Jump Reset")
@export var jump_reset_target: int = 3
@export var boost_invulnerable_duration: float = 1.0
var _jump_reset_count: int = 0
var _can_boost: bool = true

@export_group("Combo")
@export var combo_max_multiplier: float = 100.0
@export var combo_decay_base_multiplier: float = 10.0
@export var combo_hit_increment: float = 34.0
@export var combo_on_hit_penalty: float = 50.0
@export var combo_level_up_padding: float = 15.0
var _combo: float = 0.0
var _combo_level: float = 1.0
var _combo_max: float = 0.0
var _combo_decay_multiplier: float = 0.0

@export_group("Particles")
@export var dust_particles: GPUParticles3D
@export var jump_dust_particles: GPUParticles3D

@export_group("Components")
@export var player_hurtbox: PlayerHurtbox
@export var _skin: PlayerSkin
@export var input_handler: InputHandler
@export var tracker: Node3D
@export var player_hud: PlayerHUD

@export_group("Scents")
@export var timer_spawn_scent: Timer
@export var scent_scene: PackedScene = load("res://scenes/Scent.tscn")
@export var scent_parent: Node
var scents: Array[Scent] = []

@export_group("Debug")
@export var state_movement_label: Label3D
@export var state_action_label: Label3D

enum State {IDLE, RUN, JUMP, FALL, WALL_SLIDE, SLIDE}
var curr_state: State:
	set(value):
		curr_state = value
		#print_state_change()

func _ready():
	_gravity = gravity_default
	_move_speed = move_speed_ground
	_active_acceleration = acceleration

	timer_jump_coyote.timeout.connect(on_timer_jump_coyote_timeout)
	timer_wall_slide.timeout.connect(on_timer_wall_slide_timeout)
	timer_prevent_wall_slide.timeout.connect(on_timer_prevent_wall_slide_timeout)
	timer_wall_jump_coyote.timeout.connect(on_timer_wall_jump_coyote_timeout)
	timer_attack_slow.timeout.connect(on_timer_attack_slow_timeout)
	timer_spawn_scent.timeout.connect(on_timer_spawn_scent_timeout)
	timer_invulnerable.timeout.connect(on_timer_invulnerable_timeout)

	camera.initialize()

	dust_particles.visible = true
	jump_dust_particles.visible = true

	player_hurtbox.hit.connect(on_player_hurtbox_hit)
	
	area_attack_forward.area_entered.connect(on_attack_area_entered)
	area_attack_down.area_entered.connect(on_attack_area_entered)
	disable_all_hitboxes()

	input_handler.jump_triggered.connect(on_jump_triggered)
	input_handler.attack_triggered.connect(trigger_skin_attack)
	input_handler.slide_triggered.connect(on_slide_triggered)
	input_handler.slide_released.connect(on_slide_released)

	_skin.hitbox_disable_requested.connect(disable_attack_hitbox)

	_combo_max = (_combo_level * combo_max_multiplier)
	_combo_decay_multiplier = combo_decay_base_multiplier
	set_combo_level(0)
	_combo = 0.0

func on_jump_triggered() -> void:
	jump()
	
func on_timer_attack_slow_timeout() -> void:
	move_speed_ground = 8
	move_speed_air = 8
	min_y_velocity = -15

func _input(_event):
	if Input.is_action_just_pressed("left_click"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Input.is_action_just_pressed("escape"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Input.is_action_pressed("scroll_up"):
		camera.zoom_target -= camera.zoom_step
	if Input.is_action_pressed("scroll_down"):
		camera.zoom_target += camera.zoom_step

	if can_move:
		if Input.is_action_just_pressed("sprint"):
			if _can_boost:
				velocity.y = (jump_power * 1.5)
				jump_dust_particles.restart()

				_invulnerable = true
				timer_invulnerable.start(boost_invulnerable_duration)
				_can_boost = false

		if Input.is_action_just_released("sprint"):
			pass
		if Input.is_action_just_pressed("move_down"):
			is_moving_down = true
			reset_from_wall_slide()
			_wall_slide_allowed = false
			timer_prevent_wall_slide.start(prevent_wall_slide_duration)
		if Input.is_action_just_released("move_down"):
			is_moving_down = false

func _process(delta):
	process_after_image(delta)
	process_dust_particles()

func _physics_process(delta: float) -> void:
	var move_direction: Vector3
	if can_move: move_direction = input_handler.move_direction

	move_and_fall(delta, move_direction, move_speed_ground)
	update_character(delta, move_direction)
	process_combo(delta)
	move_and_slide()
	set_state()
	
func move_and_fall(delta: float, move_direction: Vector3, state_move_speed: float) -> void:
	var y_velocity = velocity.y
	velocity.y = 0.0
	velocity = velocity.move_toward(move_direction * state_move_speed, _active_acceleration * delta) # Apply horizontal movement
	velocity.y = clampf((y_velocity + (_gravity * (gravity_scale * delta))), min_y_velocity, max_y_velocity) # Apply vertical movement

	if _prev_is_on_floor != is_on_floor() and not is_on_floor():
		timer_jump_coyote.start(jump_coyote_time)
	_prev_is_on_floor = is_on_floor()

func update_character(delta: float, move_direction: Vector3) -> void:
	camera.update(delta)
	turn_and_skid(move_direction)
	process_wall_slide(move_direction)

func turn_and_skid(move_direction: Vector3) -> void:
	# Ensure that character look direction does not update when there is no input
	if move_direction.length() > MOVE_DIRECTION_THRESHOLD:
		if curr_state == State.RUN:
			# Skid if move direction is not the same as previous
			if move_direction != _last_movement_direction:
				var is_skid_active: bool = _skin.animation_tree.get("parameters/SkidOneShot/active") == true
				# If not already skidding, skid and wait for completion to flip character
				if not is_skid_active:
					_last_movement_direction = move_direction
					_skin.skid()
					await _skin.skid_complete
					flip_skin_horizontal(move_direction)
					return # Return because _last_movement_direction has been set and we do not want to do so again
				# Else cancel previous skid and just flip without a skid
				else:
					_skin.cancel_skid()
					flip_skin_horizontal(move_direction)

		elif curr_state == State.IDLE:
			# Do not flip if currently skidding
			var is_skid_active: bool = _skin.animation_tree.get("parameters/SkidOneShot/active") == true
			if not is_skid_active:
				flip_skin_horizontal(move_direction)

		# If not grounded, never skid
		else:
			flip_skin_horizontal(_last_movement_direction)

		_last_movement_direction = move_direction

func flip_skin_horizontal(_direction: Vector3) -> void:
	# Flip skin on Y-axis to face move direction
	var target_angle: float = Vector3.BACK.signed_angle_to(_direction, Vector3.UP)
	global_rotation.y = target_angle
	_skin.mirror_mesh(_direction.z == 1)

func process_wall_slide(_move_direction: Vector3) -> void:
	if can_wall_slide() and not _is_wall_sliding and _move_direction != Vector3.ZERO and _wall_slide_allowed: # Start wall slide
		_is_wall_sliding = true
		velocity = Vector3.ZERO
		_gravity = gravity_wall_slide
		_jump_count = 0
		_wall_slide_normal = get_wall_normal()
	elif not can_wall_slide() and _is_wall_sliding: # JUST fell off wall
		reset_from_wall_slide()
		_coyote_wall_jump_available = true
		timer_wall_jump_coyote.start(wall_jump_coyote_time)
	elif _is_wall_sliding: # Is actively wall sliding
		_gravity -= gravity_wall_slide_increment

func set_state() -> void:
	var speed: float = abs(velocity.z)
	print(speed)
	# Wall slide
	if _is_wall_sliding:
		if curr_state != State.WALL_SLIDE:
			_skin.wall_slide()
			curr_state = State.WALL_SLIDE

	# Slide
	elif _is_sliding and speed > 1.0:
		if curr_state != State.SLIDE:
			curr_state = State.SLIDE
			_skin.slide()

	# In Air
	elif not is_on_floor():
		_move_speed = move_speed_air

		if velocity.y <= 0:
			if curr_state != State.FALL:
				curr_state = State.FALL
				_skin.fall()
		else:
			if curr_state != State.JUMP:
				curr_state = State.JUMP
				_skin.jump()

	# Grounded
	elif is_on_floor():
		# First frame being grounded again
		# TODO: Maybe heirarchy state for this?
		# TODO: Everytime you set the usual state var it could set a parent one that tracks grounded or not or whatever
		if curr_state != State.RUN or curr_state != State.IDLE or curr_state != State.SLIDE:
			_coyote_jump_available = true
			timer_jump_coyote.stop()
			_jump_count = 0
			_can_boost = true

			# Cancel pogo and disable hitbox
			_skin.canel_attack_down()
			disable_attack_hitbox(Attack.DOWN, true)

		if curr_state == State.FALL or curr_state == State.JUMP:
			_skin.land()

		var ground_speed: float = velocity.length()
		print(ground_speed)
		if ground_speed > 1.0:
			if curr_state != State.RUN:
				curr_state = State.RUN
				_skin.run()
		else:
			if curr_state != State.IDLE:
				on_slide_released() # Stop slide if slowed down too much
				curr_state = State.IDLE
				_skin.idle()

func jump() -> void:
	if is_on_floor() or _coyote_jump_available or (_jump_count < jump_max):
		if _jump_count != 0: # air jumping
			jump_dust_particles.restart()
		_jump_count += 1
		_coyote_jump_available = false
		_skin.jump()
		var _jump_power: float = jump_power

		# Can wall jump if currently wall sliding, or wall jump coyote avaiable AND input is moving away from wall
		if _is_wall_sliding or (_coyote_wall_jump_available and (_last_movement_direction.z == _wall_slide_normal.z)): 
			_coyote_wall_jump_available = false
			_jump_power = wall_jump_power 
			velocity.z += (_wall_slide_normal.z * wall_push_power) # Push off away from wall if sliding
			_last_movement_direction = -_last_movement_direction # Flip direction character is facing
			can_move = false
			timer_wall_slide.start(wall_jump_move_disable_duration)
			_skin.wall_jump()

		velocity.y = _jump_power

func on_timer_jump_coyote_timeout() -> void:
	_coyote_jump_available = false

## Returns true if wall_raycast is colliding, and character is not on floor
func can_wall_slide() -> bool:
	return wall_raycast_top.is_colliding() and wall_raycast_bottom.is_colliding() and not is_on_floor()

func sprint() -> void:
	_move_speed = move_speed_sprint
	_skin.animation_tree.set("parameters/TimeScale/scale", 1.25)

func reset_sprint() -> void:
	# TODO: Check if grounded or air
	_move_speed = move_speed_ground
	_skin.animation_tree.set("parameters/TimeScale/scale", 1.0)

func dash() -> void:
	after_image_active = true
	var raw_input: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var right_direction: Vector3 = camera.global_basis.x
	var move_direction: Vector3 = (right_direction * raw_input.x).normalized()
	velocity += (move_direction * 25)
	velocity.y += 10
	await get_tree().create_timer(.6).timeout
	after_image_active = false

func on_player_hurtbox_hit(_hit_impulse: Vector3) -> void:
	if not _invulnerable:
		_invulnerable = true
		timer_invulnerable.start(invulnerable_duration)

		velocity = _hit_impulse
		camera.apply_shake(.1)
		disable_all_hitboxes()
		_skin.hurt()
		TimeManager.apply_hitstop(hitstop_duration)
		increment_combo(-combo_on_hit_penalty)

func disable_all_hitboxes() -> void:
	disable_attack_hitbox(Attack.FORWARD, true)
	disable_attack_hitbox(Attack.DOWN, true)

func trigger_skin_attack() -> void:
	if _skin.is_attack_available() and not _is_wall_sliding:
		if is_on_floor():
			curr_attack_type = Attack.FORWARD
			_skin.attack()
		else:
			curr_attack_type = Attack.DOWN
			_skin.attack_down()
		_move_speed = move_speed_attack
		camera.apply_shake(.03)
		# min_y_velocity = -4 # More needs to be fixed, specifically how move_speed is used and ground and air speeds
		# timer_attack_slow.start(.5)

func on_attack_area_entered(_intruder: Area3D) -> void: # Could have 1 for each area, doesn't seem necessary rn
	if _intruder.owner is EnemyDummy:
		pogo_bounce()
		return

	var enemy: Enemy = _intruder.owner as Enemy
	if enemy:
		var _direction: Vector3
		var _power: float
		match curr_attack_type:
			Attack.FORWARD: 
				_direction = Vector3.FORWARD * sign(transform.origin - enemy.transform.origin) # Knock away from player
				_power = attack_forward_power
			Attack.DOWN:
				_direction = Vector3.DOWN
				_power = attack_down_power
				update_jump_reset()
				pogo()
		_intruder.owner.take_damage(_direction, _power, 1, default_attack_hitstun_duration) # TODO: Different attack damage in future
		increment_combo(combo_hit_increment)

	elif _intruder.owner is SpikePlatform:
		pogo()
		_intruder.owner.flip()

	elif _intruder.owner is SpinTurret:
		pogo()
		_intruder.owner.spin_out()

	else:
		push_warning("Player attack targeting non-enemy")

func update_jump_reset() -> void:
	_jump_reset_count += 1
	if _jump_reset_count >= jump_reset_target:
		_jump_reset_count = 0
		_jump_count = 1
		_can_boost = true
	player_hud.set_jump_reset_value(_jump_reset_count)

func disable_attack_hitbox(_attack: Attack, _disabled: bool) -> void:
	for hitbox in attack_areas[_attack].get_children():
		hitbox.set_deferred("disabled", _disabled)

func on_timer_wall_slide_timeout() -> void:
	can_move = true

func on_timer_prevent_wall_slide_timeout() -> void:
	_wall_slide_allowed = true

func on_timer_wall_jump_coyote_timeout() -> void:
	_coyote_wall_jump_available = false

func pogo() -> void:
	velocity.y = pogo_power

func pogo_bounce() -> void:
	velocity.y = pogo_power * 2

func create_after_image() -> void:
	var material_after_image: StandardMaterial3D = load("res://materials/material_afterimage.tres")
	var skin_clone: PlayerSkin = _skin.duplicate()
	after_image_parent.add_child(skin_clone)
	skin_clone.animation_tree.active = false

	skin_clone.mesh.set_surface_override_material(0,material_after_image)
	skin_clone.mesh.set_surface_override_material(1,material_after_image)
	skin_clone.mesh.set_surface_override_material(2,material_after_image)
	skin_clone.mesh.set_surface_override_material(3,material_after_image)

	skin_clone.global_position = _skin.mesh.global_position
	skin_clone.global_rotation = _skin.global_rotation

	var lifetime: float = .3
	await get_tree().create_timer(lifetime).timeout
	skin_clone.queue_free()

func process_dust_particles() -> void:
	## TODO: Disable if character is attacking/moving slow
	if not is_equal_approx(velocity.z, 0) and is_on_floor() and abs(velocity.z) > 7:
		dust_particles.emitting = true
	else:
		dust_particles.emitting = false

func process_after_image(delta) -> void:
	if after_image_active:
		_after_image_spawn_time_count += delta
		if _after_image_spawn_time_count >= after_image_spawn_time_max:
			create_after_image()
			_after_image_spawn_time_count = 0

## Reset to normal after wall slide completes
func reset_from_wall_slide() -> void:
	_is_wall_sliding = false
	_gravity = gravity_default

func print_state_change() -> void:
	var text: String
	match curr_state:
		State.IDLE: text = "Idle"
		State.RUN: text = "Run"
		State.FALL: text = "Fall"
		State.WALL_SLIDE: text = "Wall Slide"
		State.JUMP: text = "Jump"
	print("Changed current state to: ", text)

func on_timer_spawn_scent_timeout() -> void:
	spawn_scent()

func spawn_scent() -> void:
	var new_scent = scent_scene.instantiate()
	scent_parent.add_child(new_scent)
	new_scent.global_transform.origin = tracker.global_transform.origin
	scents.push_front(new_scent)

	new_scent.scent_expired.connect(on_scent_expired)

	new_scent.start_despawn(10)

func on_scent_expired(expired_scent: Scent) -> void:
	scents.erase(expired_scent)
	expired_scent.queue_free()

func process_combo(delta: float) -> void:
	if _combo > 0.0:
		_combo = clampf(_combo - (delta * _combo_decay_multiplier), 0, INF)
		if _combo < (_combo_max - 100):
			set_combo_level(-1)

		var combo_offset: float = _combo_max - 100
		var combo_value: float = clampf(((_combo - combo_offset) / 100) * 100, 0, 100)
		player_hud.set_combo_value(combo_value)
		#print("Combo: ", _combo, " --- Combo Max: ", _combo_max, " --- Combo Decay: ", _combo_decay_multiplier, " --- Combo Level: ", _combo_level, " --- combo_value: ", combo_value, " --- combo_offset: ", combo_offset)
	else:
		player_hud.set_combo_value(0)

func increment_combo(_increment: float) -> void:
	_combo = clampf(_combo + _increment, 0, INF)
	if _combo >= _combo_max:
		set_combo_level(1)

func set_combo_level(_step: int) -> void:
	_combo_level += _step
	_combo_max = _combo_level * combo_max_multiplier
	_combo_decay_multiplier = combo_decay_base_multiplier + (_combo_level - 1)
	player_hud.set_combo_level_value(int(_combo_level))

	# When moving UP to a new level, give _combo padding so player doesn't immediately fall out
	if _step > 0:
		_combo += combo_level_up_padding

func on_timer_invulnerable_timeout() -> void:
	_invulnerable = false

func on_slide_triggered() -> void:
	_is_sliding = true
	can_move = false
	var ground_speed: float = velocity.length()
	if ground_speed > (move_speed_ground / 2):
		velocity.z = 12.0 * _last_movement_direction.z
	_active_acceleration = slide_acceleration

func on_slide_released() -> void:
	can_move = true
	_is_sliding = false
	_active_acceleration = acceleration
	_skin.slide_end()