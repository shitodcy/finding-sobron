extends CharacterBody2D

enum PlayerState {
	ON_FOOT,
	DRIVING,
	CASTING,
	FISHING
}

var current_state = PlayerState.ON_FOOT

var nearby_boat = null
var current_boat = null
var standing_boat = null

@export var move_speed := 200.0
@export var jump_force := -350.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var _saved_collision_layer: int = 0
var _saved_collision_mask: int = 0

func _physics_process(delta):
	if current_state == PlayerState.ON_FOOT:
		handle_on_foot(delta)
	elif current_state == PlayerState.DRIVING:
		handle_driving(delta)

func handle_on_foot(delta):
	# Ambil input axis di awal
	var direction = Input.get_axis("move_left", "move_right")
	
	# ── DECK GRAVITY ISOLATION ──
	if standing_boat != null:
		# Matikan akumulasi gravitasi agar tidak membebani pegas perahu
		velocity.y = 0.0
		
		# Singkirkan perahu (layer 1) dari collision mask agar tidak mentransfer impulse liar
		if _saved_collision_mask != 0:
			collision_mask = _saved_collision_mask & ~1
		
		# Kunci posisi Y karakter mengikuti permukaan dek perahu
		global_position.y = standing_boat.global_position.y - 30.0
		
		# Sinkronisasikan kecepatan horizontal karakter dengan perahu
		velocity.x = (direction * move_speed) + (standing_boat.velocity.x * 0.8)
	else:
		# Kembalikan konfigurasi fisik normal saat berada di luar dek perahu
		if _saved_collision_mask != 0 and collision_mask != 1:
			collision_mask = 1
		if not is_on_floor():
			velocity.y += gravity * delta
		velocity.x = move_toward(velocity.x, direction * move_speed, 800.0 * delta)
	
	if direction != 0:
		$Sprite2D.flip_h = direction < 0
	
	if Input.is_action_just_pressed("jump") and is_on_floor() and standing_boat == null:
		velocity.y = jump_force
	
	if Input.is_action_just_pressed("interact") and nearby_boat != null:
		enter_boat()
	
	move_and_slide()

func handle_driving(_delta):
	if current_boat == null: return
	
	global_position = current_boat.get_driver_seat_position()
	global_rotation = current_boat.get_boat_rotation()
	
	# Penyederhanaan: Keluar dari kemudi bisa menggunakan tombol Interact (E) maupun Jump (Spasi)
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump"):
		exit_boat()

func enter_boat():
	if nearby_boat == null: return
	
	# Simpan status fisik sebelum dinonaktifkan
	_saved_collision_layer = collision_layer
	_saved_collision_mask = collision_mask
	
	current_state = PlayerState.DRIVING
	current_boat = nearby_boat
	current_boat.set_driver(true)
	
	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = true

func exit_boat():
	if current_boat == null: return
	
	var boat_momentum = current_boat.velocity
	
	current_boat.set_driver(false)
	global_rotation = 0.0
	global_position = current_boat.get_exit_position()
	
	current_state = PlayerState.ON_FOOT
	current_boat = null
	
	# PERBAIKAN BUG: Langsung pulihkan collision secara instan tanpa jeda timer 0.2 detik
	# Hal ini mencegah karakter amblas menembus lantai dek kapal yang memicu lonjakan gaya fisik liar
	collision_layer = 1
	collision_mask = 1
	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = false
	
	# Netralkan gaya gravitasi vertikal saat melompat keluar agar transisi mulus
	velocity = Vector2(boat_momentum.x * 0.9, 0.0)

func _restore_collision() -> void:
	# Fungsi pembantu bawaan dipertahankan sebagai cadangan aman sistem
	collision_layer = 1
	collision_mask = 1
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", false)

# ── DECK AREA CALLBACKS ──

func _on_deck_entered(boat_node) -> void:
	standing_boat = boat_node
	_saved_collision_layer = collision_layer
	_saved_collision_mask = collision_mask

func _on_deck_exited() -> void:
	standing_boat = null
