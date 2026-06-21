extends Node2D

var velocity := Vector2.ZERO
var sink_speed := 120.0
var is_sinking := false

func _physics_process(delta):
	# Menggerakkan posisi proyektil (melayang di udara atau tarik umpan)
	global_position += velocity * delta

	# Tenggelam lurus ke bawah saat masuk air
	if is_sinking:
		global_position.y += sink_speed * delta
