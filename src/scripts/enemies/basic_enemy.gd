extends CharacterBody2D
class_name BasicEnemy

signal enemy_died
signal health_changed(new_health: float, max_health: float)

@export_group("Movement")
@export var speed: float = 150.0
@export var acceleration: float = 1000.0

@export_group("Combat")
@export var max_health: float = 50.0
@export var damage: float = 10.0
@export var attack_cooldown: float = 1.0
@export var knockback_force: float = 100.0

var _current_health: float
var _can_attack: bool = true
var _target: Node2D

func _ready() -> void:
	print("Enemy ready")  # Debug print
	add_to_group("enemies")
	_current_health = max_health
	health_changed.emit(_current_health, max_health)

func _physics_process(delta: float) -> void:
	_update_target()
	_handle_movement(delta)

func _update_target() -> void:
	if not _target or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("players")
		if _target:
			print("Found target: ", _target.name)  # Debug print

func _handle_movement(delta: float) -> void:
	if not _target:
		return
		
	var direction = (_target.global_position - global_position).normalized()
	velocity = velocity.move_toward(direction * speed, acceleration * delta)
	move_and_slide()

func take_damage(amount: float, knockback_direction: Vector2 = Vector2.ZERO) -> void:
	_current_health = max(0.0, _current_health - amount)
	health_changed.emit(_current_health, max_health)
	
	if knockback_direction != Vector2.ZERO:
		velocity = knockback_direction * knockback_force
	
	if _current_health <= 0:
		die()

func die() -> void:
	print("Enemy died")  # Debug print
	enemy_died.emit()
	queue_free()

func _on_hitbox_area_entered(area: Area2D) -> void:
	if not _can_attack:
		return
		
	var target = area.get_parent()
	if target.has_method("take_damage") and target.is_in_group("players"):
		print("Enemy hit player")  # Debug print
		target.take_damage(damage)
		_start_attack_cooldown()

func _start_attack_cooldown() -> void:
	_can_attack = false
	get_tree().create_timer(attack_cooldown).timeout.connect(
		func(): _can_attack = true
	)
