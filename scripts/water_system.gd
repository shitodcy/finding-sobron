@tool
extends Node2D

signal dimensions_changed

@export_category("Darat & Langit Dimensions")
@export var land_width: float = 600.0 :
	set(val):
		land_width = val
		dimensions_changed.emit()

@export var land_height_above_water: float = 60.0 :
	set(val):
		land_height_above_water = val
		dimensions_changed.emit()

@export var sky_height: float = 600.0 :
	set(val):
		sky_height = val
		dimensions_changed.emit()

@export_category("Ocean Dimensions (Elastis)")
@export var zone_widths: Array[float] = [800.0, 1200.0, 1500.0] :
	set(val):
		zone_widths = val
		dimensions_changed.emit()

@export var depth_heights: Array[float] = [400.0, 600.0, 1000.0] :
	set(val):
		depth_heights = val
		dimensions_changed.emit()

@export_category("Batas Spesifik Game")
@export var open_sea_buffer: float = 400.0 :
	set(val):
		open_sea_buffer = val
		dimensions_changed.emit()

@export var sea_floor_camera_padding: float = 200.0 :
	set(val):
		sea_floor_camera_padding = val
		dimensions_changed.emit()

@export_category("Foam & Wave Control")
@export_range(0.005, 1.0) var foam_thickness: float = 0.15 :
	set(val):
		foam_thickness = val
		_sync_inspector_colors_to_materials()
@export var foam_line_color: Color = Color("#ffffff") :
	set(val):
		foam_line_color = val
		_sync_inspector_colors_to_materials()

@export_category("Procedural Terrain Aesthetics")
@export var continental_slope_color: Color = Color("#b05d2e") :
	set(val):
		continental_slope_color = val
		_sync_inspector_colors_to_materials()
@export var land_grass_color: Color = Color("#3cb043") :
	set(val):
		land_grass_color = val
		_sync_inspector_colors_to_materials()

@export_category("Procedural Sky Clouds")
@export_range(-1200.0, 400.0) var cloud_altitude: float = -400.0 :
	set(val):
		cloud_altitude = val
		_sync_inspector_colors_to_materials()
@export_range(0.0, 100.0) var cloud_speed: float = 12.0 :
	set(val):
		cloud_speed = val
		_sync_inspector_colors_to_materials()
@export_range(0.1, 1.0) var cloud_density_threshold: float = 0.43 :
	set(val):
		cloud_density_threshold = val
		_sync_inspector_colors_to_materials()

@export_category("Global Pixel Art Settings")
@export_range(1.0, 16.0, 1.0) var global_pixel_size: float = 4.0 :
	set(val):
		global_pixel_size = val
		_sync_inspector_colors_to_materials()

# Color references for background gradients
@export var sky_top_color: Color = Color("#1a4c80")
@export var sky_bottom_color: Color = Color("#6ba4db")
@export var sea_shallow_color: Color = Color("#1c7399")
@export var sea_deep_color: Color = Color("#081e33")
@export var ray_intensity: float = 0.4
@export var ray_absorption_depth: float = 800.0

func _ready() -> void:
	_sync_inspector_colors_to_materials()

