@tool
class_name ResourcePickup
extends Area2D

## Signal emitted when resource is collected
signal collected(value: float)

@export_group("Resource Properties")
@export var base_value: float = 1.0
@export var collection_radius: float = 100.0
@export var move_speed: float = 400.0
@export var acceleration: float = 2000.0

var _current_value: float
var _target: Node2D
var _velocity: Vector2 = Vector2.ZERO
var _value_multiplier: float = 1.0
var _is_being_collected: bool = false

func _ready() -> void:
	print("Resource pickup ready at: ", global_position)
	_current_value = base_value
	add_to_group("resources")
	
	# Set up collision
	collision_layer = 16    # Layer 5 for resources
	collision_mask = 2     # Layer 2 for player
	monitoring = true
	monitorable = true
	
	print("Resource collision setup - Layer: ", collision_layer, " Mask: ", collision_mask)
	print("Resource script: ", get_script().get_path())

func _physics_process(delta: float) -> void:
	if not _is_being_collected or not _target:
		return
		
	if not is_instance_valid(_target):
		queue_free()
		return
		
	var direction = (_target.global_position - global_position).normalized()
	_velocity = _velocity.move_toward(direction * move_speed, acceleration * delta)
	position += _velocity * delta
	
	# Check if we're close enough to collect
	if global_position.distance_to(_target.global_position) < 20.0:
		_collect()

func start_collection(collector: Node2D) -> void:
	print("Start collection called by: ", collector.name)
	if not _is_being_collected:
		print("Starting collection by: ", collector.name)
		_is_being_collected = true
		_target = collector

func _collect() -> void:
	if is_instance_valid(self):
		print("Resource collected with value: ", _current_value)
		collected.emit(_current_value)
		queue_free()

func set_value_multiplier(multiplier: float) -> void:
	_value_multiplier = multiplier
	_current_value = base_value * _value_multiplier
	modulate = Color(1.0, 0.8, 0.0) if _value_multiplier == 1.0 else Color(1.0, 1.0, 0.0)  # Visual feedback 
