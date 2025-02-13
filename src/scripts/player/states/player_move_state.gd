class_name BasePlayerMoveState
extends BasePlayerState

var _input_buffer_time: float = 0.1
var _buffered_input: Vector2 = Vector2.ZERO
var _buffer_timer: float = 0.0

func physics_update(delta: float) -> void:
	# Get movement input
	var input_vector = Input.get_vector(
		"move_left", "move_right",
		"move_up", "move_down"
	)
	
	# Update input buffer
	if input_vector != Vector2.ZERO:
		_buffered_input = input_vector
		_buffer_timer = _input_buffer_time
	elif _buffer_timer > 0:
		_buffer_timer -= delta
		if _buffer_timer <= 0:
			_buffered_input = Vector2.ZERO
	
	# Use buffered input if available
	var effective_input = _buffered_input if _buffer_timer > 0 else input_vector
	
	if effective_input == Vector2.ZERO:
		player.state_machine.transition_to("Idle")
		return
		
	# Apply movement with diagonal correction
	var target_velocity = effective_input * player.speed
	if effective_input.x != 0 and effective_input.y != 0:
		target_velocity *= 0.7071  # Approximately 1/sqrt(2) for diagonal movement
		
	# Apply movement
	player.velocity = player.velocity.move_toward(
		target_velocity,
		player.acceleration * delta
	)
	player.move_and_slide() 