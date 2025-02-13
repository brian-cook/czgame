class_name PlayerHurtState
extends BasePlayerState

var _knockback_velocity: Vector2
var _stun_time: float = 0.2
var _timer: float = 0.0
var _knockback_strength: float = 200.0
var _min_knockback_speed: float = 50.0  # Minimum knockback speed
var _invulnerable_time: float = 0.5  # Time player is invulnerable after being hit

var _sprite: ColorRect
var _original_color: Color
var _hurt_color: Color = Color(1, 0.3, 0.3)
var _flash_time: float = 0.1

func enter() -> void:
	_timer = 0.0
	
	# Make player invulnerable
	player._can_take_damage = false
	
	# Initialize sprite reference
	_sprite = player.get_node("Sprite")
	_original_color = _sprite.color
	
	# Get direction from enemy if available
	var enemies = get_tree().get_nodes_in_group("enemies")
	var closest_enemy = null
	var closest_distance = INF
	
	for enemy in enemies:
		var distance = enemy.global_position.distance_to(player.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy
	
	if closest_enemy:
		var direction = (player.global_position - closest_enemy.global_position).normalized()
		_knockback_velocity = direction * _knockback_strength
	else:
		# If no enemy found or already being knocked back, add to current velocity
		var current_speed = player.velocity.length()
		if current_speed > _min_knockback_speed:
			_knockback_velocity = player.velocity.normalized() * _knockback_strength
		else:
			# Random knockback if no clear direction
			_knockback_velocity = Vector2.RIGHT.rotated(randf() * TAU) * _knockback_strength

	# Visual feedback
	_sprite.color = _hurt_color
	
	# Reset color after flash
	get_tree().create_timer(_flash_time).timeout.connect(
		func(): _sprite.color = _original_color
	)

func physics_update(delta: float) -> void:
	_timer += delta
	
	if _timer >= _stun_time:
		player.state_machine.transition_to("Idle")
		return
		
	# Flash effect while stunned
	_sprite.visible = int(_timer * 10) % 2 == 0
	
	# Apply knockback and friction
	player.velocity = _knockback_velocity.move_toward(Vector2.ZERO, player.friction * delta)
	player.move_and_slide()

func exit() -> void:
	if _sprite:
		_sprite.color = _original_color
		_sprite.visible = true
	
	# Start invulnerability timer
	get_tree().create_timer(_invulnerable_time).timeout.connect(
		func(): player._can_take_damage = true
	) 
