class_name ProjectileBase
extends Area2D

signal hit_target(target: Node)

@export_group("Projectile Properties")
@export var lifetime: float = 2.0
@export var pierce_count: int = 1

var speed: float = 800.0
var damage: float = 10.0
var _direction: Vector2
var _source: Node2D
var _initialized: bool = false
var pierced_targets: Array[Node] = []
var _time_alive: float = 0.0

func _ready() -> void:
    print("Projectile ready")
    # Start disabled
    set_physics_process(false)
    process_mode = Node.PROCESS_MODE_DISABLED
    hide()

func initialize(pos: Vector2, dir: Vector2, src: Node2D, dmg: float, spd: float) -> void:
    print("Initializing projectile at: ", pos)
    
    # Reset state
    pierced_targets.clear()
    _initialized = true
    _time_alive = 0.0
    
    # Set properties
    global_position = pos
    _direction = dir.normalized()
    _source = src
    damage = dmg
    speed = spd
    
    # Show and enable
    show()
    set_physics_process(true)
    process_mode = Node.PROCESS_MODE_INHERIT
    print("Projectile initialized with speed:", speed, " direction:", _direction)

func _physics_process(delta: float) -> void:
    if not _initialized:
        return
        
    _time_alive += delta
    if _time_alive >= lifetime:
        _handle_cleanup()
        return
        
    # Move projectile
    var velocity = _direction * speed
    global_position += velocity * delta

func _on_area_entered(area: Area2D) -> void:
    if not _initialized or not area or not area.owner:
        return
        
    if area.owner != _source and area.owner.has_method("take_damage"):
        if area.owner not in pierced_targets:
            _handle_collision(area)

func _handle_collision(area: Area2D) -> void:
    var target = area.owner
    if target.has_method("take_damage"):
        target.take_damage(damage, _direction)
        hit_target.emit(target)
        
    pierced_targets.append(target)
    if pierced_targets.size() >= pierce_count:
        _handle_cleanup()

func _on_screen_exited() -> void:
    _handle_cleanup()

func _handle_cleanup() -> void:
    if not _initialized:
        return
        
    _initialized = false
    var pool_manager = get_tree().get_first_node_in_group("pool_manager")
    if pool_manager and pool_manager.has_method("return_object"):
        pool_manager.return_object(self, "projectile")
    else:
        queue_free() 