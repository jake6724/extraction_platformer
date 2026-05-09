class_name Enemy
extends CharacterBody3D

@export var mesh: MeshInstance3D
@export var area_attack: Area3D
var attack_power: float = 15.0
var base_color: Color
@export var gravity_default: float = -30

func _ready():
	base_color = mesh.get_active_material(0).albedo_color
	print(base_color)
	area_attack.area_entered.connect(on_area_attack_area_entered)

func _physics_process(delta):
	velocity = velocity.move_toward(Vector3.ZERO, delta * 30)
	velocity.x = 0
	move_and_slide()

## Attack
func on_area_attack_area_entered(_player_hurtbox: PlayerHurtbox) -> void: 
	if _player_hurtbox:
		_player_hurtbox.take_damage(global_position, attack_power)
		
func take_damage(_direction, _power) -> void:
	velocity = _direction * _power
	flash_mesh()

func flash_mesh() -> void:
	var flash_tween: Tween = get_tree().create_tween()
	var mesh_material: StandardMaterial3D = mesh.get_active_material(0)
	flash_tween.tween_property(mesh_material, "albedo_color", base_color, .25).from(Color.YELLOW)
