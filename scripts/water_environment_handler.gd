@tool
extends StaticBody2D

@export var camera_path: NodePath

var master_system: Node2D = null
var sky_node: ColorRect = null
var dirt_node: Polygon2D = null
var land_node: Polygon2D = null
var dock_node: StaticBody2D = null

var col_left: CollisionShape2D = null
var col_right: CollisionShape2D = null
var col_top: CollisionShape2D = null
var col_bottom: CollisionShape2D = null
var col_land_top: CollisionShape2D = null
var col_land_wall: CollisionShape2D = null
var slope_col: CollisionPolygon2D = null

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	_cache_nodes()
	_connect_to_master()
	_update_environment_and_bounds()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_cache_nodes()
		_connect_to_master()
		_update_environment_and_bounds()

func _cache_nodes() -> void:
	master_system = get_parent()
	if master_system:
		sky_node = master_system.get_node_or_null("SkyBackground")
		dirt_node = master_system.get_node_or_null("DirtBackground") as Polygon2D
		land_node = master_system.get_node_or_null("LandBackground") as Polygon2D
		dock_node = master_system.get_node_or_null("Dock")
		
	col_left = get_node_or_null("CollisionLeft")
	col_right = get_node_or_null("CollisionRight")
	col_top = get_node_or_null("CollisionTop")
	col_bottom = get_node_or_null("CollisionBottom")
	col_land_top = get_node_or_null("CollisionLandTop")
	col_land_wall = get_node_or_null("CollisionLandWall")
	slope_col = get_node_or_null("ContinentalSlopeCollision") as CollisionPolygon2D

func _connect_to_master() -> void:
	if master_system and master_system.has_signal("dimensions_changed"):
		if not master_system.dimensions_changed.is_connected(_update_environment_and_bounds):
			master_system.dimensions_changed.connect(_update_environment_and_bounds)

func _get_rugged_noise(x: float) -> float:
	var n = sin(x * 0.014) * 28.0
	n += cos(x * 0.033) * 14.0
	n += sin(x * 0.085) * 6.0
	return floor(n / 4.0) * 4.0

