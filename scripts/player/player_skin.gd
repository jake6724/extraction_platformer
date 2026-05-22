class_name PlayerSkin
extends Node3D

@export var animation_tree: AnimationTree
@onready var state_machine : AnimationNodeStateMachinePlayback = animation_tree.get("parameters/StateMachine/playback")
@export var animation_player: AnimationPlayer
@export var weapon: Chainsaw
@export var mesh_parent: Node3D

@export var mesh: MeshInstance3D

@export var attack_combo_timer: Timer
@export var combo_duration: float = 1
var attack_combo_index: int = 0
var attack_names: Array[String] = ["Attack1OneShot", "Attack2OneShot", "Attack3OneShot"]

var player_is_on_wall: bool

var curr_skid_direction: Vector3

signal hitbox_disable_requested
signal skid_complete(skid_direction: Vector3)

func _ready():
	animation_tree.active = true
	attack_combo_timer.timeout.connect(on_attack_combo_timer_timeout)
	
	animation_tree.animation_finished.connect(on_animation_tree_animation_finished)

# func _process(delta):
# 	print(state_machine.get_current_node())

func on_skid_complete() -> void:
	skid_complete.emit(curr_skid_direction)

func on_animation_tree_animation_finished(_anim_name) -> void:
	# print(_anim_name)
	pass

func mirror_mesh(_value: bool) -> void:
	if _value:
		mesh_parent.scale.z = -1
	else:
		mesh_parent.scale.z = 1

func is_attack_available() -> bool:
	var res: bool = true
	if animation_tree["parameters/AttackDownOneShot/active"]: res = false
	for attack_name in attack_names:
		var _one_shot_string: String = "parameters/%s/active" % attack_name
		if animation_tree[_one_shot_string]: res = false

	return res

func attack() -> void:
	# print("Attack called")
	attack_combo_timer.start(combo_duration)

	# print(attack_combo_index)
	var _one_shot_string: String = "parameters/%s/request" % attack_names[attack_combo_index]
	# print(_one_shot_string)
	animation_tree[_one_shot_string] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE

	attack_combo_index += 1
	if attack_combo_index > 2:
		attack_combo_index = 0

func attack_down() -> void:
	animation_tree["parameters/AttackDownOneShot/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE

func canel_attack_down() -> void:
	animation_tree["parameters/AttackDownOneShot/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT

func cancel_attacks() -> void:
	animation_tree["parameters/AttackDownOneShot/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT
	animation_tree["parameters/Attack1OneShot/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT
	animation_tree["parameters/Attack2OneShot/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT
	animation_tree["parameters/Attack3OneShot/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT

func on_attack_combo_timer_timeout() -> void:
	attack_combo_index = 0

func hurt(): 
	cancel_attacks()
	animation_tree["parameters/HurtOneShot/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE

func land():
	weapon.particles_sparks.emitting = false
	animation_tree["parameters/LandOneShot/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE

func wall_jump(): 
	animation_tree["parameters/WallJumpOneShot/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE

func skid(): 
	animation_tree["parameters/SkidOneShot/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT
	animation_tree["parameters/SkidOneShot/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE

func cancel_skid() -> void:
	animation_tree["parameters/SkidOneShot/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT

func idle():
	state_machine.travel("Idle")

func run():
	# Cancel land animation just in case
	animation_tree["parameters/LandOneShot/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT
	state_machine.travel("Run2")

func fall():
	weapon.particles_sparks.emitting = false
	state_machine.travel("Fall")

func jump():
	weapon.particles_sparks.emitting = false
	state_machine.travel("Jump")

func wall_slide():
	weapon.particles_sparks.emitting = true
	state_machine.start("WallSlide")

func request_disable_hitbox(_attack: Player.Attack, _disable: bool) -> void:
	hitbox_disable_requested.emit(_attack, _disable)
