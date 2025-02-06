class_name ObjectPoolManager
extends Node

# Dictionary to store pools for different scene types
var _pools: Dictionary = {}

# Configuration for initial pool sizes and growth settings
const POOL_CONFIG = {
	"enemy": {
		"scene": preload("res://src/scenes/enemies/basic_enemy.tscn"),
		"initial_size": 20,
		"growth_factor": 1.5,  # Multiply pool size by this when expanding
		"max_size": 100,       # Maximum pool size
		"cleanup_threshold": 0.5,  # Clean up when usage drops below this percentage
		"performance_monitor": true  # Enable detailed monitoring
	}
}

var _pool_stats: Dictionary = {}
var _debug_label: Label
var _cleanup_timer: Timer
var _stats_update_timer: float = 0.0
const STATS_UPDATE_INTERVAL: float = 0.5  # Update stats every 0.5 seconds

const MAX_FRAME_SAMPLES = 60  # Track last second of frames at 60fps

# Add to class variables
var _frame_time_sum: float = 0.0
var _last_stats_update: float = 0.0

# Add to class variables
const HISTORY_SAMPLES = 60  # Keep 1 minute of history at 1 sample per second
var _performance_history: Dictionary = {}

# Add to class variables
const TREND_WINDOW_SIZE = 5  # Number of samples for trend calculation
var _rolling_averages: Dictionary = {}

func _ready() -> void:
	add_to_group("pool_manager")
	_initialize_pools()
	_setup_debug_display()
	_setup_cleanup_timer()

func _initialize_pools() -> void:
	for pool_name in POOL_CONFIG:
		var config = POOL_CONFIG[pool_name]
		_create_pool(pool_name, config.scene, config.initial_size)

func _create_pool(pool_name: String, scene: PackedScene, size: int) -> void:
	var pool: Array[Node] = []
	_pool_stats[pool_name] = {
		"total": size,
		"active": 0,
		"expansions": 0,
		"peak_usage": 0,
		"last_cleanup_time": Time.get_ticks_msec(),
		"performance": {
			"activation_time": 0.0,
			"deactivation_time": 0.0,
			"expansion_time": 0.0,
			"cleanup_time": 0.0,
			"frame_times": [],
			"state_changes": 0,
			"attacks": 0,
			"average_frame_time": 0.0,
			"comfort_zone_effects": 0,
			"comfort_zone_time": 0.0,
			"memory_usage": 0.0,
			"attack_rate": 0.0,
			"average_attack_interval": 0.0,
			"state_transition_rate": 0.0,
			"history": {
				"frame_times": [],
				"state_changes": [],
				"attacks": [],
				"comfort_effects": []
			}
		}
	}
	_performance_history[pool_name] = {
		"timestamps": []
	}
	
	for i in size:
		var instance = _create_pooled_instance(scene, pool_name)
		pool.append(instance)
	
	_pools[pool_name] = pool
	print("Created pool: ", pool_name, " with size: ", size)

func _create_pooled_instance(scene: PackedScene, pool_name: String) -> Node:
	var instance = scene.instantiate()
	instance.process_mode = Node.PROCESS_MODE_DISABLED
	instance.set_meta("pool_name", pool_name)  # Track which pool it belongs to
	add_child(instance)
	instance.hide()
	return instance

func get_object(pool_name: String) -> Node:
	if not _pools.has(pool_name):
		push_error("Pool not found: " + pool_name)
		return null
		
	var pool = _pools[pool_name]
	var stats = _pool_stats[pool_name]
	
	# Try to find an inactive object
	for obj in pool:
		if obj.process_mode == Node.PROCESS_MODE_DISABLED:
			_activate_object(obj, stats)
			return obj
	
	# If no inactive objects, try to expand pool
	if stats.total < POOL_CONFIG[pool_name].max_size:
		return _expand_pool(pool_name)
	else:
		push_warning("Pool '%s' has reached maximum size (%d)" % [pool_name, POOL_CONFIG[pool_name].max_size])
		return null

func _activate_object(obj: Node, stats: Dictionary) -> void:
	var start_time = Time.get_ticks_usec()
	
	obj.process_mode = Node.PROCESS_MODE_INHERIT
	obj.show()
	stats.active += 1
	stats.peak_usage = max(stats.peak_usage, stats.active)
	
	var end_time = Time.get_ticks_usec()
	stats.performance.activation_time = (end_time - start_time) / 1000.0  # Convert to ms

