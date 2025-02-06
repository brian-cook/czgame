class_name ResourceCounter
extends Control

@onready var _label := $Label as Label
@onready var _animation_player := $AnimationPlayer as AnimationPlayer

var _current_resources: float = 0.0

func _ready() -> void:
    _update_display()

func add_resources(amount: float) -> void:
    _current_resources += amount
    _update_display()
    if _animation_player:
        _animation_player.play("collect")

func _update_display() -> void:
    if _label:
        _label.text = "Resources: %d" % _current_resources 