class_name BasicPlayer
extends CharacterBody2D

# Signals for future extensibility
signal health_changed(new_health: float, max_health: float)
signal died
signal took_damage(amount: float)
signal resource_collected(amount: float)
signal weapon_fired(position: Vector2, direction: Vector2)

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
@export var fire_rate: float = 2.0  # Shots per second
@export var projectile_damage: float = 10.0
@export var projectile_speed: float = 800.0

# Private variables
var _current_health: float
var _can_take_damage: bool = true
var _using_controller: bool = false
var _aim_direction: Vector2 = Vector2.RIGHT
const CONTROLLER_DEADZONE: float = 0.2

@onready var state_machine: PlayerStateMachine = $StateMachine
@onready var weapon_base: WeaponBase = $WeaponMount/WeaponBase

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
	
	# Set up weapon reference
	weapon_base = $WeaponMount/WeaponBase
	if not weapon_base:
		push_error("WeaponBase not found!")
	else:
		print("WeaponBase found and initialized")

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

func _physics_process(delta: float) -> void:
	# Get movement input
	var input_vector = Input.get_vector(
		"move_left", "move_right",
		"move_up", "move_down"
	)
	
	# Handle movement
	if input_vector != Vector2.ZERO:
		velocity = velocity.move_toward(
			input_vector * speed,
			acceleration * delta
		)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	
	move_and_slide()
	
	# Handle aiming
	_update_aim_direction()

func _update_aim_direction() -> void:
	if weapon_base:
		# Get right stick input
		var aim_vector = Vector2(
			Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
			Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
		)
		
		# Check if using controller based on right stick movement
		if aim_vector.length() > CONTROLLER_DEADZONE:
			_using_controller = true
			_aim_direction = aim_vector.normalized()
			weapon_base.rotation = _aim_direction.angle()
		else:
			# Check if mouse has moved
			var mouse_pos = get_global_mouse_position()
			var to_mouse = mouse_pos - global_position
			if to_mouse.length() > 0:
				_using_controller = false
				weapon_base.look_at(mouse_pos)

func _input(event: InputEvent) -> void:
	# Update controller state based on input type
	if event is InputEventJoypadMotion or event is InputEventJoypadButton:
		_using_controller = true
	elif event is InputEventMouse:
		_using_controller = false

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

func _on_weapon_fired(_weapon: Node2D, firing_position: Vector2) -> void:
	weapon_fired.emit(firing_position, (get_global_mouse_position() - firing_position).normalized())
