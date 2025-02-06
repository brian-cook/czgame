class_name WaveIndicator
extends Control

@onready var wave_label: Label = $WaveLabel
@onready var timer_label: Label = $TimerLabel
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var progress_label: Label = $ProgressLabel

var _preparation_time: float = 0.0
var _timer: float = 0.0
var _in_preparation: bool = false

func _ready() -> void:
	# Hide labels initially
	wave_label.modulate = Color(1, 1, 1, 0)
	timer_label.hide()
	progress_label.hide()

func show_wave_start(wave_number: int) -> void:
	wave_label.modulate = Color(1, 1, 1, 0)  # Reset modulate before animation
	wave_label.text = "Wave %d" % wave_number
	animation_player.stop()  # Stop any running animations
	animation_player.play("wave_start")

func show_wave_complete(wave_number: int) -> void:
	wave_label.modulate = Color(1, 1, 1, 0)  # Reset modulate before animation
	wave_label.text = "Wave %d Complete!" % wave_number
	animation_player.stop()  # Stop any running animations
	animation_player.play("wave_complete")

func start_preparation_countdown(time: float) -> void:
	_preparation_time = time
	_timer = time
	_in_preparation = true
	timer_label.show()
	
func _process(delta: float) -> void:
	if _in_preparation:
		_timer = max(0.0, _timer - delta)
		timer_label.text = "Next Wave in: %.1f" % _timer
		
		if _timer <= 0:
			_in_preparation = false
			timer_label.hide() 

func update_progress(remaining: int, total: int) -> void:
	progress_label.text = "Enemies Remaining: %d/%d" % [remaining, total]
	progress_label.show()

func hide_progress() -> void:
	progress_label.hide() 