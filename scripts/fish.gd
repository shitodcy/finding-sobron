extends CharacterBody2D

enum State {
	IDLE,
	FOLLOWING,
	STRIKE
}

var fish_intrest := 0.0
var detect_radius := 120.0
var current_state := State.IDLE
var lure_node: Node2D = null

func _physics_process(delta: float) -> void:
	if lure_node == null:
		return

	var lure_position = lure_node.global_position
	var distance_to_lure = global_position.distance_to(lure_position)
	
	if distance_to_lure < detect_radius:
		var distance_score = 1.0 - (distance_to_lure / detect_radius)
		fish_intrest += distance_score * delta * 10.0 
		current_state = State.FOLLOWING

	if fish_intrest < 30.0:
		current_state = State.IDLE
	elif fish_intrest >= 100.0:
		current_state = State.STRIKE
