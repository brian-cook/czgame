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
		"performance_monitor": true,  # Enable detailed monitoring
		"cleanup_interval": 30.0,  # Seconds between cleanup checks
		"batch_processing": true,
		"batch_size": 5,          # Number of objects to process per frame
		"memory_threshold": 0.8,   # Trigger cleanup at 80% memory usage
		"inactive_timeout": 60.0   # Seconds before inactive objects are cleaned up
	},
	"projectile": {
		"scene": preload("res://src/scenes/projectiles/projectile.tscn"),
		"initial_size": 50,
		"growth_factor": 1.5,
		"max_size": 200,
		"cleanup_threshold": 0.5,
		"performance_monitor": true,
		"cleanup_interval": 30.0,
		"batch_processing": true,
		"batch_size": 10,
		"memory_threshold": 0.8,
		"inactive_timeout": 30.0,
		"process_priority": 1  # Higher priority for projectiles
	}
}

var _pool_stats: Dictionary = {}
var _debug_label: Label
var _cleanup_timer: Timer

# Add to class variables
var _frame_time_sum: float = 0.0

# Add to class variables
const HISTORY_SAMPLES = 60  # Keep 1 minute of history at 1 sample per second
var _performance_history: Dictionary = {}

# Add to class variables
const TREND_WINDOW_SIZE = 5  # Number of samples for trend calculation
var _rolling_averages: Dictionary = {}

# Add memory tracking
var _memory_tracker := {
	"last_check_time": 0.0,
	"check_interval": 5.0,  # Check memory every 5 seconds
	"peak_usage": 0,
	"cleanup_triggered": false
}

# Add batch processing queues
var _activation_queue: Array[Dictionary] = []
var _deactivation_queue: Array[Dictionary] = []

# Add back the frame samples constant
const MAX_FRAME_SAMPLES = 60  # Track last second of frames at 60fps

# Add new performance tracking variables
var _last_process_time: float = 0.0
var _frame_counter: int = 0
const FRAMES_BETWEEN_UPDATES = 30  # Update stats every 30 frames

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
	
	# Batch create instances
	print("Creating pool: ", pool_name, " with size: ", size)
	
	# Create instances in smaller batches to avoid frame spikes
	var batch_size = 5
	for i in range(0, size, batch_size):
		var current_batch = min(batch_size, size - i)
		for j in current_batch:
			var instance = _create_pooled_instance(scene, pool_name)
			pool.append(instance)
		await get_tree().process_frame  # Allow frame to complete
	
	_pools[pool_name] = pool
	print("Pool creation complete: ", pool_name)

func _create_pooled_instance(scene: PackedScene, pool_name: String) -> Node:
	var instance = scene.instantiate()
	instance.process_mode = Node.PROCESS_MODE_DISABLED
	instance.set_meta("pool_name", pool_name)
	add_child(instance)
	instance.hide()
	print("Created pooled instance for: ", pool_name)
	return instance

func get_object(pool_name: String) -> Node:
	if not _pools.has(pool_name):
		push_error("Pool not found: " + pool_name)
		return null
		
	var pool = _pools[pool_name]
	var stats = _pool_stats[pool_name]
	
	print("Looking for inactive object in pool:", pool_name)
	# Try to find an inactive object
	for obj in pool:
		if obj.process_mode == Node.PROCESS_MODE_DISABLED:
			print("Found inactive object in pool:", pool_name)
			
			# Update stats before activating
			stats.active += 1
			stats.peak_usage = max(stats.peak_usage, stats.active)
			
			obj.process_mode = Node.PROCESS_MODE_INHERIT
			_activate_object_internal(obj, stats)
			return obj
	
	print("No inactive objects found in pool:", pool_name)
	# If no inactive objects, try to expand pool
	if stats.total < POOL_CONFIG[pool_name].max_size:
		return _expand_pool(pool_name)
	else:
		push_warning("Pool '%s' has reached maximum size (%d)" % [pool_name, POOL_CONFIG[pool_name].max_size])
		return null

