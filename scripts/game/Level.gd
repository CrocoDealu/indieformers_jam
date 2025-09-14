extends Node2D

@export var initial_position: Vector2
@export var layers: Array 
@export var is_tutorial: bool

@onready var layers_node = $Layers
var deletable_blocks = [Vector2(-42 ,9), Vector2(-42, 10)]

func _ready() -> void:
	SignalBus.level_ready.emit(initial_position)
	layers = layers_node.get_children()

func show_layer(i):
	layers[i].visible = true

func hide_layer(i):
	layers[i].visible = false

func delete_blocks():
	for block in deletable_blocks:
		layers[1].erase_cell(block)
