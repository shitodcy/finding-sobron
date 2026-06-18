@tool
extends Node2D

@export_category("Grid Visibility")
@export var show_debug_grid: bool = true :
	set(val):
		show_debug_grid = val
		queue_redraw()

@export var base_line_thickness: float = 3.0 :
	set(val):
		base_line_thickness = val
		queue_redraw()

var master_system: Node2D = null

func _ready() -> void:
	_connect_to_master()
	
	# RUNTIME SECURITY: Automatically hide the debug grid from players when playing the game
	if not Engine.is_editor_hint():
		visible = false
	else:
		visible = true
	queue_redraw()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_connect_to_master()
		queue_redraw()

func _connect_to_master() -> void:
	if not master_system:
		master_system = get_parent()
		if master_system and master_system.has_signal("dimensions_changed"):
			if not master_system.dimensions_changed.is_connected(queue_redraw):
				master_system.dimensions_changed.connect(queue_redraw)

func _draw() -> void:
	if not show_debug_grid or not master_system:
		return
		
	if not master_system.has_method("get_cumulative_zones"):
		return
		
	var cz = master_system.get_cumulative_zones()
	var cd = master_system.get_cumulative_depths()
	var total_w = master_system.get_total_sea_width()
	var total_d = master_system.get_total_sea_depth()
	var land_w = master_system.land_width
	var sky_h = master_system.sky_height
	
	if total_w <= 0.0 or total_d <= 0.0:
		return

	# --- INFINITE SCALING THICKNESS ENGINE (MATCHES NATIVE GODOT GRID) ---
	var dynamic_thickness: float = base_line_thickness
	if Engine.is_editor_hint():
		var canvas_transform = get_global_transform_with_canvas()
		var zoom_scale: float = global_transform.get_scale().x * canvas_transform.get_scale().x
		
		if zoom_scale > 0.0001:
			# Absolute inverse scaling without upper clamp allows the line to become 
			# thousands of pixels wide in world-space so it stays exactly 'base_line_thickness' wide on screen.
			dynamic_thickness = max(base_line_thickness, (base_line_thickness + 0.1) / zoom_scale)
		else:
			dynamic_thickness = base_line_thickness

	# --- BATCH DRAWING USING GPU MULTILINE ---
	var white_lines := PackedVector2Array()
	
	# 1. Collect Vertical Zone Dividers
	for i in range(cz.size() - 1):
		white_lines.append(Vector2(cz[i], 0))
		white_lines.append(Vector2(cz[i], total_d))
		
	# 2. Collect Horizontal Depth Dividers
	for j in range(cd.size() - 1):
		white_lines.append(Vector2(0, cd[j]))
		white_lines.append(Vector2(total_w, cd[j]))
		
	# Draw all inner white grid lines in a single anti-aliased GPU pass
	if white_lines.size() > 0:
		draw_multiline(white_lines, Color(1, 1, 1, 0.6), dynamic_thickness, true)

	# 3. Draw Outer Master Boundary Box (Red Box - 4 connected lines for antialiasing stability)
	var red_box := PackedVector2Array([
		Vector2(0, 0), Vector2(total_w, 0),
		Vector2(total_w, 0), Vector2(total_w, total_d),
		Vector2(total_w, total_d), Vector2(0, total_d),
		Vector2(0, total_d), Vector2(0, 0)
	])
	draw_multiline(red_box, Color(1, 0.1, 0.2, 0.8), dynamic_thickness * 1.5, true)
	
	# 4. Draw Land/Sky Reference Box (Blue Box helper - Editor Only)
	if Engine.is_editor_hint():
		var blue_box := PackedVector2Array([
			Vector2(-land_w, -sky_h), Vector2(0, -sky_h),
			Vector2(0, -sky_h), Vector2(0, 0),
			Vector2(0, 0), Vector2(-land_w, 0),
			Vector2(-land_w, 0), Vector2(-land_w, -sky_h)
		])
		draw_multiline(blue_box, Color(0.2, 0.5, 1.0, 0.5), dynamic_thickness, true)
