class_name BasePlayerStateMachine
extends Node

signal state_changed(state_name: String)

var current_state: BasePlayerState
var states: Dictionary = {}
var debug_label: Label

func _ready() -> void:
	# Create debug label with better visibility
	debug_label = Label.new()
	debug_label.position = Vector2(-50, -40)  # Above the player
	debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	debug_label.size = Vector2(100, 20)
	
	# Add background for better visibility
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.size = Vector2(100, 20)
	bg.position = Vector2(-50, -40)
	
	add_child(bg)
	add_child(debug_label)
	
	# Get states from autoload
	for child in get_children():
		if child is BasePlayerState:
			states[child.name.to_lower()] = child
			child.player = owner as BasicPlayer
	
	if states.has("idle"):
		transition_to("idle")

func _process(_delta: float) -> void:
	if current_state and OS.is_debug_build():
		debug_label.text = "State: " + current_state.name
		# Add color coding for different states
		debug_label.modulate = _get_state_color(current_state.name)

func _get_state_color(state_name: String) -> Color:
	match state_name.to_lower():
		"idle": return Color.WHITE
		"move": return Color.GREEN
		"hurt": return Color.RED
		_: return Color.WHITE

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)

func transition_to(state_name: String) -> void:
	if current_state:
		print("Exiting state: ", current_state.name)  # Debug print
		current_state.exit()
		
	if states.has(state_name.to_lower()):
		current_state = states[state_name.to_lower()]
		print("Entering state: ", state_name)  # Debug print
		current_state.enter()
		state_changed.emit(state_name)
	else:
		push_error("State not found: " + state_name) 