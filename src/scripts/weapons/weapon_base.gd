class_name WeaponBase
extends Node2D

signal weapon_fired(weapon: Node2D, position: Vector2)

@export_group("Weapon Properties")
@export var fire_rate: float = 1.0  # Shots per second
@export var damage: float = 10.0
@export var projectile_speed: float = 800.0

var can_fire: bool = true
var _fire_timer: Timer

func _ready() -> void:
    print("Weapon base initializing")
    # Setup fire rate timer
    _fire_timer = Timer.new()
    _fire_timer.one_shot = true
    _fire_timer.timeout.connect(_on_fire_timer_timeout)
    add_child(_fire_timer)
    can_fire = true  # Ensure we can fire initially
    print("Weapon base ready - can_fire:", can_fire)
    
    # Add to weapon group for easy access
    add_to_group("weapons")

func try_fire() -> void:
    print("try_fire called - can_fire:", can_fire)
    if not can_fire:
        print("Cannot fire - cooldown active")
        return
        
    print("Attempting to fire weapon")
    can_fire = false
    _fire_timer.start(1.0 / fire_rate)
    
    # Get firing direction (towards mouse)
    var mouse_pos = get_global_mouse_position()
    var direction = (mouse_pos - global_position).normalized()
    
    var owner_name = "none"
    if owner:
        owner_name = owner.name
    
    print("Firing weapon:",
          "\n - mouse_pos:", mouse_pos,
          "\n - weapon_pos:", global_position,
          "\n - direction:", direction,
          "\n - owner:", owner_name)
    
    _spawn_projectile(direction)
    weapon_fired.emit(self, global_position)

func _spawn_projectile(direction: Vector2) -> void:
    var pool_manager = get_tree().get_first_node_in_group("pool_manager")
    if not pool_manager:
        push_error("Pool manager not found!")
        return
        
    print("Found pool manager, requesting projectile")
    var projectile = pool_manager.get_object("projectile") as ProjectileBase
    if not projectile:
        push_error("Failed to get projectile from pool!")
        return
        
    print("Got projectile from pool - Valid:", is_instance_valid(projectile))
    projectile.initialize(
        global_position,
        direction,
        owner,  # The player
        damage,
        projectile_speed
    )

func _on_fire_timer_timeout() -> void:
    can_fire = true 