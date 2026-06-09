extends Node

var sources: Dictionary[Node3D, Array]

# TODO: Memory leak by not cleaning up the sphere also ? 
func create_debug_sphere(_source: Node3D, _spawn_global_position: Vector3, _radius: float=0.1, _height: float=0.2, _color: Color=Color.RED) -> void:
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
	
	add_child(new_mesh)
	new_mesh.global_transform.origin = _spawn_global_position

	if sources.get(_source, null):
		sources[_source].append(new_mesh)
	else:
		sources[_source] = [new_mesh]

func clear_source_debugs(_source: Node3D) -> void:
	for mesh: MeshInstance3D in sources[_source]:
		mesh.queue_free()
	sources[_source] = []
