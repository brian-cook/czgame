class_name TestGame
extends Node2D

# Add this at the top of the file to ensure ComfortZone class is available
const ComfortZoneScene := preload("res://src/scenes/zones/comfort_zone.tscn")
const ResourcePickupScene := preload("res://src/scenes/pickups/resource_pickup.tscn")
const ResourcePickupScript := preload("res://src/scripts/resources/resource_pickup.gd")

@onready var player := $Player as BasicPlayer
@onready var health_bar := $UI/HealthBar as ProgressBar
@onready var resource_counter := $UI/ResourceCounter as ResourceCounter
@onready var object_pool_manager: ObjectPoolManager = $ObjectPoolManager
@onready var enemy_spawn_manager: EnemySpawnManager = $EnemySpawnManager
@onready var wave_indicator := $UI/WaveIndicator as WaveIndicator

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
var _current_zone: ComfortZone = null  # Instead of _active_zones array
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
	_setup_spawn_manager()
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

func _setup_spawn_manager() -> void:
	if enemy_spawn_manager:
		enemy_spawn_manager.initialize(object_pool_manager, player, wave_indicator)
		enemy_spawn_manager.wave_started.connect(_on_wave_started)
		enemy_spawn_manager.wave_completed.connect(_on_wave_completed)
		enemy_spawn_manager.start_next_wave()

func _setup_comfort_zone_placement() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _spawn_initial_enemies() -> void:
	for i in initial_enemy_count:
		_spawn_enemy()

func _spawn_enemy() -> void:
	if not player or _active_enemies.size() >= max_enemies:
		return
		
	var enemy = object_pool_manager.get_object("enemy") as BasicEnemy
	if enemy:
		enemy.initialize(_get_random_spawn_position())
		enemy.enemy_died.connect(
			func(): _on_enemy_died(enemy)
		)
		_active_enemies.append(enemy)  # Add to active enemies list

func _place_comfort_zone(spawn_pos: Vector2) -> void:
	# Remove existing zone if it exists
	if _current_zone and is_instance_valid(_current_zone):
		_current_zone.queue_free()
	
	print("Placing comfort zone at: ", spawn_pos)  # Debug print
	var zone = ComfortZoneScene.instantiate()
	if not zone:
		push_error("Failed to instantiate comfort zone!")
		return
		
	zone.position = spawn_pos
	add_child(zone)
	_current_zone = zone

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

func _on_enemy_died(enemy: Node) -> void:
	_active_enemies.erase(enemy)  # Remove from active enemies list
	object_pool_manager.return_object(enemy, "enemy")
	
	# Spawn new enemy after delay
	get_tree().create_timer(2.0).timeout.connect(_spawn_enemy)

func _setup_input_actions() -> void:
	print("Setting up input actions")
	_setup_movement_actions()
	_setup_combat_actions()
	_setup_zone_actions()

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

func _setup_zone_actions() -> void:
	if not InputMap.has_action("place_zone"):
		InputMap.add_action("place_zone")
		var event = InputEventKey.new()
		event.keycode = KEY_SPACE
		InputMap.action_add_event("place_zone", event)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("place_zone"):
		# Place zone at player position instead of mouse position
		if player:
			_place_comfort_zone(player.global_position)

func _start_resource_spawning() -> void:
	var timer = Timer.new()
	timer.wait_time = resource_spawn_interval
	timer.timeout.connect(_spawn_resource)
	add_child(timer)
	timer.start()

func _spawn_resource() -> void:
	if _active_resources.size() >= max_resources:
		return
		
	print("Attempting to spawn resource")
	var resource = ResourcePickupScene.instantiate()
	if not resource:
		push_error("Failed to instantiate resource!")
		return
		
	var spawn_pos = _get_random_spawn_position()
	resource.position = spawn_pos
	
	# Verify script is attached
	if not resource.get_script():
		push_error("Resource script not attached! Check if script is properly attached in resource_pickup.tscn")
		return
		
	add_child(resource)
	_active_resources.append(resource)
	print("Resource spawned at: ", spawn_pos)

func _on_resource_collected(value: float) -> void:
	print("Resource collected: ", value)
	# Remove from active resources
	for resource in _active_resources:
		if not is_instance_valid(resource):
			_active_resources.erase(resource)
	
	# Update counter
	if resource_counter:
		resource_counter.add_resources(value)
		print("Updated resource counter: ", value)  # Debug print
	else:
		push_error("Resource counter not found!")

func _on_player_resource_collected(amount: float) -> void:
	if resource_counter:
		resource_counter.add_resources(amount)
		print("Player collected resource: ", amount)  # Debug print
	else:
		push_error("Resource counter not found!")

func _on_wave_started(wave_number: int) -> void:
	print("Wave ", wave_number, " started!")
	# TODO: Update UI

func _on_wave_completed(wave_number: int) -> void:
	print("Wave ", wave_number, " completed!")
	# TODO: Update UI
