class_name PlayerHUD extends CanvasLayer

@export var jump_reset_value: Label
@export var combo_level_value: Label
@export var combo_value: ProgressBar

func _ready():
    set_jump_reset_value(0)

func set_jump_reset_value(_value: int) -> void:
    jump_reset_value.text = str(_value)

func set_combo_level_value(_value: int) -> void:
    if _value == 0:
        _value = 1
    combo_level_value.text = "x" + str(_value)

func set_combo_value(_value: float) -> void:
    _value = clampf(_value, 0, 100)
    combo_value.value = _value