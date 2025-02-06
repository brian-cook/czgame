class_name ObjectPoolManager
extends Node

# Dictionary to store pools for different scene types
var _pools: Dictionary = {}

# Configuration for initial pool sizes
const DEFAULT_POOL_SIZE = 20
const POOL_SCENES = {
	"enemy": {
		"scene": preload("res://src/scenes/enemies/basic_enemy.tscn"),
		"initial_size": 20
	}
}

var _pool_stats: Dictionary = {}
var _debug_label: Label

func _ready() -> void:
	_initialize_pools()
	_setup_debug_display()

func _initialize_pools() -> void:
	for pool_name in POOL_SCENES:
		var config = POOL_SCENES[pool_name]
		_create_pool(pool_name, config.scene, config.initial_size)

func _create_pool(pool_name: String, scene: PackedScene, size: int) -> void:
	var pool: Array[Node] = []
	_pool_stats[pool_name] = {
		"total": size,
		"active": 0,
		"expansions": 0
	}
	
	for i in size:
		var instance = scene.instantiate()
		instance.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(instance)
		instance.hide()
		pool.append(instance)
	
	_pools[pool_name] = pool
	print("Created pool: ", pool_name, " with size: ", size)

func get_object(pool_name: String) -> Node:
	if not _pools.has(pool_name):
		push_error("Pool not found: " + pool_name)
		return null
		
	var pool = _pools[pool_name]
	var stats = _pool_stats[pool_name]
	
	# Try to find an inactive object
	for obj in pool:
		if obj.process_mode == Node.PROCESS_MODE_DISABLED:
			obj.process_mode = Node.PROCESS_MODE_INHERIT
			obj.show()
			stats.active += 1
			return obj
	
	# If no inactive objects, expand pool
	print("Expanding pool: ", pool_name, " (Active: ", stats.active, "/", stats.total, ")")
	stats.expansions += 1
	stats.total += 1
	
	var scene = POOL_SCENES[pool_name].scene
	var new_obj = scene.instantiate()
	add_child(new_obj)
	pool.append(new_obj)
	stats.active += 1
	return new_obj

func return_object(obj: Node, pool_name: String) -> void:
	if not _pools.has(pool_name):
		push_error("Pool not found: " + pool_name)
		return
		
	if obj not in _pools[pool_name]:
		push_error("Object not from pool: " + pool_name)
		return
		
	obj.process_mode = Node.PROCESS_MODE_DISABLED
	obj.hide()
	_pool_stats[pool_name].active -= 1

func get_pool_stats() -> Dictionary:
	return _pool_stats 

func _setup_debug_display() -> void:
	if not OS.is_debug_build():
		return
		
	_debug_label = Label.new()
	_debug_label.position = Vector2(10, 100)
	_debug_label.size = Vector2(200, 100)
	add_child(_debug_label)

func _process(_delta: float) -> void:
	if OS.is_debug_build() and _debug_label:
		var text = "Object Pool Stats:\n"
		for pool_name in _pool_stats:
			var stats = _pool_stats[pool_name]
			text += "%s: %d/%d (Expanded: %d)\n" % [
				pool_name,
				stats.active,
				stats.total,
				stats.expansions
			]
		_debug_label.text = text 