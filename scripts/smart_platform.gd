class_name SmartPlatform extends CSGBox3D

@export var show_debug: bool = true

var left_edge_point: Vector3
var right_edge_point: Vector3
var left_edge: Node3D = Node3D.new()
var right_edge: Node3D = Node3D.new()
var y_margin: float = 0.5
var z_margin: float = 1.0

enum Edge {LEFT, RIGHT}

@onready var edges: Dictionary[Edge, Node3D] = {Edge.LEFT: left_edge, Edge.RIGHT: right_edge}

func _ready():
	add_child(left_edge)
	add_child(right_edge)
	calc_edge_points()

func calc_edge_points() -> void:
	var y_offset: float = (size.y / 2) + y_margin
	var z_offset: float = (size.z / 2) - z_margin

	var center_top: Vector3 = global_transform.origin + Vector3(0,y_offset,0)
	left_edge_point = center_top + Vector3(0,0,z_offset)
	right_edge_point = center_top - Vector3(0,0,z_offset)

	left_edge.global_transform.origin = left_edge_point
	right_edge.global_transform.origin = right_edge_point

	if show_debug:
		DebugTools.create_debug_sphere(self, left_edge_point, .4, .8, Color.RED)
		DebugTools.create_debug_sphere(self, right_edge_point, .4, .8, Color.BLUE)
