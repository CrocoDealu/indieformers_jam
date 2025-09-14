extends Area2D



@export var event_type : Enums.event_type

func _on_body_entered(body: Node2D) -> void:
	if "team" not in body:
		return
	SignalBus.player_area_entered.emit(event_type)

func _on_body_exited(body: Node2D) -> void:
	if "team" not in body:
		return
	SignalBus.player_area_exited.emit(event_type)