func _sync_inspector_colors_to_materials() -> void:
	var total_depth = get_total_sea_depth()
	var land_top_world_y = -land_height_above_water
	
	# 1. Background Ocean Wave Mesh
	var ocean_mesh = get_node_or_null("OceanMesh") as Polygon2D
	if ocean_mesh and ocean_mesh.material:
		var mat = ocean_mesh.material as ShaderMaterial
		mat.set_shader_parameter("sky_top", sky_top_color)
		mat.set_shader_parameter("sky_bottom", sky_bottom_color)
		mat.set_shader_parameter("sea_shallow", sea_shallow_color)
		mat.set_shader_parameter("sea_deep", sea_deep_color)
		mat.set_shader_parameter("ray_intensity", ray_intensity)
		mat.set_shader_parameter("ray_absorption_depth", ray_absorption_depth)
		mat.set_shader_parameter("ocean_depth", total_depth)
		mat.set_shader_parameter("pixel_size", global_pixel_size)

	# 2. Foreground Wave Foam Mesh
	var foam_mesh = get_node_or_null("OceanMeshForeground") as Polygon2D
	if foam_mesh and foam_mesh.material:
		var mat = foam_mesh.material as ShaderMaterial
		mat.set_shader_parameter("foam_color", foam_line_color)
		mat.set_shader_parameter("foam_thickness", foam_thickness)
		mat.set_shader_parameter("ocean_depth", total_depth)
		mat.set_shader_parameter("pixel_size", global_pixel_size)

	# 3. Sky Background with Procedural Clouds
	var sky = get_node_or_null("SkyBackground") as ColorRect
	if sky and sky.material:
		var mat = sky.material as ShaderMaterial
		mat.set_shader_parameter("sky_top", sky_top_color)
		mat.set_shader_parameter("sky_bottom", sky_bottom_color)
		mat.set_shader_parameter("cloud_altitude", cloud_altitude)
		mat.set_shader_parameter("cloud_speed", cloud_speed)
		mat.set_shader_parameter("cloud_threshold", cloud_density_threshold)
		mat.set_shader_parameter("pixel_size", global_pixel_size)

	# 4. Unified Terrain Sync (Slope, Polygon Flat Land, and Sea Floor)
	var terrain_nodes = ["ContinentalSlopeVisual", "LandBackground", "DirtBackground"]
	for node_name in terrain_nodes:
		var node = get_node_or_null(node_name) as CanvasItem
		if node and node.material:
			var mat = node.material as ShaderMaterial
			mat.set_shader_parameter("land_color", continental_slope_color)
			mat.set_shader_parameter("grass_color", land_grass_color)
			mat.set_shader_parameter("ocean_depth", total_depth)
			mat.set_shader_parameter("land_top_y", land_top_world_y)
			mat.set_shader_parameter("pixel_size", global_pixel_size)

func get_cumulative_zones() -> PackedFloat32Array:
	var arr = PackedFloat32Array()
	var current_x: float = 0.0
	for w in zone_widths:
		current_x += w
		arr.append(current_x)
	return arr

func get_cumulative_depths() -> PackedFloat32Array:
	var arr = PackedFloat32Array()
	var current_y: float = 0.0
	for d in depth_heights:
		current_y += d
		arr.append(current_y)
	return arr

func get_total_sea_width() -> float:
	var total: float = 0.0
	for w in zone_widths:
		total += w
	return total

func get_total_sea_depth() -> float:
	var total: float = 0.0
	for d in depth_heights:
		total += d
	return total

func get_slope_zone_width() -> float:
	if zone_widths.size() > 0:
		return zone_widths[0]
	return 0.0

func get_last_zone_start() -> float:
	var total = get_total_sea_width()
	if zone_widths.size() > 0:
		return total - zone_widths[zone_widths.size() - 1]
	return total

func get_physics_info(x: float) -> Dictionary:
	var info = {
		"wave_y": 0.0,
		"wave_slope": 0.0, # Tambahkan ini untuk Rolling
		"floor_y": get_total_sea_depth(),
		"is_on_slope": false
	}
	
	var time = Time.get_ticks_msec() / 1000.0
	
	# Rumus yang disinkronkan dengan OceanMesh
	var wave_speed = 2.0
	var wave_freq = 0.02
	var wave_amp = 5.0
	
	# Kalkulasi Y
	info.wave_y = sin(time * wave_speed + x * wave_freq) * wave_amp
	info.wave_y += cos(time * (wave_speed * 0.7) + x * (wave_freq * 1.2)) * (wave_amp * 0.3)
	
	# Kalkulasi Slope (Turunan pertama dari rumus di atas untuk menentukan kemiringan)
	var deriv = cos(time * wave_speed + x * wave_freq) * (wave_amp * wave_freq)
	deriv -= sin(time * (wave_speed * 0.7) + x * (wave_freq * 1.2)) * (wave_amp * 0.3 * wave_freq * 1.2)
	info.wave_slope = atan(deriv) # Hasilnya dalam radian
	
	# (Logika floor_y tetap sama...)
	var slope_w = get_slope_zone_width()
	if x >= 0.0 and x <= slope_w and slope_w > 0.0:
		info.floor_y = (x / slope_w) * get_total_sea_depth()
		info.is_on_slope = true
	
	return info
