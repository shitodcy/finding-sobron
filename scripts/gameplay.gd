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
var power_direction := 1 

@export_category("UI References")
@export var casting_bar: ProgressBar
@export var result_panel: Control

@export_category("Fishing Settings")
# Sesuaikan angka ini di Inspector Godot untuk menurunkan batas air!
@export var water_level_offset: float = 120.0 
@export var retrieve_speed: float = 250.0

@onready var lure = get_node_or_null("Lure")
@onready var fisherman = get_node_or_null("Fisherman")
@onready var fishing_line = get_node_or_null("FishingLine")
@onready var boat = get_node_or_null("Boat")

func _ready():
	if casting_bar == null:
		casting_bar = get_tree().current_scene.find_child("CastingBar", true, false)
	if result_panel == null:
		result_panel = get_tree().current_scene.find_child("ResultPanel", true, false)
		
	if casting_bar == null:
		push_warning("CastingBar tidak ditemukan! Pastikan node ProgressBar bernama persis 'CastingBar'.")
		
	if fisherman and not fisherman.has_node("DummyRod"):
		push_warning("Peringatan Visual: Node 'DummyRod' tidak ditemukan di dalam Fisherman.")
		
	if lure: lure.visible = false
	if fishing_line: fishing_line.visible = false
	if casting_bar: casting_bar.visible = false
	if result_panel: result_panel.visible = false

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

	var can_fish = is_ready_to_fish()
	
	if can_fish and not is_fishing_mode and current_state == State.SAILING:
		is_fishing_mode = true
		if fisherman.has_node("DummyRod"): 
			fisherman.get_node("DummyRod").visible = true
			
	elif not can_fish and is_fishing_mode:
		matikan_mode_memancing()
		batalkan_pancingan()

	if current_state == State.SAILING:
		if not is_fishing_mode:
			return
			
		if Input.is_action_just_pressed("cast"):
			charging = true
			cast_power = 0.0
			power_direction = 1
			if casting_bar:
				casting_bar.visible = true
				casting_bar.max_value = max_cast_power
				casting_bar.value = 0.0
			
		if Input.is_action_pressed("cast") and charging:
			cast_power += 600.0 * delta * power_direction
			if cast_power >= max_cast_power:
				cast_power = max_cast_power
				power_direction = -1
			elif cast_power <= 0.0:
				cast_power = 0.0
				power_direction = 1
				
			if casting_bar:
				casting_bar.value = cast_power
			
		if Input.is_action_just_released("cast") and charging:
			charging = false
			if casting_bar:
				casting_bar.visible = false
			start_cast()

	elif current_state == State.SINKING or current_state == State.RETRIEVE:
		# MEKANIK MENARIK (RETRIEVE): Tahan Klik Kiri Lagi!
		if Input.is_action_pressed("cast"):
			current_state = State.RETRIEVE
			lure.is_retrieving = true
			lure.is_sinking = false
			
			var rod_tip = get_rod_tip_position()
			var pull_dir = (rod_tip - lure.global_position).normalized()
			
			var current_speed = retrieve_speed * lure.drag_multiplier
			lure.global_position += pull_dir * current_speed * delta
			
			# Jika umpan ditarik sampai ke tangan, pancingan di-reset dan siap lempar ulang
			if lure.global_position.distance_to(rod_tip) < 20.0:
				batalkan_pancingan()
		else:
			current_state = State.SINKING
			lure.is_retrieving = false
			lure.is_sinking = true

func start_cast():
	current_state = State.CASTING
	lure.visible = true
	
	var is_facing_left = fisherman.get_node("Sprite2D").flip_h
	var throw_direction = -1 if is_facing_left else 1
	
	lure.global_position = get_rod_tip_position()
	lure.velocity = Vector2(cast_power * throw_direction, -150.0)
	lure.is_sinking = false
	lure.is_retrieving = false
	
	lure.target_water_y = fisherman.global_position.y + water_level_offset

func is_ready_to_fish() -> bool:
	if fisherman == null: return false
	if fisherman.current_state == fisherman.PlayerState.DRIVING: return false
	
	if fisherman.standing_boat != null or fisherman.nearby_boat != null:
		return true
		
	if boat != null:
		var jarak_ke_kapal = fisherman.global_position.distance_to(boat.global_position)
		if jarak_ke_kapal < 150.0:
			return true
			
	return false

func matikan_mode_memancing():
	is_fishing_mode = false
	if fisherman and fisherman.has_node("DummyRod"): 
		fisherman.get_node("DummyRod").visible = false

func batalkan_pancingan():
	current_state = State.SAILING
	charging = false
	if lure:
		lure.visible = false
		lure.is_sinking = false
		lure.is_retrieving = false
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
	
	match current_state:
		State.SINKING:
			fishing_line.default_color = Color.WHITE
		State.RETRIEVE:
			fishing_line.default_color = Color.ORANGE
		State.STRIKE:
			fishing_line.default_color = Color.RED
		_:
			fishing_line.default_color = Color.WHITE

func _on_fish_strike(fish_node):
	current_state = State.STRIKE
	
	await get_tree().create_timer(1.2).timeout
	tampilkan_result(fish_node)

func tampilkan_result(fish_node):
	current_state = State.RESULT
	
	if is_instance_valid(fish_node):
		fish_node.queue_free()
		
	batalkan_pancingan()
	matikan_mode_memancing()
	
	if result_panel:
		result_panel.visible = true
