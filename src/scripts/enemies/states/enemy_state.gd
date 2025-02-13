class_name BaseEnemyState
extends Node

var enemy: BasicEnemy
var state_machine: BaseEnemyStateMachine

# Initialize is called by the state machine after all nodes are ready
func initialize(parent_state_machine: BaseEnemyStateMachine, parent_enemy: BasicEnemy) -> void:
	state_machine = parent_state_machine
	enemy = parent_enemy

func enter() -> void:
	pass

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass 
