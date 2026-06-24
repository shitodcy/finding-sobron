extends Node2D

var velocity := Vector2.ZERO
var is_sinking := false
var is_retrieving := false # VARIABEL BARU
var gravity := 500.0

var time_passed := 0.0
var base_y := 0.0
var drag_multiplier := 1.0
var target_water_y := 0.0

func _physics_process(delta):
	# Jika ditarik, abaikan semua gaya fisika jatuh atau mengapung
	if is_retrieving:
		pass 
	# Jika di air, bergoyang/mengapung
	elif is_sinking:
		time_passed += delta
		var bobbing_offset = sin(time_passed * 4.0) * 5.0
		
		velocity.x = lerp(velocity.x, 0.0, 5.0 * delta)
		global_position.x += velocity.x * delta
		
		global_position.y = base_y + bobbing_offset
	# Jika sedang dilempar di udara
	else:
		if velocity != Vector2.ZERO:
			velocity.y += gravity * delta
			
		global_position += (velocity * drag_multiplier) * delta
		
		# Deteksi otomatis menyentuh batas air laut
		if velocity.y > 0 and target_water_y != 0.0 and global_position.y >= target_water_y:
			is_sinking = true
			base_y = target_water_y
			velocity.y = 0.0
			
			var gameplay = get_tree().current_scene.find_child("Gameplay", true, false)
			if gameplay and gameplay.current_state == gameplay.State.CASTING:
				gameplay.current_state = gameplay.State.SINKING
