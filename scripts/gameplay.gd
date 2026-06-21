extends Node2D

enum State {
	SAILING,
	CASTING,
	SINKING,
	RETRIEVE,
	STRIKE,
	RESULT
}

var current_state = State.SAILING

var cast_power := 0.0
var max_cast_power := 600.0
var charging := false

var is_fishing_mode := false
var f_key_was_pressed := false 

@onready var lure = get_node_or_null("Lure")
@onready var fisherman = get_node_or_null("Fisherman")
@onready var fishing_line = get_node_or_null("FishingLine")
@onready var boat = get_node_or_null("Boat") # Tambahan referensi kapal

func _ready():
	if lure: lure.visible = false
	if fishing_line: fishing_line.visible = false
	print("Sistem Siap. Tekan tombol 'F' di atas kapal untuk Menyalakan Mode Memancing.")

func _process(delta):
	if lure == null or fisherman == null:
		return

	if is_fishing_mode and fisherman.has_node("DummyRod"):
		var dummy_rod = fisherman.get_node("DummyRod")
		dummy_rod.flip_h = fisherman.get_node("Sprite2D").flip_h
		dummy_rod.position.x = -15 if dummy_rod.flip_h else 15

	if current_state in [State.CASTING, State.SINKING, State.RETRIEVE, State.STRIKE]:
		update_fishing_line()
	else:
		if fishing_line: fishing_line.visible = false

	# Toggle Mode Memancing (Tombol F)
	var f_key_is_pressed = Input.is_physical_key_pressed(KEY_F)
	if f_key_is_pressed and not f_key_was_pressed:
		toggle_fishing_mode()
	f_key_was_pressed = f_key_is_pressed

	# CONSTRAINT OTOMATIS: Menggunakan fungsi baru yang lebih kebal bug
	if is_fishing_mode and not is_ready_to_fish():
		if current_state != State.SAILING:
			print("Pancingan terputus! Karakter berpindah dari posisi dek.")
		matikan_mode_memancing()
		batalkan_pancingan()

	# --- STATE MACHINE MEMANCING ---
	if current_state == State.SAILING:
		if not is_fishing_mode:
			return
			
		if Input.is_action_just_pressed("cast"):
			charging = true
			cast_power = 0.0
			
		if Input.is_action_pressed("cast") and charging:
			cast_power += 500 * delta
			cast_power = min(cast_power, max_cast_power)
			
		if Input.is_action_just_released("cast") and charging:
			charging = false
			start_cast()

	elif current_state == State.SINKING or current_state == State.RETRIEVE:
		if Input.is_action_pressed("cast"):
			current_state = State.RETRIEVE
			lure.is_sinking = false
			
			var rod_tip = get_rod_tip_position()
			var pull_dir = (rod_tip - lure.global_position).normalized()
			
			lure.global_position += pull_dir * 180 * delta
			
			if lure.global_position.distance_to(rod_tip) < 20:
				print("Umpan berhasil ditarik penuh. Siap lempar kembali.")
				batalkan_pancingan()
		else:
			current_state = State.SINKING
			lure.is_sinking = true
			lure.velocity = Vector2.ZERO 

func start_cast():
	current_state = State.CASTING
	lure.visible = true
	
	var is_facing_left = fisherman.get_node("Sprite2D").flip_h
	var throw_direction = -1 if is_facing_left else 1
	
	lure.global_position = get_rod_tip_position()
	lure.velocity = Vector2(cast_power * throw_direction, -200)
	
	await get_tree().create_timer(0.5).timeout
	
	current_state = State.SINKING
	lure.velocity = Vector2.ZERO
	lure.is_sinking = true

# --- FUNGSI PEMBANTU (HELPER) ---

# Fungsi baru untuk mengecek posisi valid yang anti-bug
func is_ready_to_fish() -> bool:
	if fisherman == null: return false
	if fisherman.current_state == fisherman.PlayerState.DRIVING: return false
	
	# Validasi 1: Sensor area bawaan Godot
	if fisherman.standing_boat != null or fisherman.nearby_boat != null:
		return true
		
	# Validasi 2: Failsafe jarak (backup jika sensor Godot ter-reset)
	if boat != null:
		var jarak_ke_kapal = fisherman.global_position.distance_to(boat.global_position)
		if jarak_ke_kapal < 150.0: # Radius toleransi pemain masih berada di kapal
			return true
			
	return false

func toggle_fishing_mode():
	if not is_ready_to_fish():
		print("PENGAMAN: Tidak bisa memancing! Anda harus berada di atas dek kapal.")
		return
		
	is_fishing_mode = !is_fishing_mode
	
	if is_fishing_mode:
		print("MODE MEMANCING ON: Joran disiapkan.")
		if fisherman.has_node("DummyRod"): fisherman.get_node("DummyRod").visible = true
	else:
		matikan_mode_memancing()
		batalkan_pancingan()

func matikan_mode_memancing():
	is_fishing_mode = false
	print("MODE MEMANCING OFF: Joran disimpan.")
	if fisherman.has_node("DummyRod"): fisherman.get_node("DummyRod").visible = false

func batalkan_pancingan():
	current_state = State.SAILING
	charging = false
	if lure:
		lure.visible = false
		lure.is_sinking = false
		lure.velocity = Vector2.ZERO
	if fishing_line:
		fishing_line.visible = false

func get_rod_tip_position() -> Vector2:
	if fisherman == null: return Vector2.ZERO
	var is_facing_left = fisherman.get_node("Sprite2D").flip_h
	var offset = Vector2(-25, -25) if is_facing_left else Vector2(25, -25)
	return fisherman.global_position + offset

func update_fishing_line():
	if not fishing_line or not lure or not fisherman: return
	fishing_line.visible = true
	fishing_line.clear_points()
	fishing_line.add_point(get_rod_tip_position())
	fishing_line.add_point(lure.global_position)
