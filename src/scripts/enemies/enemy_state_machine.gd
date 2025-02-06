class_name EnemyStateMachine
extends Node

signal state_changed(state_name: String)

var current_state: EnemyState
var states: Dictionary = {}
var debug_label: Label

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
	
	for child in get_children():
		if child is EnemyState:
			states[child.name.to_lower()] = child
			child.enemy = owner as BasicEnemy
	
	if states.has("chase"):
		transition_to("chase")

func _process(_delta: float) -> void:
	if current_state and OS.is_debug_build():
		debug_label.text = "State: " + current_state.name
		debug_label.modulate = _get_state_color(current_state.name)

func _get_state_color(state_name: String) -> Color:
	match state_name.to_lower():
		"chase": return Color.YELLOW
		"attack": return Color.RED
		"stunned": return Color.GRAY
		_: return Color.WHITE

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func transition_to(state_name: String) -> void:
	if current_state:
		print("Enemy exiting state: ", current_state.name)
		current_state.exit()
		
	if states.has(state_name.to_lower()):
		current_state = states[state_name.to_lower()]
		print("Enemy entering state: ", state_name)
		current_state.enter()
		state_changed.emit(state_name)
	else:
		push_error("Enemy state not found: " + state_name) 