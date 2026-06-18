extends CharacterBody2D

@export_enum("Ringan", "Menengah", "Berat") var boat_level: int = 1
var stats = {
	0: {"speed": 400.0, "acceleration": 300.0, "drag": 0.5},
	1: {"speed": 300.0, "acceleration": 250.0, "drag": 0.4},
	2: {"speed": 200.0, "acceleration": 200.0, "drag": 0.3}
}

@export var roll_intensity: float = 0.3
@export var pitch_intensity: float = 0.08

var is_driven: bool = false
var is_engine_on: bool = false
var is_starting_up: bool = false

var standing_boat: Node = null
var nearby_boat: Node = null

# ── Throttle State ──
var target_speed_x: float = 0.0

@onready var driver_seat: Marker2D = $VisualRoot/DriverSeat
@onready var exit_point: Marker2D = $VisualRoot/ExitPoint
@onready var visual_root: Node2D = $VisualRoot

# ── Thresholds ──
const IDLE_LOCK_THRESHOLD: float = 5.0
const DRIVER_DRAG_MULTIPLIER: float = 100.0
const DRIFTER_DRAG_MULTIPLIER: float = 200.0  # Increased from 15 → kills small collision impulses fast

# ── Anti-Sink Floor Proximity ──
const FLOOR_SAFETY_MARGIN: float = 30.0

# ── Cinematic Camera State ──
var player_camera: Camera2D = null
var is_camera_returning: bool = false

const CAM_ZOOM_IDLE: float = 0.76
const CAM_ZOOM_FULL: float = 0.50
const CAM_OFFSET_X_LOOKAHEAD: float = 300.0
const CAM_OFFSET_Y_BOTTOM_THIRD: float = -100.0
const CAM_LERP_SPEED: float = 2.0
const RETURN_LERP_SPEED: float = 4.0
const CONVERGENCE_EPSILON: float = 0.5

# ── U-Turn State ──
var is_turning: bool = false
var u_turn_tween: Tween = null

# ── Particle Emitters ──
@onready var wake_particles: CPUParticles2D = $VisualRoot/WakeParticles
@onready var propeller_particles: CPUParticles2D = $VisualRoot/PropellerParticles

# ── HUD Button Path ──
const HUD_BUTTON_PATH: NodePath = NodePath("../HUD/Control/PutarBalikButton")

func _ready():
	var sfx_start = get_node_or_null("EngineStart")
	if sfx_start:
		sfx_start.finished.connect(_on_engine_start_finished)

func _process(_delta):
	# ── Particle Emitter Toggle ──
	# Wake particles activate when moving fast enough (abs velocity > 50).
	# Propeller particles activate when the engine is running.
	# NOTE: CPUParticles2D does NOT auto-stop when emitting = false.
	# We must explicitly set emitting = false AND call restart()
	# to fully halt particles. Setting emitting = true restarts them.
	# ── Wake (speed-triggered) ──
	var should_wake = abs(velocity.x) > 50.0
	if wake_particles and wake_particles.emitting != should_wake:
		wake_particles.emitting = false
		if should_wake:
			wake_particles.restart()
			wake_particles.emitting = true
	
	# ── Propeller foam (engine-triggered) ──
	var should_prop = is_engine_on
	if propeller_particles and propeller_particles.emitting != should_prop:
		propeller_particles.emitting = false
		if should_prop:
			propeller_particles.restart()
			propeller_particles.emitting = true

