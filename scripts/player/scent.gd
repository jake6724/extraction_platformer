class_name Scent extends Node3D

@export var mesh: MeshInstance3D

signal scent_expired

func _ready():
    mesh.get_surface_override_material(0).albedo_color = Color.YELLOW

func start_despawn(scent_despawn_delay: float) -> void:
    await get_tree().create_timer(scent_despawn_delay).timeout
    scent_expired.emit(self)