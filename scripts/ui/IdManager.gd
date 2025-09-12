extends Node

var current_id: int = 0

func get_id():
	self.current_id += 1
	return current_id
