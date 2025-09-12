extends Area2D

@export var speed: float = 600.0

var direction: Vector2
var shooter: Node = null

func _ready() -> void:
	self.z_index = 2

func set_direction(_direction: Vector2):
	self.direction = _direction
	self.rotation = _direction.angle()

func _physics_process(delta: float) -> void:
	position += direction * speed * delta 
	if position.y < -100:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body == shooter:
		return
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area == shooter:
		return
	queue_free()
