class_name TestGame
extends Node2D

# Add this at the top of the file to ensure ComfortZone class is available
const ComfortZoneScene := preload("res://src/scenes/zones/comfort_zone.tscn")
const ResourcePickupScene := preload("res://src/scenes/pickups/resource_pickup.tscn")
const ResourcePickupScript := preload("res://src/scripts/resources/resource_pickup.gd")

@onready var player := $Player as BasicPlayer
@onready var health_bar := $UI/HealthBar as ProgressBar
@onready var resource_counter := $UI/ResourceCounter as ResourceCounter

@export_group("Scene References")
@export var enemy_scene: PackedScene
@export var comfort_zone_scene: PackedScene = ComfortZoneScene

@export_group("Spawn Settings")
@export var spawn_radius: float = 800.0
@export var max_enemies: int = 10
@export var initial_enemy_count: int = 5
@export var resource_spawn_interval: float = 2.0
@export var max_resources: int = 50

var _active_enemies: Array[BasicEnemy] = []
var _active_zones: Array[Node] = []  # Changed to Node for now
var _active_resources: Array[Area2D] = []

func _ready() -> void:
	print("Test game ready")
	_setup_input_actions()
	await get_tree().process_frame
	
	if not _verify_nodes():
		return
		
	_setup_game()
	_start_resource_spawning()

func _verify_nodes() -> bool:
	if not player:
		push_error("Player node not found!")
		return false
		
	if not health_bar:
		push_error("Health bar not found!")
		return false
		
	if not enemy_scene:
		push_error("Enemy scene not assigned!")
		return false
		
	if not comfort_zone_scene:
		push_error("Comfort zone scene not assigned!")
		return false
		
	if not resource_counter:
		push_warning("Resource counter not found - resource collection disabled")
		
	return true

func _setup_game() -> void:
	_connect_signals()
	_setup_ui()
	_spawn_initial_enemies()
	_setup_comfort_zone_placement()
	print("Game setup complete")

func _connect_signals() -> void:
	if player:
		player.health_changed.connect(_on_player_health_changed)
		player.died.connect(_on_player_died)
		player.resource_collected.connect(_on_player_resource_collected)

func _setup_ui() -> void:
	if player and health_bar:
		health_bar.max_value = player.max_health
		health_bar.value = player.max_health

func _setup_comfort_zone_placement() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _spawn_initial_enemies() -> void:
	for i in initial_enemy_count:
		_spawn_enemy()

func _spawn_enemy() -> void:
	if not player or _active_enemies.size() >= max_enemies:
		return
		
	var enemy = enemy_scene.instantiate() as BasicEnemy
	if not enemy:
		push_error("Failed to instantiate enemy!")
		return
		
	var spawn_position = _get_random_spawn_position()
	enemy.position = spawn_position
	enemy.enemy_died.connect(_on_enemy_died.bind(enemy))
	add_child(enemy)
	_active_enemies.append(enemy)

func _place_comfort_zone(spawn_pos: Vector2) -> void:
	var zone = comfort_zone_scene.instantiate()
	if not zone or not zone is Area2D:
		push_error("Failed to instantiate comfort zone!")
		return
		
	zone.position = spawn_pos
	add_child(zone)
	_active_zones.append(zone)

func _get_random_spawn_position() -> Vector2:
	if not player:
		return Vector2.ZERO
		
	var angle = randf() * TAU
	return player.position + Vector2.RIGHT.rotated(angle) * spawn_radius

func _on_player_health_changed(new_health: float, _max_health: float) -> void:
	if health_bar:
		health_bar.value = new_health

func _on_player_died() -> void:
	# Add a small delay before reloading
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 1.0
	timer.one_shot = true
	timer.timeout.connect(
		func():
			get_tree().reload_current_scene()
			timer.queue_free()
	)
	timer.start()

func _on_enemy_died(enemy: BasicEnemy) -> void:
	_active_enemies.erase(enemy)
	get_tree().create_timer(2.0).timeout.connect(_spawn_enemy)

func _setup_input_actions() -> void:
	print("Setting up input actions")
	_setup_movement_actions()
	_setup_combat_actions()

func _setup_movement_actions() -> void:
	print("Setting up movement actions")
	var movement_actions = {
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT]
	}
	
	for action_name in movement_actions:
		# Remove existing action if it exists
		if InputMap.has_action(action_name):
			InputMap.erase_action(action_name)
		
		print("Adding input action: ", action_name)
		InputMap.add_action(action_name)
		
		for key in movement_actions[action_name]:
			var event = InputEventKey.new()
			event.keycode = key
			print("Adding key ", key, " to action ", action_name)
			InputMap.action_add_event(action_name, event)

func _setup_combat_actions() -> void:
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
		var event_attack = InputEventMouseButton.new()
		event_attack.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("attack", event_attack)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_RIGHT:
				_place_comfort_zone(get_global_mouse_position()) 

func _start_resource_spawning() -> void:
	var timer = Timer.new()
	timer.wait_time = resource_spawn_interval
	timer.timeout.connect(_spawn_resource)
	add_child(timer)
	timer.start()

func _spawn_resource() -> void:
	if _active_resources.size() >= max_resources:
		return
		
	print("Attempting to spawn resource")  # Debug print
	var resource = ResourcePickupScene.instantiate()
	if not resource:
		push_error("Failed to instantiate resource!")
		return
		
	var spawn_pos = _get_random_spawn_position()
	resource.position = spawn_pos
	
	# Connect to the signal before adding to scene
	if resource.has_signal("collected"):
		print("Connecting resource collected signal")  # Debug print
		resource.collected.connect(
			func(value: float):
				print("Resource collected with value: ", value)  # Debug print
				_on_resource_collected(value)
		)
	
	add_child(resource)
	_active_resources.append(resource)
	print("Resource spawned at: ", spawn_pos)  # Debug print

func _on_resource_collected(value: float) -> void:
	print("Resource collected: ", value)
	# Remove from active resources
	for resource in _active_resources:
		if not is_instance_valid(resource):
			_active_resources.erase(resource)

func _on_player_resource_collected(amount: float) -> void:
	if resource_counter:
		resource_counter.add_resources(amount)
	else:
		print("Resource collected but counter not available: ", amount)
