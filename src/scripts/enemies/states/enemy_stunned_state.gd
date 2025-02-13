class_name BaseEnemyStunnedState
extends BaseEnemyState

var _stun_time: float = 0.2
var _timer: float = 0.0
var _knockback_velocity: Vector2

func enter() -> void:
	_timer = 0.0
	_knockback_velocity = enemy.velocity

func physics_update(delta: float) -> void:
	_timer += delta
	
	if _timer >= _stun_time:
		state_machine.transition_to("Chase")
		return
		
	# Apply knockback and friction
	enemy.velocity = _knockback_velocity.move_toward(Vector2.ZERO, enemy.friction * delta)
	enemy.move_and_slide() 