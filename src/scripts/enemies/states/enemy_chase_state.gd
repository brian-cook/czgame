class_name EnemyChaseState
extends EnemyState

func physics_update(delta: float) -> void:
	var target = enemy.get_target()
	if not target:
		return
		
	var direction = (target.global_position - enemy.global_position).normalized()
	enemy.velocity = enemy.velocity.move_toward(
		direction * enemy.speed,
		enemy.acceleration * delta
	)
	enemy.move_and_slide()
	
	# Check if close enough to attack
	if enemy.global_position.distance_to(target.global_position) <= enemy.attack_range:
		enemy.state_machine.transition_to("Attack") 