func _activate_object_internal(obj: Node, stats: Dictionary) -> void:
	var start_time = Time.get_ticks_usec()
	
	obj.process_mode = Node.PROCESS_MODE_INHERIT
	obj.show()
	obj.set_meta("last_use_time", Time.get_ticks_msec() / 1000.0)
	stats.active += 1
	stats.peak_usage = max(stats.peak_usage, stats.active)
	
	var end_time = Time.get_ticks_usec()
	stats.performance.activation_time = (end_time - start_time) / 1000.0

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
	_activate_object_internal(obj, stats)
	return obj

func return_object(obj: Node, pool_name: String) -> void:
	if not _pools.has(pool_name) or not obj.has_meta("pool_name") or obj.get_meta("pool_name") != pool_name:
		push_error("Invalid object return to pool: " + pool_name)
		return
	
	var stats = _pool_stats[pool_name]
	
	# Update stats first
	stats.active = max(0, stats.active - 1)
	
	# Use call_deferred to avoid physics callback issues
	if obj is CollisionObject2D:
		obj.call_deferred("set_process_mode", Node.PROCESS_MODE_DISABLED)
		obj.call_deferred("hide")
	else:
		obj.process_mode = Node.PROCESS_MODE_DISABLED
		obj.hide()
	
	# Reset object state
	if obj.has_method("reset"):
		obj.call_deferred("reset")
	
	# Sync stats after object return
	call_deferred("_sync_pool_stats", pool_name)

func _deactivate_object_internal(obj: Node, pool_name: String) -> void:
	var stats = _pool_stats[pool_name]
	var start_time = Time.get_ticks_usec()
	
	obj.process_mode = Node.PROCESS_MODE_DISABLED
	obj.hide()
	obj.set_meta("last_use_time", Time.get_ticks_msec() / 1000.0)
	
	# Reset object state
	if obj.has_method("reset"):
		obj.reset()
	
	stats.active -= 1
	
	var end_time = Time.get_ticks_usec()
	stats.performance.deactivation_time = (end_time - start_time) / 1000.0
	
	_check_cleanup_needed(pool_name)

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
	
	var cleanup_start = Time.get_ticks_usec()
	var initial_count = pool.size()
	
	# Calculate target size based on peak usage
	var target_size = max(config.initial_size, int(stats.peak_usage * 1.2))
	var remove_count = pool.size() - target_size
	
	if remove_count <= 0:
		return
	
	# Remove inactive objects
	var removed = 0
	for i in range(pool.size() - 1, -1, -1):
		if removed >= remove_count:
			break
			
		var obj = pool[i]
		if obj.process_mode == Node.PROCESS_MODE_DISABLED:
			pool.remove_at(i)
			obj.queue_free()
			removed += 1
	
	stats.total -= removed
	
	var cleanup_time = (Time.get_ticks_usec() - cleanup_start) / 1000.0
	stats.performance.cleanup_time = cleanup_time
	
	print("Regular cleanup for pool '%s': Removed %d/%d objects in %.2fms" % 
		[pool_name, removed, initial_count, cleanup_time])

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
	_process_queues()
	
	# Update performance tracking
	_frame_counter += 1
	if _frame_counter >= FRAMES_BETWEEN_UPDATES:
		_frame_counter = 0
		_update_memory_tracking()
		_update_performance_stats(delta)

func _process_queues() -> void:
	var batch_size = POOL_CONFIG.enemy.batch_size
	var processed = 0
	var batch_start = Time.get_ticks_usec()
	
	# Process activation queue with time limit
	while not _activation_queue.is_empty() and processed < batch_size:
		var item = _activation_queue.pop_front()
		_activate_object_internal(item.object, item.stats)
		processed += 1
		
		# Check if we're taking too long
		if (Time.get_ticks_usec() - batch_start) / 1000.0 > 2.0:  # 2ms time limit
			break
	
	# Process deactivation queue with time limit
	while not _deactivation_queue.is_empty() and processed < batch_size * 2:  # Allow more deactivations
		var item = _deactivation_queue.pop_front()
		_deactivate_object_internal(item.object, item.pool_name)
		processed += 1
		
		# Check if we're taking too long
		if (Time.get_ticks_usec() - batch_start) / 1000.0 > 4.0:  # 4ms time limit
			break

