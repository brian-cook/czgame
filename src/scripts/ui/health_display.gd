class_name HealthDisplay
extends Control

@onready var health_bar := $HealthBar
@onready var health_label := $HealthLabel

func update_health(current: float, max_health: float) -> void:
    health_bar.value = current
    health_bar.max_value = max_health
    health_label.text = "%d/%d" % [current, max_health] 