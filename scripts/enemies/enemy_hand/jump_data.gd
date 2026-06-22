class_name JumpData extends RefCounted

enum Status {SUCCESS, UNDER_ROOF, FALL_CUTOFF, ABOVE_PLATFORM, CLIMB, FAILED_IMPULSE}

var impulse: Vector3
var status: Status
var target_position: Vector3 # X locked
var squared_discriminant