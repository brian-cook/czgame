class_name EnemyAttackState
extends EnemyState

var _attack_cooldown: float = 1.0
var _timer: float = 0.0
var _can_attack: bool = true

func enter() -> void:
	_timer = 0.0
	_can_attack = true

func physics_update(delta: float) -> void:
	var target = enemy.get_target()
	if not target:
		enemy.state_machine.transition_to("Chase")
		return
		
	_timer += delta
	
	# Check if target moved out of range
	if enemy.global_position.distance_to(target.global_position) > enemy.attack_range:
		enemy.state_machine.transition_to("Chase")
		return
		
	# Slow down when attacking
	enemy.velocity = enemy.velocity.move_toward(Vector2.ZERO, enemy.friction * delta)
	
	# Attack if possible
	if _can_attack:
		_perform_attack()
		
func _perform_attack() -> void:
	_can_attack = false
	enemy.attack()  # This should be implemented in basic_enemy.gd
	
	# Reset attack cooldown
	get_tree().create_timer(_attack_cooldown).timeout.connect(
		func(): _can_attack = true
	) 