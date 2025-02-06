@tool  # Add tool to ensure class registration
class_name ResourcePickup
extends Area2D

signal collected(value: float)

@export var base_value: float = 1.0
@export var collection_radius: float = 32.0
@export var move_speed: float = 200.0
@export var acceleration: float = 1000.0

var _current_value: float
var _target: Node2D
var _velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
    print("Resource pickup ready")  # Debug print
    _current_value = base_value
    add_to_group("resources")
    
    # Only setup collision in game, not in editor
    if not Engine.is_editor_hint():
        _setup_collision()
        area_entered.connect(_on_area_entered)

func _setup_collision() -> void:
    if not $CollisionShape2D.shape:
        var shape := CircleShape2D.new()
        shape.radius = collection_radius
        $CollisionShape2D.shape = shape

func _physics_process(delta: float) -> void:
    if Engine.is_editor_hint():
        return
        
    if _target:
        var direction = (_target.global_position - global_position).normalized()
        _velocity = _velocity.move_toward(direction * move_speed, acceleration * delta)
        position += _velocity * delta

func _on_area_entered(area: Area2D) -> void:
    var parent = area.get_parent()
    if parent.is_in_group("players"):
        print("Player entered resource area")  # Debug print
        collected.emit(_current_value)
        queue_free()

func set_value_multiplier(multiplier: float) -> void:
    _current_value = base_value * multiplier

func start_collection(collector: Node2D) -> void:
    print("Starting collection towards: ", collector.name)  # Debug print
    _target = collector
    # Don't emit collected signal here, wait for area collision 