func _expand_pool(pool_name: String) -> Node:
	var config = POOL_CONFIG[pool_name]
	var stats = _pool_stats[pool_name]
	var pool = _pools[pool_name]
	
	var growth_size = int(pool.size() * (config.growth_factor - 1))
	growth_size = min(growth_size, config.max_size - stats.total)
	
	print("Expanding pool '%s' by %d objects" % [pool_name, growth_size])
	
	for i in growth_size:
		var new_obj = _create_pooled_instance(config.scene, pool_name)
		pool.append(new_obj)
	
	stats.total += growth_size
	stats.expansions += 1
	
	# Return the first new object
	var obj = pool[-growth_size]
	_activate_object(obj, stats)
	return obj

func return_object(obj: Node, pool_name: String) -> void:
	if not _pools.has(pool_name) or not obj.has_meta("pool_name") or obj.get_meta("pool_name") != pool_name:
		push_error("Invalid object return to pool: " + pool_name)
		return
	
	_deactivate_object(obj)
	_pool_stats[pool_name].active -= 1
	_check_cleanup_needed(pool_name)

func _deactivate_object(obj: Node) -> void:
	obj.process_mode = Node.PROCESS_MODE_DISABLED
	obj.hide()
	# Reset object state
	if obj.has_method("reset"):
		obj.reset()

func _setup_cleanup_timer() -> void:
	_cleanup_timer = Timer.new()
	_cleanup_timer.wait_time = 30.0  # Check every 30 seconds
	_cleanup_timer.timeout.connect(_check_all_pools_cleanup)
	add_child(_cleanup_timer)
	_cleanup_timer.start()

func _check_all_pools_cleanup() -> void:
	for pool_name in _pools.keys():
		_check_cleanup_needed(pool_name)

func _check_cleanup_needed(pool_name: String) -> void:
	var stats = _pool_stats[pool_name]
	var config = POOL_CONFIG[pool_name]
	var pool = _pools[pool_name]
	
	# Only cleanup if usage is below threshold and pool is larger than initial size
	if stats.active / float(stats.total) < config.cleanup_threshold and pool.size() > config.initial_size:
		_cleanup_pool(pool_name)

func _cleanup_pool(pool_name: String) -> void:
	var pool = _pools[pool_name]
	var stats = _pool_stats[pool_name]
	var config = POOL_CONFIG[pool_name]
	
	# Calculate how many objects to remove
	var target_size = max(config.initial_size, int(stats.peak_usage * 1.5))
	var remove_count = pool.size() - target_size
	
	if remove_count <= 0:
		return
	
	print("Cleaning up pool '%s': removing %d objects" % [pool_name, remove_count])
	
	# Remove inactive objects from the end of the pool
	var removed = 0
	for i in range(pool.size() - 1, -1, -1):
		if removed >= remove_count:
			break
			
		var obj = pool[i]
		if obj.process_mode == Node.PROCESS_MODE_DISABLED:
			obj.queue_free()
			pool.remove_at(i)
			removed += 1
	
	stats.total -= removed
	stats.peak_usage = stats.active  # Reset peak usage
	stats.last_cleanup_time = Time.get_ticks_msec()

func get_pool_stats() -> Dictionary:
	return _pool_stats 

func _setup_debug_display() -> void:
	if not OS.is_debug_build():
		return
		
	_debug_label = Label.new()
	_debug_label.position = Vector2(10, 100)
	_debug_label.size = Vector2(200, 100)
	add_child(_debug_label)

func _process(_delta: float) -> void:
	if OS.is_debug_build() and _debug_label:
		var text = "Object Pool Stats:\n"
		for pool_name in _pool_stats:
			var stats = _pool_stats[pool_name]
			if POOL_CONFIG[pool_name].performance_monitor:
				var perf = stats.performance
				var history = perf.history
				
				# Pool status section
				text += "\n%s Pool\n" % [pool_name.capitalize()]
				text += "━━━━━━━━━━━━━━━━━━━━━\n"
				text += "Active/Total: %d/%d\n" % [
					stats.active,
					stats.total
				]
				
				# Performance metrics section
				text += "\nPerformance\n"
				text += "━━━━━━━━━━\n"
				text += "Frame Time: %.2fms\n" % [
					perf.average_frame_time
				]
				text += "Memory: %.1f MB\n" % [
					perf.memory_usage
				]
				
				# Activity metrics section
				text += "\nActivity\n"
				text += "━━━━━━━━\n"
				text += "State Changes: %d (%.1f/s)\n" % [
					perf.state_changes,
					perf.state_transition_rate
				]
				text += "Attacks: %d (%.1f/s)\n" % [
					perf.attacks,
					perf.attack_rate
				]
				text += "Attack Interval: %.2fs\n" % [
					perf.average_attack_interval
				]
				
				# Comfort zone metrics section
				text += "\nComfort Zones\n"
				text += "━━━━━━━━━━━━\n"
				text += "Effects: %d\n" % [
					perf.comfort_zone_effects
				]
				text += "Total Time: %.1fs\n" % [
					perf.comfort_zone_time
				]
				
				# Trends section
				if not history.frame_times.is_empty():
					text += "\nTrends\n"
					text += "━━━━━━\n"
					var frame_trend = _calculate_trend(history.frame_times)
					var attack_trend = _calculate_trend(history.attacks)
					text += "Performance: %s\n" % [_get_trend_indicator(frame_trend)]
					text += "Attack Rate: %s\n" % [_get_trend_indicator(attack_trend)]
				
				text += "\n"  # Add spacing between pools
		
		_debug_label.text = text

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_cleanup_all_pools()

