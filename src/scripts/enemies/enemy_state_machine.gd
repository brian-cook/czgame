class_name BaseEnemyStateMachine
extends Node

signal state_changed(state_name: String)

var current_state: BaseEnemyState
var states: Dictionary = {}
var debug_label: Label
var _last_transition_time: float = 0.0
const MIN_TRANSITION_INTERVAL: float = 0.1  # Minimum time between transitions
const DEBUG_PRINT_INTERVAL: float = 1.0  # Only print debug every second
var _pool_stats: Dictionary
var _last_state_name: String = ""
var _transition_count: int = 0
const MAX_TRANSITIONS_PER_SECOND: int = 5
var _state_durations: Dictionary = {}
var _state_start_time: float = 0.0
var _debug_update_timer: float = 0.0
const DEBUG_UPDATE_INTERVAL: float = 0.2  # Update debug display every 0.2 seconds
var _transition_batch_size: int = 3
var _pending_transitions: Array[Dictionary] = []

func _ready() -> void:
	# Create debug label with better visibility
	debug_label = Label.new()
	debug_label.position = Vector2(-50, -40)
	debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	debug_label.size = Vector2(100, 20)
	
	# Add background for better visibility
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.size = Vector2(100, 20)
	bg.position = Vector2(-50, -40)
	
	add_child(bg)
	add_child(debug_label)
	
	# Initialize states
	var parent_enemy = owner as BasicEnemy
	for child in get_children():
		if child is BaseEnemyState:
			states[child.name.to_lower()] = child
			child.initialize(self, parent_enemy)
	
	if states.has("chase"):
		transition_to("chase")
	
	# Get pool stats reference
	var pool_manager = get_tree().get_first_node_in_group("pool_manager")
	if pool_manager:
		_pool_stats = pool_manager.get_pool_stats().get("enemy", {})
	
	_state_start_time = Time.get_ticks_msec() / 1000.0

func _process(delta: float) -> void:
	if not OS.is_debug_build() or not current_state:
		return
		
	_debug_update_timer += delta
	if _debug_update_timer >= DEBUG_UPDATE_INTERVAL:
		_debug_update_timer = 0.0
		
		# Only update debug label if state or color changed
		var new_text = "State: " + current_state.name
		var new_color = _get_state_color(current_state.name)
		
		if debug_label.text != new_text or debug_label.modulate != new_color:
			debug_label.text = new_text
			debug_label.modulate = new_color
			
			# Update state stats
			if _pool_stats and _pool_stats.has("performance"):
				_pool_stats.performance.state_durations = _state_durations.duplicate()

func _get_state_color(state_name: String) -> Color:
	match state_name.to_lower():
		"chase": return Color.YELLOW
		"attack": return Color.RED
		"stunned": return Color.GRAY
		_: return Color.WHITE

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)
		
		# Process pending transitions
		var processed = 0
		while not _pending_transitions.is_empty() and processed < _transition_batch_size:
			var transition = _pending_transitions.pop_front()
			_process_transition(transition.state, Time.get_ticks_msec() / 1000.0)
			processed += 1

func transition_to(state_name: String) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Track state duration
	if current_state:
		var duration = current_time - _state_start_time
		if not _state_durations.has(current_state.name):
			_state_durations[current_state.name] = 0.0
		_state_durations[current_state.name] += duration
	
	# Reset transition count each second
	if current_time - _last_transition_time >= 1.0:
		_transition_count = 0
		_last_transition_time = current_time
		_pending_transitions.clear()
	
	# Limit transitions per second
	if _transition_count >= MAX_TRANSITIONS_PER_SECOND:
		# Queue transition for later if limit reached
		_pending_transitions.append({
			"state": state_name,
			"time": current_time
		})
		return
	
	# Process transition
	_process_transition(state_name, current_time)

func _process_transition(state_name: String, current_time: float) -> void:
	# Prevent redundant transitions
	if current_state and current_state.name.to_lower() == state_name.to_lower():
		return
	
	_transition_count += 1
	_last_state_name = state_name
	
	if current_state:
		current_state.exit()
	
	if states.has(state_name.to_lower()):
		current_state = states[state_name.to_lower()]
		current_state.enter()
		state_changed.emit(state_name)
		
		# Track state changes in pool stats
		if _pool_stats and _pool_stats.has("performance"):
			_pool_stats.performance.state_changes += 1
	else:
		push_error("Enemy state not found: " + state_name)
	
	_state_start_time = current_time

func get_state_stats() -> Dictionary:
	var current_state_name = "none"
	if current_state:
		current_state_name = current_state.name
		
	return {
		"durations": _state_durations,
		"transitions": _transition_count,
		"current_state": current_state_name
	} 