func _update_memory_tracking() -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - _memory_tracker.last_check_time < _memory_tracker.check_interval:
		return
		
	_memory_tracker.last_check_time = current_time
	
	# Get memory usage more efficiently
	var memory_stats = {
		"static": Performance.get_monitor(Performance.MEMORY_STATIC),
		"max": Performance.get_monitor(Performance.MEMORY_STATIC_MAX)
	}
	
	var usage_ratio = float(memory_stats.static) / float(memory_stats.max) if memory_stats.max > 0 else 0.0
	_memory_tracker.peak_usage = max(_memory_tracker.peak_usage, usage_ratio)
	
	# Update pool stats with more accurate memory estimation
	for pool_name in _pools:
		var stats = _pool_stats[pool_name]
		var active_pool = _pools[pool_name]
		
		# Count active objects manually instead of using count()
		var active_count = 0
		var inactive_count = 0
		for obj in active_pool:
			if obj.process_mode == Node.PROCESS_MODE_INHERIT:
				active_count += 1
			else:
				inactive_count += 1
		
		# Estimate memory (active objects use more memory than inactive ones)
		var active_mem = active_count * 0.15  # 150KB per active object
		var inactive_mem = inactive_count * 0.05  # 50KB per inactive object
		stats.performance.memory_usage = active_mem + inactive_mem
	
	# Trigger cleanup if needed
	if usage_ratio > POOL_CONFIG.enemy.memory_threshold and not _memory_tracker.cleanup_triggered:
		_memory_tracker.cleanup_triggered = true
		_force_cleanup()
	elif usage_ratio < POOL_CONFIG.enemy.memory_threshold * 0.7:  # Add more hysteresis
		_memory_tracker.cleanup_triggered = false

func _force_cleanup() -> void:
	print("Forcing pool cleanup due to high memory usage")
	for pool_name in _pools.keys():
		_aggressive_cleanup(pool_name)

func _aggressive_cleanup(pool_name: String) -> void:
	var pool = _pools[pool_name]
	var stats = _pool_stats[pool_name]
	var config = POOL_CONFIG[pool_name]
	
	# Keep track of cleanup metrics
	var cleanup_start = Time.get_ticks_usec()
	var initial_count = pool.size()
	
	# Sort objects by last use time
	var inactive_objects = []
	for obj in pool:
		if obj.process_mode == Node.PROCESS_MODE_DISABLED:
			if not obj.has_meta("last_use_time"):
				obj.set_meta("last_use_time", 0.0)
			inactive_objects.append(obj)
	
	inactive_objects.sort_custom(
		func(a, b): return a.get_meta("last_use_time") < b.get_meta("last_use_time")
	)
	
	# Calculate how many objects to remove
	var target_size = max(config.initial_size, stats.peak_usage + config.initial_size / 2)
	var remove_count = pool.size() - target_size
	remove_count = max(0, remove_count)
	
	# Remove oldest inactive objects
	var removed = 0
	for obj in inactive_objects:
		if removed >= remove_count:
			break
			
		var last_use_time = obj.get_meta("last_use_time")
		var current_time = Time.get_ticks_msec() / 1000.0
		
		if current_time - last_use_time > config.inactive_timeout:
			pool.erase(obj)
			obj.queue_free()
			removed += 1
	
	# Update stats
	stats.total -= removed
	
	var cleanup_time = (Time.get_ticks_usec() - cleanup_start) / 1000.0
	stats.performance.cleanup_time = cleanup_time
	
	print("Aggressive cleanup for pool '%s': Removed %d/%d objects in %.2fms" % 
		[pool_name, removed, initial_count, cleanup_time])

