class_name GameManager
extends Node

signal game_over(score: int)

@export var base_score_per_wave: int = 1000
@export var resource_score_multiplier: float = 10.0

var _current_wave: int = 0
var _total_resources: float = 0.0
var _enemies_defeated: int = 0
var _game_over_ui: Control

func _ready() -> void:
    # Connect to necessary signals from game systems
    var player = get_tree().get_first_node_in_group("players")
    if player:
        player.died.connect(_on_player_died)
    _setup_game_over_ui()

func _setup_game_over_ui() -> void:
    # Create basic game over UI
    _game_over_ui = Control.new()
    _game_over_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
    _game_over_ui.hide()
    
    var panel = ColorRect.new()
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.custom_minimum_size = Vector2(300, 200)
    panel.color = Color(0, 0, 0, 0.8)
    panel.position = Vector2(-150, -100)  # Half size offset
    
    var vbox = VBoxContainer.new()
    vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    vbox.add_theme_constant_override("separation", 20)
    
    var title = Label.new()
    title.text = "Game Over"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 32)
    
    var score_label = Label.new()
    score_label.name = "ScoreLabel"
    score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    
    var restart_button = Button.new()
    restart_button.text = "Restart Game"
    restart_button.pressed.connect(_on_restart_pressed)
    
    vbox.add_child(title)
    vbox.add_child(score_label)
    vbox.add_child(restart_button)
    panel.add_child(vbox)
    _game_over_ui.add_child(panel)

func _on_player_died() -> void:
    var final_score = calculate_final_score()
    game_over.emit(final_score)
    show_game_over_screen()

func calculate_final_score() -> int:
    var wave_score = _current_wave * base_score_per_wave
    var resource_score = int(_total_resources * resource_score_multiplier)
    var enemy_score = _enemies_defeated * 100
    
    return wave_score + resource_score + enemy_score

func show_game_over_screen() -> void:
    if not _game_over_ui.get_parent():
        get_tree().root.add_child(_game_over_ui)
    
    var score_label = _game_over_ui.get_node("ScoreLabel")
    if score_label:
        score_label.text = "Final Score: %d" % calculate_final_score()
    
    _game_over_ui.show()
    get_tree().paused = true

func _on_restart_pressed() -> void:
    get_tree().paused = false
    get_tree().reload_current_scene()
    _game_over_ui.hide()

func update_wave(wave_num: int) -> void:
    _current_wave = wave_num

func add_resources(amount: float) -> void:
    _total_resources += amount

func increment_enemies_defeated() -> void:
    _enemies_defeated += 1

func get_current_score() -> int:
    return calculate_final_score() 