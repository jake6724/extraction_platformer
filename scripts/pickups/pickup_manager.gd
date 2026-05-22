extends Node

var pickup_scenes: Dictionary[Pickup.Type, PackedScene] = {
	Pickup.Type.COIN: load("res://scenes/pickup/Coin.tscn")
}

func spawn_pickups(pickup_type: Pickup.Type, amount: int, spawn_position: Vector3) -> void:
	for i in range(amount):
		var new_pickup = create_pickup(pickup_type)
		spawn_position.x = 0
		new_pickup.global_transform.origin = spawn_position


## Creates and adds pickup child. Returns the pickup object for further configuration
func create_pickup(pickup_type: Pickup.Type) -> Pickup:
	var new_pickup: Pickup = pickup_scenes[pickup_type].instantiate()
	add_child(new_pickup)
	return new_pickup
