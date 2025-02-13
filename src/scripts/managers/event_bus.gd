class_name EventBus
extends Node

# Game state signals
signal weapon_fired(weapon: Node2D, position: Vector2)
signal enemy_died(enemy: Node)
signal resource_collected(amount: float)
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)

func emit_weapon_fired(weapon: Node2D, position: Vector2) -> void:
    weapon_fired.emit(weapon, position)

func emit_enemy_died(enemy: Node) -> void:
    enemy_died.emit(enemy)

func emit_resource_collected(amount: float) -> void:
    resource_collected.emit(amount)

func emit_wave_started(wave_number: int) -> void:
    wave_started.emit(wave_number)

func emit_wave_completed(wave_number: int) -> void:
    wave_completed.emit(wave_number)

# Optional: Add helper methods for connecting signals
func connect_weapon_fired(callable: Callable) -> void:
    weapon_fired.connect(callable)

func connect_enemy_died(callable: Callable) -> void:
    enemy_died.connect(callable)

func connect_resource_collected(callable: Callable) -> void:
    resource_collected.connect(callable)

func connect_wave_started(callable: Callable) -> void:
    wave_started.connect(callable)

func connect_wave_completed(callable: Callable) -> void:
    wave_completed.connect(callable) 