extends Node2D

var velocity := Vector2.ZERO

# Fase Umpan Tenggelam
var sink_speed := 120.0
var is_sinking := false

func _physics_process(delta):
	position += velocity * delta

	if is_sinking:
		position.y += sink_speed * delta
