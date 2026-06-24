extends CharacterBody2D

enum State {
	IDLE,
	WANDERING,
	FOLLOWING,
	STRIKE
}

var fish_interest := 0.0
var detect_radius := 160.0
var current_state := State.IDLE

var wander_timer := 0.0
var wander_target := Vector2.ZERO
var start_pos := Vector2.ZERO

var swim_speed := 40.0
var chase_speed := 90.0
var lure_node: Node2D = null

func _ready():
	start_pos = global_position
	# Mencari referensi lure di dalam hirarki scene secara otomatis
	lure_node = get_tree().current_scene.find_child("Lure", true, false)

func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE:
			velocity = velocity.lerp(Vector2.ZERO, 3.0 * delta)
			wander_timer -= delta
			if wander_timer <= 0:
				wander_target = start_pos + Vector2(randf_range(-60, 60), randf_range(-40, 40))
				current_state = State.WANDERING
				
		State.WANDERING:
			var dir = (wander_target - global_position).normalized()
			velocity = velocity.lerp(dir * swim_speed, 2.0 * delta)
			
			if global_position.distance_to(wander_target) < 15.0:
				current_state = State.IDLE
				wander_timer = randf_range(1.0, 3.5)
				
		State.FOLLOWING:
			if lure_node:
				var dir = (lure_node.global_position - global_position).normalized()
				# Smooth lerping velocity menuju umpan
				velocity = velocity.lerp(dir * chase_speed, 4.0 * delta)
			else:
				current_state = State.IDLE
				
		State.STRIKE:
			# Berhenti diam karena tertangkap pancing
			velocity = Vector2.ZERO

	# Logika Peningkatan Interest
	if lure_node and current_state != State.STRIKE:
		var distance_to_lure = global_position.distance_to(lure_node.global_position)
		
		# Jika di area umpan
		if distance_to_lure < detect_radius:
			var distance_score = 1.0 - (distance_to_lure / detect_radius)
			fish_interest += distance_score * delta * 15.0 
			current_state = State.FOLLOWING
		else:
			# Pengurangan perlahan saat di luar radius
			fish_interest = max(0.0, fish_interest - delta * 5.0)
			if current_state == State.FOLLOWING and fish_interest <= 0:
				current_state = State.IDLE

		# Cek Strike dan Triger ke Gameplay
		if fish_interest >= 100.0:
			current_state = State.STRIKE
			var gameplay_node = get_tree().current_scene.find_child("Gameplay", true, false)
			if gameplay_node and gameplay_node.has_method("_on_fish_strike"):
				gameplay_node._on_fish_strike(self)

	move_and_slide()
