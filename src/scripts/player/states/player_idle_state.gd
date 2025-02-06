class_name PlayerIdleState
extends PlayerState

func enter() -> void:
	player.velocity = Vector2.ZERO

func physics_update(delta: float) -> void:
	# Get movement input
	var input_vector = Input.get_vector(
		"move_left", "move_right",
		"move_up", "move_down"
	)
	
	if input_vector != Vector2.ZERO:
		player.state_machine.transition_to("Move")
		return
		
	# Apply friction while idle
	player.velocity = player.velocity.move_toward(
		Vector2.ZERO, 
		player.friction * delta
	)
	player.move_and_slide() 