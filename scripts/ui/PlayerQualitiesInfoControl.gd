extends Control

@onready var health_bar = $HBoxContainer/ProgressBar
@onready var bullet_number_label = $HBoxContainer/HBoxContainer/Label
@onready var special_progress_bar = $HBoxContainer/HBoxContainer2/Control/TextureRect/ProgressBar

func _ready() -> void:
	SignalBus.health_changed.connect(_on_health_changed)
	SignalBus.bullet_number_changed.connect(_on_bullet_number_changed)
	SignalBus.special_state_changed.connect(_on_special_state_changed)


func _on_health_changed(current_health, max_health):
	health_bar.max_value = max_health
	health_bar.value = current_health

func _on_bullet_number_changed(bullet_number, max_bullets):
	bullet_number_label.text = str(bullet_number) + "/" + str(max_bullets)

func _on_special_state_changed(new_special_state):
	if new_special_state == true:
		special_progress_bar.value = 0
	else:
		special_progress_bar.value = 100
