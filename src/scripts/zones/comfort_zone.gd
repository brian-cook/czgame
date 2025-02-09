class_name ComfortZone
extends Area2D

signal zone_state_changed(is_active: bool)

@export_group("Zone Properties")
@export var radius: float = 100.0
@export var enemy_slow_factor: float = 0.5
@export var resource_multiplier: float = 2.0

var _active: bool = false
var _pool_stats: Dictionary
var _affected_enemies: Dictionary = {}  # Track enemies and their entry times
var _affected_resources: Array[ResourcePickup] = []
var _speed_modifiers: Dictionary = {}
const CLEANUP_INTERVAL: float = 5.0  # Cleanup every 5 seconds
var _effect_batch_size: int = 5
var _effect_update_timer: float = 0.0
const EFFECT_UPDATE_INTERVAL: float = 0.1  # Update effects every 0.1 seconds
var _speed_cache: Dictionary = {}
var _last_speed_update: float = 0.0
const SPEED_UPDATE_INTERVAL: float = 0.1

func _ready() -> void:
	add_to_group("comfort_zones")
	_setup_collision_shape()
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	_set_active(true)
	var pool_manager = get_tree().get_first_node_in_group("pool_manager")
	if pool_manager:
		_pool_stats = pool_manager.get_pool_stats().get("enemy", {})

func _setup_collision_shape() -> void:
	var shape := CircleShape2D.new()
	shape.radius = radius
	$CollisionShape2D.shape = shape

func _set_active(value: bool) -> void:
	if _active != value:
		_active = value
		zone_state_changed.emit(_active)
		modulate.a = 1.0 if _active else 0.5  # Visual feedback

func _on_area_entered(area: Area2D) -> void:
	if area.owner is BasicEnemy:
		var enemy = area.owner as BasicEnemy
		if not _affected_enemies.has(enemy):
			_affected_enemies[enemy] = Time.get_ticks_msec()
			if _pool_stats and _pool_stats.has("performance"):
				_pool_stats.performance.comfort_zone_effects += 1
			_apply_speed_modifier(enemy)
	elif area.owner is ResourcePickup:
		print("Resource entered comfort zone")  # Debug print
		_affected_resources.append(area.owner as ResourcePickup)
		_affected_resources[-1].set_value_multiplier(resource_multiplier)

func _on_area_exited(area: Area2D) -> void:
	if area.owner is BasicEnemy:
		var enemy = area.owner as BasicEnemy
		if _affected_enemies.has(enemy):
			var entry_time = _affected_enemies[enemy]
			var duration = (Time.get_ticks_msec() - entry_time) / 1000.0  # Convert to seconds
			if _pool_stats and _pool_stats.has("performance"):
				_pool_stats.performance.comfort_zone_time += duration
			_affected_enemies.erase(enemy)
			_remove_speed_modifier(enemy)
	elif area.owner is ResourcePickup:
		_affected_resources.erase(area.owner as ResourcePickup)
		_affected_resources[-1].set_value_multiplier(1.0)
	
	if _affected_enemies.is_empty() and _affected_resources.is_empty():
		_set_active(false)

func _physics_process(delta: float) -> void:
	_effect_update_timer += delta
	
	# Batch process effects
	if _effect_update_timer >= EFFECT_UPDATE_INTERVAL:
		_effect_update_timer = 0.0
		_update_effects()
		_cleanup_invalid_references()

func _update_effects() -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - _last_speed_update >= SPEED_UPDATE_INTERVAL:
		_last_speed_update = current_time
		var processed = 0
		
		for enemy in _affected_enemies.keys():
			if processed >= _effect_batch_size:
				break
				
			if is_instance_valid(enemy):
				# Cache and update speed only if changed
				var current_speed = enemy.speed
				if not _speed_cache.has(enemy) or _speed_cache[enemy] != current_speed:
					_speed_cache[enemy] = current_speed
					_apply_speed_modifier(enemy)
				processed += 1

func _cleanup_invalid_references() -> void:
	var to_remove = []
	for enemy in _affected_enemies.keys():
		if not is_instance_valid(enemy):
			to_remove.append(enemy)
	
	for enemy in to_remove:
		_affected_enemies.erase(enemy)
		_speed_modifiers.erase(enemy)
		_speed_cache.erase(enemy)

func _apply_speed_modifier(enemy: BasicEnemy) -> void:
	if not _speed_modifiers.has(enemy):
		_speed_modifiers[enemy] = enemy.speed
		enemy.speed *= enemy_slow_factor

func _remove_speed_modifier(enemy: BasicEnemy) -> void:
	if _speed_modifiers.has(enemy):
		enemy.speed = _speed_modifiers[enemy]
		_speed_modifiers.erase(enemy) 
