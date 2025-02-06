class_name EnemySpawnManager
extends Node

signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)

@export_group("Wave Settings")
@export var initial_enemies_per_wave := 5
@export var enemies_increase_per_wave := 2
@export var wave_preparation_time := 5.0
@export var spawn_radius := 800.0

@export_group("Difficulty Scaling")
@export var health_increase_per_wave := 10.0
@export var damage_increase_per_wave := 2.0
@export var speed_increase_per_wave := 20.0

var _current_wave := 0
var _enemies_remaining := 0
var _wave_in_progress := false
var _object_pool: ObjectPoolManager
var _player: Node2D
var _wave_indicator: WaveIndicator
var _wave_delay := 3.0  # Time between waves
var _preparation_timer: Timer
var _spawn_timer: Timer
var _stagger_timer: Timer
var _total_enemies: int = 0

func initialize(object_pool: ObjectPoolManager, player: Node2D, wave_indicator: WaveIndicator = null) -> void:
	_object_pool = object_pool
	_player = player
	_wave_indicator = wave_indicator

func _ready() -> void:
	_setup_timers()

func _setup_timers() -> void:
	_preparation_timer = Timer.new()
	_preparation_timer.one_shot = true
	add_child(_preparation_timer)
	
	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = true
	add_child(_spawn_timer)
	
	_stagger_timer = Timer.new()
	_stagger_timer.one_shot = true
	add_child(_stagger_timer)

func start_next_wave() -> void:
	if _wave_in_progress:
		return
		
	_current_wave += 1
	var enemies_to_spawn = initial_enemies_per_wave + (_current_wave - 1) * enemies_increase_per_wave
	
	print("Starting wave ", _current_wave, " with ", enemies_to_spawn, " enemies")
	
	if _wave_indicator:
		_wave_indicator.start_preparation_countdown(wave_preparation_time)
	
	# Start preparation time
	_preparation_timer.start(wave_preparation_time)
	_preparation_timer.timeout.connect(
		func():
			_spawn_wave(enemies_to_spawn)
			wave_started.emit(_current_wave)
			if _wave_indicator:
				_wave_indicator.show_wave_start(_current_wave)
	, CONNECT_ONE_SHOT)

func _spawn_wave(enemy_count: int) -> void:
	_enemies_remaining = enemy_count
	_total_enemies = enemy_count
	_wave_in_progress = true
	
	if _wave_indicator:
		_wave_indicator.update_progress(_enemies_remaining, _total_enemies)
	
	for i in enemy_count:
		_spawn_enemy()
		_stagger_timer.start(0.2)  # Stagger spawns
		await _stagger_timer.timeout

func _spawn_enemy() -> void:
	if not _object_pool or not _player:
		push_error("Spawn manager not properly initialized!")
		return
		
	var enemy = _object_pool.get_object("enemy") as BasicEnemy
	if enemy:
		var spawn_pos = _get_spawn_position()
		
		# Apply wave-based scaling
		_apply_wave_scaling(enemy)
		
		enemy.initialize(spawn_pos)
		enemy.enemy_died.connect(_on_enemy_died)

func _on_enemy_died() -> void:
	_enemies_remaining -= 1
	
	if _wave_indicator:
		_wave_indicator.update_progress(_enemies_remaining, _total_enemies)
	
	if _enemies_remaining <= 0:
		_wave_in_progress = false
		wave_completed.emit(_current_wave)
		if _wave_indicator:
			_wave_indicator.hide_progress()
			_wave_indicator.show_wave_complete(_current_wave)
		
		# Start next wave after delay
		_spawn_timer.start(_wave_delay)
		_spawn_timer.timeout.connect(start_next_wave, CONNECT_ONE_SHOT)

func _get_spawn_position() -> Vector2:
	if not _player:
		return Vector2.ZERO
		
	var angle = randf() * TAU
	return _player.position + Vector2.RIGHT.rotated(angle) * spawn_radius 

func _apply_wave_scaling(enemy: BasicEnemy) -> void:
	enemy.max_health += health_increase_per_wave * (_current_wave - 1)
	enemy.damage += damage_increase_per_wave * (_current_wave - 1)
	enemy.speed += speed_increase_per_wave * (_current_wave - 1) 