func _update_performance_stats(delta: float) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_since_last = current_time - _last_process_time
	if time_since_last < 0.016:  # Don't update more than once per frame
		return
		
	_last_process_time = current_time
	
	for pool_name in _pools:
		var stats = _pool_stats[pool_name]
		if not POOL_CONFIG[pool_name].performance_monitor:
			continue
		
		var perf = stats.performance
		
		# Update frame times
		var frame_time = delta * 1000.0
		_frame_time_sum += frame_time
		var frame_times = perf.frame_times
		
		frame_times.push_back(frame_time)
		if frame_times.size() > MAX_FRAME_SAMPLES:
			_frame_time_sum -= frame_times[0]
			frame_times.pop_front()
		
		# Calculate average frame time
		perf.average_frame_time = _frame_time_sum / frame_times.size()
		
		# Update rolling averages
		if not _rolling_averages.has(pool_name):
			_rolling_averages[pool_name] = {
				"frame_times": [],
				"attacks": [],
				"state_changes": []
			}
		
		_update_rolling_average(_rolling_averages[pool_name].frame_times, perf.average_frame_time)
		_update_rolling_average(_rolling_averages[pool_name].attacks, float(perf.attacks))
		_update_rolling_average(_rolling_averages[pool_name].state_changes, float(perf.state_changes))
		
		# Update history
		var history = perf.history
		history.frame_times.push_back(_get_rolling_average(_rolling_averages[pool_name].frame_times))
		history.state_changes.push_back(_get_rolling_average(_rolling_averages[pool_name].state_changes))
		history.attacks.push_back(_get_rolling_average(_rolling_averages[pool_name].attacks))
		history.comfort_effects.push_back(perf.comfort_zone_effects)
		
		# Update rates
		perf.state_transition_rate = perf.state_changes / current_time
		perf.attack_rate = perf.attacks / current_time
		
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

func _process_activation_queue() -> void:
	var start_time = Time.get_ticks_usec()
	var max_process_time = 2000  # 2ms max processing time
	
	while not _activation_queue.is_empty():
		var item = _activation_queue[0]
		
		# Prioritize projectiles
		if item.object.get_meta("pool_name") == "projectile":
			_activate_object_internal(item.object, item.stats)
			_activation_queue.pop_front()
		else:
			# Process other objects normally
			_activate_object_internal(item.object, item.stats)
			_activation_queue.pop_front()
			
		if (Time.get_ticks_usec() - start_time) > max_process_time:
			break 

# Add this function to help debug pool stats
func _debug_pool_stats(pool_name: String) -> void:
	var stats = _pool_stats[pool_name]
	var active_count = 0
	var pool = _pools[pool_name]
	
	# Count actual active objects
	for obj in pool:
		if obj.process_mode == Node.PROCESS_MODE_INHERIT:
			active_count += 1
	
	print("Pool Stats for %s:" % pool_name)
	print("- Recorded active: ", stats.active)
	print("- Actual active: ", active_count)
	print("- Total: ", stats.total)
	
	# Auto-correct if needed
	if active_count != stats.active:
		print("Correcting active count from %d to %d" % [stats.active, active_count])
		stats.active = active_count 

# Add this function to sync pool stats
func _sync_pool_stats(pool_name: String) -> void:
	if not _pools.has(pool_name):
		return
		
	var stats = _pool_stats[pool_name]
	var pool = _pools[pool_name]
	var active_count = 0
	
	# Count actual active objects
	for obj in pool:
		if obj.process_mode == Node.PROCESS_MODE_INHERIT:
			active_count += 1
	
	# Update stats if they don't match
	if stats.active != active_count:
		print("Syncing %s pool stats - Active: %d -> %d" % [pool_name, stats.active, active_count])
		stats.active = active_count
		stats.peak_usage = max(stats.peak_usage, active_count)
