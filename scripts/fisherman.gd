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

# ── Deck Collision Exception ──
# When the player stands on the boat's deck, their CharacterBody2D gravity
# pushes down on the boat, forcing it below equilibrium depth. This causes
# the spring-damper to compute extreme displacement, triggering a phantom
# horizontal velocity that feeds into the engine audio pitch (RPM runaway).
#
# The solution: when standing_boat is set, we disable collision between
# the player and the boat via layer/mask manipulation and manually
# enforce the player's Y position to track the deck surface.

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
	# Read input once at the top for use in both branches
	var direction = Input.get_axis("move_left", "move_right")
	
	# ── DECK GRAVITY ISOLATION ──
	# When on the boat deck, the player must NOT apply downward force to the boat.
	# Strategy:
	#   1. Zero out gravity accumulation so the player doesn't push the boat down
	#   2. Remove the boat from our collision mask so move_and_slide transfers no impulse
	#   3. Manually snap Y position to the boat's surface
	if standing_boat != null:
		# No gravity while on deck
		velocity.y = 0.0
		
		# Remove the boat (layer 1) from our collision mask
		if _saved_collision_mask != 0:
			collision_mask = _saved_collision_mask & ~1
		
		# Track the boat's deck surface so the player visually stays on deck
		global_position.y = standing_boat.global_position.y - 30.0
		
		# Sync horizontal velocity with the boat
		velocity.x = (direction * move_speed) + (standing_boat.velocity.x * 0.8)
	else:
		# Restore normal gravity and full collision when not on deck
		if _saved_collision_mask != 0 and collision_mask != 1:
			collision_mask = 1
		if not is_on_floor():
			velocity.y += gravity * delta
		velocity.x = move_toward(velocity.x, direction * move_speed, 800.0 * delta)
	
	if direction != 0:
		$Sprite2D.flip_h = direction < 0
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force
	
	if Input.is_action_just_pressed("interact") and nearby_boat != null:
		enter_boat()
	
	move_and_slide()

func handle_driving(_delta):
	if current_boat == null: return
	
	global_position = current_boat.get_driver_seat_position()
	global_rotation = current_boat.get_boat_rotation()
	
	if Input.is_action_just_pressed("interact"):
		exit_boat()

func enter_boat():
	if nearby_boat == null: return
	
	# Save collision state before disabling
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
	
	# ── Temporary Collision Bypass ──
	# The player exits at the boat's ExitPoint, but spawning with collision
	# enabled can cause the player to physically bump the boat, transferring
	# momentum and creating a ghost-throttle impulse.
	#
	# Solution: zero out collision layers for 0.2s so the player phases out
	# cleanly, then restore them via timer.
	collision_layer = 0
	collision_mask = 0
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", false)
	
	# Restore collision after a short grace period
	get_tree().create_timer(0.2).timeout.connect(_restore_collision)
	
	# Transfer only horizontal momentum — kill vertical to prevent fall damage.
	# This treats positive AND negative velocity identically (symmetric).
	velocity = Vector2(boat_momentum.x * 0.9, -50.0)
	
	# Do NOT call move_and_slide() — let the next physics frame handle it
	# with collision already in the correct bypass state.

func _restore_collision() -> void:
	collision_layer = 1
	collision_mask = 1

# ── DECK AREA CALLBACKS (called by boat.gd) ──

func _on_deck_entered(boat_node) -> void:
	standing_boat = boat_node
	_saved_collision_layer = collision_layer
	_saved_collision_mask = collision_mask

func _on_deck_exited() -> void:
	standing_boat = null
	# Collision layers will be restored naturally in handle_on_foot
