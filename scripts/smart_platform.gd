class_name SmartPlatform extends CSGBox3D

@export var show_debug: bool = true

var left_edge_point: Vector3
var right_edge_point: Vector3
var y_margin: float = 0.5
var z_margin: float = 1.0

func _ready():
	calc_edge_points()

func calc_edge_points() -> void:
	var y_offset: float = (size.y / 2) + y_margin
	var z_offset: float = (size.z / 2) - z_margin

	var center_top: Vector3 = global_transform.origin + Vector3(0,y_offset,0)
	left_edge_point = center_top + Vector3(0,0,z_offset)
	right_edge_point = center_top - Vector3(0,0,z_offset)

	if show_debug:
		DebugTools.create_debug_sphere(self, left_edge_point, .4, .8, Color.RED)
		DebugTools.create_debug_sphere(self, right_edge_point, .4, .8, Color.BLUE)