func _physics_process(delta):
	var water_system = get_parent().get_node_or_null("WaterSystem")
	if not water_system:
		return
	
	var env = water_system.get_physics_info(global_position.x - water_system.global_position.x)
	
	# ── Spring-Damper Buoyancy (Y-axis) ──
	var spring_stiffness = 140.0
	var damping_coeff = 25.0
	var equilibrium_depth = 10.0
	
	var floor_y: float = env.floor_y
	var distance_to_floor: float = floor_y - global_position.y
	var floor_factor: float = 1.0
	if distance_to_floor < FLOOR_SAFETY_MARGIN:
		floor_factor = clampf(distance_to_floor / FLOOR_SAFETY_MARGIN, 0.0, 1.0)
		var anti_sink_bias: float = (FLOOR_SAFETY_MARGIN - distance_to_floor) / FLOOR_SAFETY_MARGIN
		if distance_to_floor < FLOOR_SAFETY_MARGIN * 0.5:
			velocity.y = minf(velocity.y, -anti_sink_bias * 50.0)
	
	var displacement = (global_position.y - env.wave_y) - equilibrium_depth
	var spring_force = -spring_stiffness * displacement * floor_factor
	var damping_force = -damping_coeff * velocity.y
	velocity.y += (spring_force + damping_force) * delta
	
	# ── Engine Toggle ──
	if is_driven and Input.is_action_just_pressed("engine_toggle"):
		_toggle_engine()
	
	# ── STRUCTURAL INPUT DECOUPLING ──
	# Input is ALWAYS zero when not driving. This is checked unconditionally
	# before any velocity modification, preventing player movement keys from
	# leaking into the boat physics.
	var raw_input: float = Input.get_axis("move_left", "move_right")
	var can_drive: bool = is_driven and is_engine_on and not is_starting_up
	var effective_input: float = raw_input if can_drive else 0.0
	
	# ── TARGET THROTTLE ──
	var cfg = stats[boat_level]
	var max_speed: float = cfg.speed
	target_speed_x = effective_input * max_speed
	
	# ── X-AXIS STATE MACHINE ──
	# Three distinct branches with an explicit idle anchor for the undriven state.
	# The undriven branch uses a high drag multiplier to kill any velocity from
	# physical collision impulses (e.g., fisherman walking on deck).
	if not is_zero_approx(effective_input):
		# ACTIVE DRIVE — player is actively pressing movement keys
		velocity.x = move_toward(velocity.x, target_speed_x, cfg.acceleration * delta)
		
	elif is_driven:
		# DRIVER COASTING — driver in seat, foot off gas — heavy damping
		velocity.x = _apply_symmetric_drag(velocity.x, cfg.drag * DRIVER_DRAG_MULTIPLIER * delta)
		
	elif abs(velocity.x) > IDLE_LOCK_THRESHOLD:
		# DRIFTER GLIDE — no driver, boat still has momentum — moderate damping
		# (DRIFTER_DRAG_MULTIPLIER is intentionally high at 200 to kill physics
		#  collision impulses from player movement on deck within 1-2 frames.)
		velocity.x = _apply_symmetric_drag(velocity.x, cfg.drag * DRIFTER_DRAG_MULTIPLIER * delta)
		
	else:
		# ABSOLUTE IDLE ANCHOR — no driver, velocity near zero — hard lock.
		# This prevents any physical collision impulse from the player walking
		# on the deck from accumulating into movement.
		velocity.x = 0.0
	
	move_and_slide()
	
	# ── Contextual Rotation (Roll / Pitch) ──
	if not is_turning:
		var is_idle: bool = is_zero_approx(velocity.x)
		var target_rotation: float = 0.0
		
		if is_idle:
			target_rotation = env.wave_slope * roll_intensity
		else:
			if effective_input > 0.0:
				target_rotation = -pitch_intensity
			elif effective_input < 0.0:
				target_rotation = pitch_intensity * 0.5
			else:
				target_rotation = -sign(velocity.x) * pitch_intensity * 0.3
		
		rotation = lerp(rotation, target_rotation, 6.0 * delta)
	
	# ── Cinematic Camera ──
	_update_cinematic_camera(delta)
	
	# ── Audio ──
	_handle_engine_audio()

# ── SYMMETRIC DRAG HELPER ──
static func _apply_symmetric_drag(current_vel_x: float, amount: float) -> float:
	if abs(current_vel_x) <= amount:
		return 0.0
	amount = minf(amount, abs(current_vel_x))
	return current_vel_x - sign(current_vel_x) * amount

# ── CINEMATIC CAMERA ──

func _update_cinematic_camera(delta: float) -> void:
	if not player_camera:
		return
	
	var speed_ratio: float = clampf(abs(velocity.x) / stats[boat_level]["speed"], 0.0, 1.0)
	var is_idle: bool = is_zero_approx(velocity.x)
	
	var target_zoom: float
	if is_camera_returning:
		target_zoom = CAM_ZOOM_IDLE
	else:
		target_zoom = lerpf(CAM_ZOOM_IDLE, CAM_ZOOM_FULL, speed_ratio)
	
	var zoom_lerp_speed: float = RETURN_LERP_SPEED if is_camera_returning else CAM_LERP_SPEED
	player_camera.zoom = player_camera.zoom.lerp(
		Vector2(target_zoom, target_zoom),
		zoom_lerp_speed * delta
	)
	
	var target_offset: Vector2
	if is_camera_returning or is_idle:
		target_offset = Vector2.ZERO
	elif velocity.x > 0.0:
		target_offset = Vector2(CAM_OFFSET_X_LOOKAHEAD, CAM_OFFSET_Y_BOTTOM_THIRD)
	else:
		target_offset = Vector2(-CAM_OFFSET_X_LOOKAHEAD, CAM_OFFSET_Y_BOTTOM_THIRD)
	
	var offset_lerp_speed: float = RETURN_LERP_SPEED if is_camera_returning else CAM_LERP_SPEED
	player_camera.offset = player_camera.offset.lerp(target_offset, offset_lerp_speed * delta)
	
	if is_camera_returning:
		var zoom_settled: bool = \
			abs(player_camera.zoom.x - CAM_ZOOM_IDLE) < 0.001 and \
			abs(player_camera.zoom.y - CAM_ZOOM_IDLE) < 0.001
		var offset_settled: bool = player_camera.offset.length() < CONVERGENCE_EPSILON
		
		if zoom_settled and offset_settled:
			player_camera.zoom = Vector2(CAM_ZOOM_IDLE, CAM_ZOOM_IDLE)
			player_camera.offset = Vector2.ZERO
			is_camera_returning = false
			player_camera = null

# ── ENGINE AUDIO PIPELINE ──

