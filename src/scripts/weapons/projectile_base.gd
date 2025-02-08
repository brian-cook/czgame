@tool  # Allow visualization in editor
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
var _creation_time: float = 0.0
const MIN_LIFETIME: float = 0.25  # Minimum time before cleanup in seconds
var _cleanup_scheduled: bool = false
var _lifetime_timer: Timer
var _start_pos: Vector2
var time_alive: float = 0.0

func _ready() -> void:
    print("Projectile ready")
    # Setup lifetime timer
    _lifetime_timer = Timer.new()
    _lifetime_timer.one_shot = true
    _lifetime_timer.timeout.connect(_on_lifetime_expired)
    add_child(_lifetime_timer)
    
    # Start disabled
    set_physics_process(false)
    process_mode = Node.PROCESS_MODE_DISABLED
    hide()

func initialize(pos: Vector2, dir: Vector2, src: Node2D, dmg: float, spd: float) -> void:
    print("Projectile initialized at: ", pos, " with direction: ", dir)
    
    # Reset state
    pierced_targets.clear()
    _initialized = true
    _cleanup_scheduled = false
    _creation_time = Time.get_ticks_msec() / 1000.0
    _start_pos = pos
    
    # Set properties
    global_position = pos
    _direction = dir.normalized()
    _source = src
    damage = dmg
    speed = spd
    
    # Start lifetime timer
    _lifetime_timer.stop()  # Stop any existing timer
    _lifetime_timer.start(lifetime)
    
    # Show and enable
    show()
    set_physics_process(true)
    process_mode = Node.PROCESS_MODE_INHERIT

func _physics_process(delta: float) -> void:
    if not _initialized or _cleanup_scheduled:
        return
        
    # Update time alive
    var current_time = Time.get_ticks_msec() / 1000.0
    time_alive = current_time - _creation_time
    
    # Move projectile
    var movement = _direction * speed * delta
    global_position += movement
    
    # Cache camera reference
    var camera = get_viewport().get_camera_2d()
    if not camera:
        return
        
    # Check if out of screen bounds (optimized)
    var viewport_rect = get_viewport().get_visible_rect()
    var margin = 150  # Increased margin for more consistent cleanup
    var screen_pos = global_position - camera.global_position
    
    # Only check bounds after minimum lifetime
    if time_alive >= MIN_LIFETIME:
        var bounds_x = viewport_rect.size.x + margin
        var bounds_y = viewport_rect.size.y + margin
        var outside_x = abs(screen_pos.x) > bounds_x
        var outside_y = abs(screen_pos.y) > bounds_y
        
        if outside_x or outside_y:
            var distance = global_position.distance_to(_start_pos)
            print("Projectile out of bounds at: ", global_position, 
                  "\n - Time alive: ", time_alive,
                  "\n - Distance traveled: ", distance,
                  "\n - Screen position: ", screen_pos)
            _handle_cleanup(false)

func _on_lifetime_expired() -> void:
    if _initialized and not _cleanup_scheduled:
        print("Lifetime expired for projectile at: ", global_position)
        _handle_cleanup(true)

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

func _handle_cleanup(force: bool = false) -> void:
    if not _initialized or _cleanup_scheduled:
        return
        
    var current_time = Time.get_ticks_msec() / 1000.0
    var time_alive = current_time - _creation_time
    
    # Only allow cleanup after minimum lifetime unless forced by lifetime expiry
    if force or time_alive >= MIN_LIFETIME:
        print("Cleaning up projectile - Force:", force, " Time alive:", time_alive)
        _cleanup_scheduled = true
        _initialized = false
        _lifetime_timer.stop()  # Stop the lifetime timer
        hide()
        set_physics_process(false)
        process_mode = Node.PROCESS_MODE_DISABLED
        
        var pool_manager = get_tree().get_first_node_in_group("pool_manager")
        if pool_manager and pool_manager.has_method("return_object"):
            pool_manager.return_object(self, "projectile")
        else:
            queue_free() 