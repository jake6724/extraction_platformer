class_name Scent extends Node3D


signal scent_expired

func start_despawn(scent_despawn_delay: float) -> void:
    await get_tree().create_timer(scent_despawn_delay).timeout
    scent_expired.emit(self)