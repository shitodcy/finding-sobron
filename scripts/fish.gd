extends CharacterBody2D

enum State {
	IDLE,
	FOLLOWING,
	STRIKE
}

var fish_intrest := 0.0
var detect_radius := 120.0

var current_state := State.IDLE
