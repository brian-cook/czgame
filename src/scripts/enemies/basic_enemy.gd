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
	
	# Return to pool instead of queue_free
	process_mode = Node.PROCESS_MODE_DISABLED
	hide()

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
