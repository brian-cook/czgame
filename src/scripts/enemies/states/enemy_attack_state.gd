class_name EnemyAttackState
extends EnemyState

var _attack_cooldown: float = 1.0
var _timer: float = 0.0
var _can_attack: bool = true
var _attack_range_buffer: float = 10.0  # Extra distance to prevent state flicker
var _pool_stats: Dictionary
var _distance_squared: float = 0.0
var _attack_range_squared: float = 0.0
var _attack_range_buffer_squared: float = 0.0
var _position_check_interval: float = 0.05  # Check position every 0.05 seconds
var _position_check_timer: float = 0.0
var _last_target_position: Vector2
var _velocity_cache: Vector2 = Vector2.ZERO
var _last_velocity_update: float = 0.0
const VELOCITY_UPDATE_INTERVAL: float = 0.1
var _performance_update_timer: float = 0.0
const PERFORMANCE_UPDATE_INTERVAL: float = 0.5

func enter() -> void:
	_timer = 0.0
	_can_attack = true
	_attack_range_squared = enemy.attack_range * enemy.attack_range
	_attack_range_buffer_squared = (_attack_range_buffer + enemy.attack_range) * (_attack_range_buffer + enemy.attack_range)
	
	# Get pool stats reference
	var pool_manager = get_tree().get_first_node_in_group("pool_manager")
	if pool_manager:
		_pool_stats = pool_manager.get_pool_stats().get("enemy", {})

func physics_update(delta: float) -> void:
	var target = enemy.get_target()
	if not target:
		enemy.state_machine.transition_to("Chase")
		return
		
	_timer += delta
	_position_check_timer += delta
	_performance_update_timer += delta
	
	# Update performance stats less frequently
	if _performance_update_timer >= PERFORMANCE_UPDATE_INTERVAL:
		_performance_update_timer = 0.0
		_update_performance_stats()
	
	# Only update position and velocity periodically
	if _position_check_timer >= _position_check_interval:
		_position_check_timer = 0.0
		_last_target_position = target.global_position
		_distance_squared = enemy.global_position.distance_squared_to(_last_target_position)
		
		# Update velocity less frequently
		if _last_velocity_update >= VELOCITY_UPDATE_INTERVAL:
			_last_velocity_update = 0.0
			var direction = (_last_target_position - enemy.global_position).normalized()
			_velocity_cache = direction * enemy.speed
		
		if _distance_squared > _attack_range_buffer_squared:
			enemy.state_machine.transition_to("Chase")
			return
	
	# Use cached velocity for movement
	enemy.velocity = enemy.velocity.move_toward(_velocity_cache, enemy.acceleration * delta)
	
	# Use cached distance for attack check
	if _can_attack and _distance_squared <= _attack_range_squared:
		_perform_attack()

func _perform_attack() -> void:
	_can_attack = false
	enemy.attack()
	
	# Track attack in pool stats
	if _pool_stats and _pool_stats.has("performance"):
		_pool_stats.performance.attacks += 1
	
	# Use SceneTreeTimer for better performance
	get_tree().create_timer(_attack_cooldown).timeout.connect(
		func(): _can_attack = true,
		CONNECT_ONE_SHOT
	) 

func _update_performance_stats() -> void:
	if _pool_stats and _pool_stats.has("performance"):
		var stats = _pool_stats.performance
		stats.attack_rate = stats.attacks / Time.get_ticks_msec() * 1000.0  # Attacks per second
		stats.average_attack_interval = _timer / max(stats.attacks, 1) 