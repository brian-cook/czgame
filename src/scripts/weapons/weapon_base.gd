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

func _physics_process(_delta: float) -> void:
    if not can_fire:
        return
        
    # Handle both mouse click and controller input
    if Input.is_action_pressed("attack"):
        try_fire()

func try_fire() -> void:
    if not can_fire:
        print("Weapon cannot fire - cooldown active")
        return
        
    print("Attempting to fire weapon")
    can_fire = false
    _fire_timer.start(1.0 / fire_rate)
    
    var spawn_pos = global_position
    var direction: Vector2
    
    # Get aim direction based on input type
    if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        direction = (get_global_mouse_position() - spawn_pos).normalized()
        print("Using mouse aim direction:", direction)
    else:
        # Use controller aim direction if available
        var stick_x = Input.get_axis("aim_left", "aim_right")
        var stick_y = Input.get_axis("aim_up", "aim_down")
        var stick_input = Vector2(stick_x, stick_y)
        
        if stick_input.length() > 0.1:
            direction = stick_input.normalized()
            print("Using controller aim direction:", direction)
        else:
            direction = Vector2.RIGHT
            print("Using default aim direction")
    
    _spawn_projectile(spawn_pos, direction)
    weapon_fired.emit(self, spawn_pos)

func _spawn_projectile(spawn_pos: Vector2, direction: Vector2) -> void:
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
        spawn_pos,  # Use the provided spawn position
        direction,
        owner,  # The player
        damage,
        projectile_speed
    )

func _on_fire_timer_timeout() -> void:
    can_fire = true 