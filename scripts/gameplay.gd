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

@onready var lure = get_node_or_null("Lure")
@onready var fisherman = get_node_or_null("Fisherman")
@onready var fishing_line = get_node_or_null("FishingLine")

func _ready():
	# --- DEBUGGING NODE SAAT GAME MULAI ---
	if fisherman == null:
		print("ERROR SYSTEM: Node 'Fisherman' tidak ditemukan di dalam Scene Tree!")
	if lure == null:
		print("ERROR SYSTEM: Node 'Lure' tidak ditemukan di dalam Scene Tree!")
	if fishing_line == null:
		print("ERROR SYSTEM: Node 'FishingLine' tidak ditemukan di dalam Scene Tree!")
		
	if lure: lure.visible = false
	if fishing_line: fishing_line.visible = false
	print("Sistem Memancing Siap. Silakan tekan tombol Cast (Spasi/M).")

func _process(delta):
	# Update visual tali
	if current_state in [State.CASTING, State.SINKING, State.RETRIEVE, State.STRIKE]:
		update_fishing_line()
	else:
		if fishing_line:
			fishing_line.visible = false
		if fisherman and fisherman.has_node("DummyRod") and not charging:
			fisherman.get_node("DummyRod").visible = false

	if current_state != State.SAILING:
		return
	
	if lure == null or fisherman == null:
		return
		
	# --- SYARAT KAPAL DIMATIKAN SEMENTARA UNTUK TESTING ---
	# (Sekarang Anda bisa memancing meskipun sedang berdiri di daratan)
	# if fisherman.standing_boat == null or fisherman.current_state == fisherman.PlayerState.DRIVING:
	#	return

	# Deteksi tombol
	if Input.is_action_just_pressed("cast"):
		print("TOMBOL CAST DITEKAN! Memulai ancang-ancang...")
		charging = true
		cast_power = 0.0
		
		if fisherman.has_node("DummyRod"):
			var dummy_rod = fisherman.get_node("DummyRod")
			dummy_rod.visible = true
			dummy_rod.flip_h = fisherman.get_node("Sprite2D").flip_h
			dummy_rod.position.x = -15 if dummy_rod.flip_h else 15
		else:
			print("WARNING: Node 'DummyRod' belum ditambahkan ke dalam karakter Fisherman!")
	
	if Input.is_action_pressed("cast") and charging:
		cast_power += 500 * delta
		cast_power = min(cast_power, max_cast_power)
	
	if Input.is_action_just_released("cast") and charging:
		print("TOMBOL DILEPAS! Melempar umpan dengan kekuatan: ", cast_power)
		charging = false
		start_cast()

func start_cast():
	current_state = State.CASTING
	lure.visible = true
	
	var is_facing_left = fisherman.get_node("Sprite2D").flip_h
	var throw_direction = -1 if is_facing_left else 1
	
	lure.global_position = fisherman.global_position + Vector2(15 * throw_direction, -15)
	lure.velocity = Vector2(cast_power * throw_direction, -200)
	
	await get_tree().create_timer(0.5).timeout
	
	current_state = State.SINKING
	lure.velocity = Vector2.ZERO
	lure.is_sinking = true

func update_fishing_line():
	if not fishing_line or not lure or not fisherman:
		return
		
	fishing_line.visible = true
	fishing_line.clear_points()
	
	var is_facing_left = fisherman.get_node("Sprite2D").flip_h
	var rod_tip_offset = Vector2(-25, -25) if is_facing_left else Vector2(25, -25)
	var rod_tip_position = fisherman.global_position + rod_tip_offset
	
	fishing_line.add_point(rod_tip_position)
	fishing_line.add_point(lure.global_position)
