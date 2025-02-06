class_name ComfortZone
extends Area2D

signal zone_state_changed(is_active: bool)

@export_group("Zone Properties")
@export var radius: float = 100.0
@export var enemy_slow_factor: float = 0.5
@export var resource_multiplier: float = 2.0

var _active: bool = false
var _affected_enemies: Array[BasicEnemy] = []

func _ready() -> void:
    add_to_group("comfort_zones")
    _setup_collision_shape()
    area_entered.connect(_on_area_entered)
    area_exited.connect(_on_area_exited)
    _set_active(true)

func _setup_collision_shape() -> void:
    var shape := CircleShape2D.new()
    shape.radius = radius
    $CollisionShape2D.shape = shape

func _set_active(value: bool) -> void:
    if _active != value:
        _active = value
        zone_state_changed.emit(_active)

func _on_area_entered(area: Area2D) -> void:
    var parent = area.get_parent()
    if parent is BasicEnemy:
        _affected_enemies.append(parent)
        parent.speed *= enemy_slow_factor
        _set_active(true)

func _on_area_exited(area: Area2D) -> void:
    var parent = area.get_parent()
    if parent is BasicEnemy:
        _affected_enemies.erase(parent)
        parent.speed /= enemy_slow_factor
        if _affected_enemies.is_empty():
            _set_active(false) 