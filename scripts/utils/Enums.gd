extends Node

enum event_type {
	LEFT,
	RIGHT
}

enum Team { 
	PLAYER, 
	ENEMY 
}

enum State {
	IDLE, 
	PATROL, 
	CHASE, 
	ATTACK, 
	COOLDOWN
}