func _toggle_engine():
	var sfx_start = get_node_or_null("EngineStart")
	var sfx_stop = get_node_or_null("EngineStop")
	var sfx_idle = get_node_or_null("EngineIdle")
	
	if not is_engine_on and not is_starting_up:
		is_starting_up = true
		if sfx_stop and sfx_stop.playing:
			sfx_stop.stop()
		if sfx_start:
			sfx_start.play()
		else:
			_on_engine_start_finished()
	elif is_engine_on and not is_starting_up:
		is_engine_on = false
		is_starting_up = false
		if sfx_idle and sfx_idle.playing:
			sfx_idle.stop()
		if sfx_stop:
			sfx_stop.play()

func _on_engine_start_finished():
	if is_starting_up:
		is_starting_up = false
		is_engine_on = true
		var sfx_idle = get_node_or_null("EngineIdle")
		if sfx_idle:
			sfx_idle.play()

func _handle_engine_audio():
	var sfx_idle = get_node_or_null("EngineIdle")
	if not sfx_idle or not sfx_idle.playing:
		return
	
	var speed_ratio: float = clampf(abs(velocity.x) / stats[boat_level]["speed"], 0.0, 1.0)
	var target_pitch: float = lerpf(1.0, 1.5, speed_ratio)
	sfx_idle.pitch_scale = clampf(target_pitch, 1.0, 1.5)

# ── HUD BUTTON VISIBILITY ──

func _set_hud_button_visible(visible: bool) -> void:
	var button = get_node_or_null(HUD_BUTTON_PATH)
	if button:
		button.visible = visible

# ── FIND FISHERMAN HELPER ──

func _get_fisherman() -> Node:
	var parent = get_parent()
	if not parent:
		return null
	return parent.get_node_or_null("Fisherman")

# ── DRIVER / BOARDING INTERFACE ──

func set_driver(active: bool):
	is_driven = active
	
	if active:
		_update_player_camera_ref()
		is_camera_returning = false
		_set_hud_button_visible(true)
	else:
		_start_camera_return()
		_set_hud_button_visible(false)

func _update_player_camera_ref() -> void:
	var fisherman = _get_fisherman()
	if fisherman:
		player_camera = fisherman.get_node_or_null("Camera2D") as Camera2D

func _start_camera_return() -> void:
	if not player_camera:
		return
	is_camera_returning = true
	target_speed_x = 0.0

# ── 180-DEGREE U-TURN SEQUENCE ──

func trigger_u_turn() -> void:
	if not is_driven or is_turning:
		return
	
	is_turning = true
	
	if u_turn_tween and u_turn_tween.is_valid():
		u_turn_tween.kill()
	
	u_turn_tween = create_tween()
	u_turn_tween.set_parallel(false)
	
	var current_vr_scale_x: float = visual_root.scale.x
	var target_final_scale_x: float = -current_vr_scale_x
	
	u_turn_tween.tween_property(
		visual_root, "scale:x", 0.0, 0.2
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	u_turn_tween.tween_callback(_u_turn_midpoint_flip)
	
	u_turn_tween.tween_property(
		visual_root, "scale:x", target_final_scale_x, 0.2
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	u_turn_tween.tween_callback(_u_turn_finished)

func _u_turn_midpoint_flip() -> void:
	velocity.x = -velocity.x
	
	var fisherman = _get_fisherman()
	if fisherman and has_node("VisualRoot/DriverSeat"):
		fisherman.global_position = $VisualRoot/DriverSeat.global_position
		var sprite = fisherman.get_node_or_null("Sprite2D") as Sprite2D
		if sprite:
			sprite.flip_h = visual_root.scale.x > 0.0

func _u_turn_finished() -> void:
	is_turning = false
	u_turn_tween = null

# ── AREA / COLLISION CALLBACKS ──

func _on_boarding_area_body_entered(body):
	if body.name == "Fisherman":
		body.nearby_boat = self

func _on_boarding_area_body_exited(body):
	if body.name == "Fisherman" and body.nearby_boat == self:
		body.nearby_boat = null

func _on_deck_area_body_entered(body):
	if body.name == "Fisherman":
		# Call the dedicated deck-entry method which saves collision state
		# and disables gravity to prevent the player's weight from pushing
		# the boat below its spring-damper equilibrium depth.
		if body.has_method("_on_deck_entered"):
			body._on_deck_entered(self)
		else:
			body.standing_boat = self

func _on_deck_area_body_exited(body):
	if body.name == "Fisherman" and body.standing_boat == self:
		if body.has_method("_on_deck_exited"):
			body._on_deck_exited()
		else:
			body.standing_boat = null

func get_boat_rotation() -> float:
	return rotation

func get_driver_seat_position() -> Vector2:
	if has_node("VisualRoot/DriverSeat"):
		return $VisualRoot/DriverSeat.global_position
	return global_position

func get_exit_position() -> Vector2:
	if has_node("VisualRoot/ExitPoint"):
		return $VisualRoot/ExitPoint.global_position
	return global_position + Vector2(-50, -20)
