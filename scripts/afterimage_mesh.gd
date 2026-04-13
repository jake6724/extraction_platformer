class_name AfterImage
extends SophiaSkin

var lifetime: float = .35

func _ready():
    # transparency = .95
    await get_tree().create_timer(lifetime).timeout
    call_deferred("queue_free")