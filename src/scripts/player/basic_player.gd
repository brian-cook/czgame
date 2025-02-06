class_name BasicPlayer
extends CharacterBody2D

# Signals for future extensibility
signal health_changed(new_health: float, max_health: float)
signal died
signal took_damage(amount: float)
signal attack_performed(position: Vector2)
signal resource_collected(amount: float)

# Export variables for easy tuning
@export_group("Movement")
@export var speed: float = 300.0
@export var acceleration: float = 2000.0
@export var friction: float = 1000.0

@export_group("Combat")
@export var max_health: float = 100.0
@export var invincibility_time: float = 0.5
@export var attack_cooldown: float = 0.5
@export var attack_range: float = 50.0

# Private variables
var _current_health: float
var _can_take_damage: bool = true
var _can_attack: bool = true

@onready var state_machine: PlayerStateMachine = $StateMachine

func _ready() -> void:
	print("Player ready")
	add_to_group("players")
	_current_health = max_health
	health_changed.emit(_current_health, max_health)
	
	# Set up resource collector
	var collector = $ResourceCollector
	collector.collision_layer = 2     # Layer 2 for player
	collector.collision_mask = 16     # Layer 5 for resources
	collector.monitoring = true
	collector.monitorable = true
	
	print("ResourceCollector setup - Layer: ", collector.collision_layer, 
		  " Mask: ", collector.collision_mask)
	print("Player position: ", global_position)

	await get_tree().process_frame
	_verify_input_actions()

func _verify_input_actions() -> void:
	var required_actions = ["move_up", "move_down", "move_left", "move_right"]
	for action in required_actions:
		if not InputMap.has_action(action):
			push_error("Required input action missing: " + action)
			# Add debug info
			print("Available actions: ", InputMap.get_actions())
		else:
			print("Input action verified: " + action)

func take_damage(amount: float) -> void:
	if not _can_take_damage:
		return
		
	_current_health = max(0.0, _current_health - amount)
	health_changed.emit(_current_health, max_health)
	took_damage.emit(amount)
	
	if _current_health <= 0:
		die()
	else:
		_start_invincibility()
		state_machine.transition_to("Hurt")

func _start_invincibility() -> void:
	_can_take_damage = false
	# Using a timer for better performance than coroutines
	get_tree().create_timer(invincibility_time).timeout.connect(
		func(): _can_take_damage = true
	)

func die() -> void:
	# Emit signal before freeing
	died.emit()
	# Don't queue_free the player, let the game manager handle scene reload
	set_physics_process(false)  # Stop movement
	visible = false  # Hide player
	# Disable collision
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	$Hurtbox.set_collision_layer_value(1, false)
	$Hurtbox.set_collision_mask_value(1, false)
	$ResourceCollector.set_collision_layer_value(1, false)
	$ResourceCollector.set_collision_mask_value(1, false)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") and _can_attack:
		_perform_attack()

func _perform_attack() -> void:
	_can_attack = false
	
	# Get attack direction (towards mouse)
	var attack_direction = (get_global_mouse_position() - global_position).normalized()
	var attack_position = global_position + (attack_direction * attack_range)
	
	attack_performed.emit(attack_position)
	
	# Start attack cooldown
	get_tree().create_timer(attack_cooldown).timeout.connect(
		func(): _can_attack = true
	)

func _on_resource_collector_area_entered(area: Area2D) -> void:
	print("Player detected area: ", area.name)
	print("Area script: ", area.get_script().get_path() if area.get_script() else "No script")
	
	# Check if area has the resource pickup script
	var script_path = area.get_script().get_path() if area.get_script() else ""
	if script_path.ends_with("resource_pickup.gd"):
		print("Starting resource collection")
		# Connect signal first
		if area.has_signal("collected"):
			area.collected.connect(_on_resource_collected)
		area.start_collection(self)
	else:
		print("Area is not a resource pickup: ", script_path)

func _on_resource_collected(value: float) -> void:
	print("Player collected resource: ", value)
	resource_collected.emit(value)
