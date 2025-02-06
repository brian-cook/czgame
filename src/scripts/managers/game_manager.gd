class_name GameManager
extends Node

signal game_over(score: int)

func _on_player_died() -> void:
    game_over.emit(calculate_final_score())
    show_game_over_screen() 