func _cleanup_all_pools() -> void:
	print("Cleaning up all object pools...")
	for pool_name in _pools.keys():
		var pool = _pools[pool_name]
		for obj in pool:
			if is_instance_valid(obj):
				obj.queue_free()
		pool.clear()
	_pools.clear()
	_pool_stats.clear() 

func _physics_process(delta: float) -> void:
	_stats_update_timer += delta
	if _stats_update_timer >= STATS_UPDATE_INTERVAL:
		_stats_update_timer = 0.0
		_update_performance_stats(delta)

func _update_performance_stats(delta: float) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	
	for pool_name in _pools:
		var stats = _pool_stats[pool_name]
		if not POOL_CONFIG[pool_name].performance_monitor:
			continue
			
		# Initialize rolling averages for this pool if needed
		if not _rolling_averages.has(pool_name):
			_rolling_averages[pool_name] = {
				"frame_times": [],
				"attacks": [],
				"state_changes": []
			}
			
		# Update frame times with batch processing
		var frame_time = delta * 1000.0
		_frame_time_sum += frame_time
		var frame_times = stats.performance.frame_times
		
		frame_times.push_back(frame_time)
		if frame_times.size() > MAX_FRAME_SAMPLES:
			_frame_time_sum -= frame_times[0]
			frame_times.pop_front()
		
		# Use cached sum for average
		stats.performance.average_frame_time = _frame_time_sum / frame_times.size()
		
		# Update rates and history
		if current_time - _last_stats_update >= STATS_UPDATE_INTERVAL:
			_last_stats_update = current_time
			var perf = stats.performance
			var history = perf.history
			
			# Update rolling averages
			_update_rolling_average(_rolling_averages[pool_name].frame_times, perf.average_frame_time)
			_update_rolling_average(_rolling_averages[pool_name].attacks, float(perf.attacks))
			_update_rolling_average(_rolling_averages[pool_name].state_changes, float(perf.state_changes))
			
			# Update rates
			perf.state_transition_rate = perf.state_changes / current_time
			perf.memory_usage = stats.total * 0.1
			
			# Update history using rolling averages
			history.frame_times.push_back(_get_rolling_average(_rolling_averages[pool_name].frame_times))
			history.state_changes.push_back(_get_rolling_average(_rolling_averages[pool_name].state_changes))
			history.attacks.push_back(_get_rolling_average(_rolling_averages[pool_name].attacks))
			history.comfort_effects.push_back(perf.comfort_zone_effects)
			
			_performance_history[pool_name].timestamps.push_back(current_time)
			
			# Trim history
			_trim_history(history)
			_trim_history(_performance_history[pool_name])

func _update_rolling_average(values: Array, new_value: float) -> void:
	values.push_back(new_value)
	if values.size() > TREND_WINDOW_SIZE:
		values.pop_front()

func _get_rolling_average(values: Array) -> float:
	if values.is_empty():
		return 0.0
	
	var sum = 0.0
	for value in values:
		sum += value
	return sum / values.size()

func _trim_history(data: Dictionary) -> void:
	var keys = data.keys()
	for key in keys:
		var array = data[key]
		if array is Array and array.size() > HISTORY_SAMPLES:
			array.pop_front()

func _calculate_trend(values: Array) -> float:
	if values.size() < 2:
		return 0.0
	
	# Calculate average of last 5 values (or less)
	var sample_count = min(5, values.size())
	var recent_sum = 0.0
	var start_index = values.size() - sample_count
	
	# Ensure we have valid indices
	if start_index < 0 or start_index >= values.size():
		return 0.0
	
	# Sum the most recent values
	for i in sample_count:
		var index = start_index + i
		if index >= 0 and index < values.size():
			recent_sum += values[index]
	
	var avg_recent = recent_sum / float(sample_count)
	
	# Get first value, ensuring it exists
	var old = 0.0
	if not values.is_empty():
		old = values[0]
	
	# Calculate trend percentage
	return (avg_recent - old) / old if old != 0 else 0.0

func _get_trend_indicator(trend: float) -> String:
	if abs(trend) < 0.05:  # Less than 5% change
		return "→"
	elif trend > 0:
		return "↗ (+%.1f%%)" % (trend * 100)
	else:
		return "↘ (%.1f%%)" % (trend * 100) 
