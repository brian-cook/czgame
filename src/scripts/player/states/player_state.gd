class_name BasePlayerState
extends Node

var player: BasicPlayer
@onready var global_state = get_node("/root/GlobalPlayerState")

func enter() -> void:
	pass

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

func handle_input(_event: InputEvent) -> void:
	pass 