func _update_environment_and_bounds() -> void:
	if not master_system or not master_system.has_method("get_total_sea_width"):
		return
		
	var total_w = master_system.get_total_sea_width()
	var total_d = master_system.get_total_sea_depth()
	var land_w = master_system.land_width
	var land_h_above = master_system.land_height_above_water
	var sky_h = master_system.sky_height
	var cam_floor_pad = master_system.sea_floor_camera_padding
	var slope_w = master_system.get_slope_zone_width()
	
	if total_w <= 0.0 or total_d <= 0.0:
		return
		
	position = Vector2.ZERO
	rotation = 0.0
	scale = Vector2.ONE

	if dock_node:
		dock_node.position = Vector2.ZERO

	if sky_node:
		sky_node.position = Vector2(-land_w, -sky_h)
		sky_node.size = Vector2(land_w + total_w, sky_h + 300.0)

	var step_size: float = 40.0
	
	# 1. Build Jagged Continental Slope Visual Polygon
	var slope_points: Array[Vector2] = [Vector2(-land_w, 0)]
	var curr_x: float = 0.0
	while curr_x <= slope_w:
		var t = curr_x / slope_w if slope_w > 0 else 0.0
		var base_y = t * total_d
		slope_points.append(Vector2(curr_x, base_y + _get_rugged_noise(curr_x)))
		curr_x += step_size
	slope_points.append(Vector2(-land_w, total_d))
	
	var slope_vis = master_system.get_node_or_null("ContinentalSlopeVisual") as Polygon2D
	if slope_vis:
		slope_vis.polygon = PackedVector2Array(slope_points)
		slope_vis.z_index = 3
		if not Engine.is_editor_hint():
			slope_vis.visible = true

	# 2. Build Jagged Dirt Seabed Visual Polygon
	var dirt_points: Array[Vector2] = []
	curr_x = slope_w
	while curr_x <= total_w:
		dirt_points.append(Vector2(curr_x, total_d + _get_rugged_noise(curr_x)))
		curr_x += step_size
		
	var dirt_thick = 600.0
	dirt_points.append(Vector2(total_w, total_d + dirt_thick))
	dirt_points.append(Vector2(-land_w, total_d + dirt_thick))
	dirt_points.append(Vector2(-land_w, total_d))
	
	if dirt_node:
		dirt_node.polygon = PackedVector2Array(dirt_points)
		dirt_node.z_index = 4  # Dirt stays in front of slope
		if not Engine.is_editor_hint():
			dirt_node.visible = true

	# 3. REVISED: LandBackground shape perfectly fits the slope angle without jagged leakage
	if land_node:
		var slope_top_noise = _get_rugged_noise(0.0)
		var land_points: Array[Vector2] = [
			Vector2(-land_w, -land_h_above),                    # Top Left
			Vector2(0.0, -land_h_above),                        # Top Right
			Vector2(0.0, 0.0 + slope_top_noise),                # Intersection point matching top slope vertex
			Vector2(-land_w, 0.0 + slope_top_noise)             # Adjusted straight down bottom edge alignment
		]
		land_node.polygon = PackedVector2Array(land_points)
		land_node.z_index = 2

	# 4. Build Unified Master Terrain Physics Collision
	var master_physics_points: Array[Vector2] = [Vector2(-land_w, 0)]
	curr_x = 0.0
	while curr_x <= slope_w:
		var t = curr_x / slope_w if slope_w > 0 else 0.0
		master_physics_points.append(Vector2(curr_x, (t * total_d) + _get_rugged_noise(curr_x)))
		curr_x += step_size
	curr_x = slope_w + step_size
	while curr_x <= total_w:
		master_physics_points.append(Vector2(curr_x, total_d + _get_rugged_noise(curr_x)))
		curr_x += step_size
	master_physics_points.append(Vector2(total_w, total_d + dirt_thick))
	master_physics_points.append(Vector2(-land_w, total_d + dirt_thick))
	
	if slope_col:
		slope_col.polygon = PackedVector2Array(master_physics_points)

	# Standard boundaries (Left, Right, Top, and Walkable Land Top)
	var wall_t: float = 100.0
	if col_left and col_left.shape is RectangleShape2D:
		col_left.position = Vector2(-land_w - (wall_t / 2.0), (total_d - sky_h) / 2.0)
		col_left.shape.size = Vector2(wall_t, sky_h + total_d)
	if col_right and col_right.shape is RectangleShape2D:
		var playable_end_x = master_system.get_last_zone_start()
		col_right.position = Vector2(playable_end_x + (wall_t / 2.0), (total_d - sky_h) / 2.0)
		col_right.shape.size = Vector2(wall_t, sky_h + total_d)
	if col_top and col_top.shape is RectangleShape2D:
		col_top.position = Vector2((total_w - land_w) / 2.0, -sky_h - (wall_t / 2.0))
		col_top.shape.size = Vector2(land_w + total_w, wall_t)
	if col_land_top and col_land_top.shape is RectangleShape2D:
		col_land_top.position = Vector2(-land_w / 2.0, -land_h_above + (wall_t / 2.0))
		col_land_top.shape.size = Vector2(land_w, wall_t)
	if col_land_wall and col_land_wall.shape is RectangleShape2D:
		col_land_wall.position = Vector2(-(wall_t / 2.0), total_d / 2.0)
		col_land_wall.shape.size = Vector2(wall_t, total_d)
	if col_bottom:
		col_bottom.position = Vector2(0, -99999)

	# REVISED REMOVAL: We DO NOT manually overwrite ocean_mesh.polygon vertices here anymore.
	# We let ocean_mesh.gd and ocean_mesh_foreground handle their own optimized vertex grids safely.
	var ocean_mesh = master_system.get_node_or_null("OceanMesh") as Polygon2D
	if ocean_mesh: ocean_mesh.z_index = -10
		
	var foam_mesh = master_system.get_node_or_null("OceanMeshForeground") as Polygon2D
	if foam_mesh:
		foam_mesh.z_index = 5
		if not Engine.is_editor_hint():
			foam_mesh.visible = true

	var boat_node = master_system.get_node_or_null("../../Boat")
	if boat_node and boat_node.has_method("set_physics_bounds"):
		boat_node.set_physics_bounds(-land_w, master_system.get_last_zone_start(), -sky_h, total_d)

	if master_system and master_system.has_method("_sync_inspector_colors_to_materials"):
		master_system._sync_inspector_colors_to_materials()

	var cam = get_node_or_null(camera_path) as Camera2D if has_node(camera_path) else get_viewport().get_camera_2d()
	if cam:
		cam.limit_left = int(-land_w)
		cam.limit_right = int(total_w)
		cam.limit_top = int(-sky_h)
		cam.limit_bottom = int(total_d + cam_floor_pad)
