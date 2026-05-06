class_name PlayerSkin
extends Node3D

@export var animation_tree: AnimationTree
@onready var state_machine : AnimationNodeStateMachinePlayback = animation_tree.get("parameters/StateMachine/playback")
@export var animation_player: AnimationPlayer
@export var weapon: Node3D
@export var mesh_parent: Node3D

@export var mesh: MeshInstance3D

@export var attack_combo_timer: Timer
@export var combo_duration: float = 1
var attack_combo_index: int = 0
var attack_names: Array[String] = ["Attack1OneShot", "Attack2OneShot", "Attack3OneShot"]

var player_is_on_wall: bool

signal hitbox_disable_requested

func _ready():
	animation_tree.active = true
	attack_combo_timer.timeout.connect(on_attack_combo_timer_timeout)
	
	animation_tree.animation_finished.connect(on_animation_tree_animation_finished)

# func _process(delta):
# 	print(state_machine.get_current_node())

func on_animation_tree_animation_finished(_anim_name) -> void:
	# print(_anim_name)
	pass

func mirror_mesh(_value: bool) -> void:
	if _value:
		mesh_parent.scale.z = -1
	else:
		mesh_parent.scale.z = 1

func attack() -> void:
	print("Attack called")
	attack_combo_timer.start(combo_duration)

	print(attack_combo_index)
	var _one_shot_string: String = "parameters/%s/request" % attack_names[attack_combo_index]
	print(_one_shot_string)
	animation_tree[_one_shot_string] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE

	attack_combo_index += 1
	if attack_combo_index > 2:
		attack_combo_index = 0

func attack_down() -> void:
	animation_tree["parameters/AttackDownOneShot/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE

func on_attack_combo_timer_timeout() -> void:
	attack_combo_index = 0

func idle():
	state_machine.travel("Idle")

func run():
	state_machine.travel("Run")

func fall():
	state_machine.travel("Fall")

func jump():
	state_machine.travel("Jump")

# func edge_grab():
# 	state_machine.travel("EdgeGrab")

func wall_slide():
	state_machine.start("WallSlide")

func request_disable_hitbox(_index: int, _disable: bool) -> void:
	hitbox_disable_requested.emit(_index, _disable)
