extends CharacterBody2D
class_name BasicEnemy

signal enemy_died
signal health_changed(new_health: float, max_health: float)

@export_group("Movement")
@export var speed: float = 200.0
@export var acceleration: float = 1000.0
@export var friction: float = 800.0
@export var attack_range: float = 50.0

@export_group("Combat")
@export var max_health: float = 50.0
@export var damage: float = 10.0
@export var attack_cooldown: float = 1.0
@export var knockback_force: float = 100.0

@onready var state_machine: EnemyStateMachine = $StateMachine

var _current_health: float
var _target: Node2D

func _ready() -> void:
	print("Enemy ready")
	add_to_group("enemies")
	_current_health = max_health
	health_changed.emit(_current_health, max_health)
	_find_target()

func get_target() -> Node2D:
	if not is_instance_valid(_target):
		_find_target()
	return _target

func _find_target() -> void:
	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		_target = players[0]
		print("Found target: ", _target.name)

func take_damage(amount: float, knockback_direction: Vector2 = Vector2.ZERO) -> void:
	_current_health = max(0.0, _current_health - amount)
	health_changed.emit(_current_health, max_health)
	
	if knockback_direction != Vector2.ZERO:
		velocity = knockback_direction * knockback_force
		state_machine.transition_to("Stunned")
	
	if _current_health <= 0:
		die()

func die() -> void:
	print("Enemy died")
	enemy_died.emit()
	
	# Use call_deferred for all physics-related cleanup
	call_deferred("_handle_death")

func _handle_death() -> void:
	# These will be handled by the object pool manager
	process_mode = Node.PROCESS_MODE_DISABLED
	hide()
	
	# Disable collision shapes
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.call_deferred("set_disabled", true)

func attack() -> void:
	if _target and _target.has_method("take_damage"):
		print("Enemy hit player")
		_target.take_damage(damage)

func initialize(pos: Vector2) -> void:
	# Reset enemy state
	global_position = pos
	_current_health = max_health
	health_changed.emit(_current_health, max_health)
	velocity = Vector2.ZERO
	
	# Reset state machine
	if state_machine:
		state_machine.transition_to("Chase")
	
	show()
	process_mode = Node.PROCESS_MODE_INHERIT

func reset() -> void:
	# Reset all state when returned to pool
	_current_health = max_health
	velocity = Vector2.ZERO
	
	# Reset state machine more efficiently
	if state_machine:
		# Clear current state without transition
		if state_machine.current_state:
			state_machine.current_state.exit()
		state_machine.current_state = state_machine.states["chase"]
		state_machine._last_transition_time = 0.0
	
	# Clear any ongoing effects or timers more efficiently
	for child in get_children():
		if child is Timer:
			child.stop()
		elif child.has_method("reset"):
			child.reset()
	
	# Reset transform state
	global_position = Vector2.ZERO
	global_rotation = 0
	global_scale = Vector2.ONE
	modulate = Color.WHITE
	
	# Clear target reference
	_target = null
	
	# Disconnect all signals safely
	for connection in enemy_died.get_connections():
		enemy_died.disconnect(connection.callable)
	for connection in health_changed.get_connections():
		health_changed.disconnect(connection.callable)
	
	# Reset collision state
	process_mode = Node.PROCESS_MODE_DISABLED
	hide()

func _on_hurtbox_area_entered(area: Area2D) -> void:
	# Cast the area to ProjectileBase first
	var projectile := area as ProjectileBase
	if projectile:  # Check if cast was successful
		if projectile._source != self:  # Use _source instead of source
			var knockback_direction = (global_position - projectile.global_position).normalized()
			take_damage(projectile.damage, knockback_direction)
			print("Enemy hit by projectile! Damage: ", projectile.damage)
