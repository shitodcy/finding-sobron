@tool
extends Polygon2D

@export_category("Wave Parameters")
@export var wave_count: int = 80
@export var wave_amplitude: float = 5.0
@export var wave_frequency: float = 0.02
@export var wave_speed: float = 2.0

var master_system: Node2D = null
var _time: float = 0.0

func _ready() -> void:
	_connect_to_master()
	_rebuild_mesh()

func _process(delta: float) -> void:
	_time += delta
	_animate_waves()
	
	if Engine.is_editor_hint():
		_connect_to_master()
		_rebuild_mesh()

func _connect_to_master() -> void:
	if not master_system:
		master_system = get_parent()
		if master_system and master_system.has_signal("dimensions_changed"):
			if not master_system.dimensions_changed.is_connected(_rebuild_mesh):
				master_system.dimensions_changed.connect(_rebuild_mesh)

func _rebuild_mesh() -> void:
	if not master_system or not master_system.has_method("get_total_sea_width"):
		return
		
	position = Vector2.ZERO
	rotation = 0.0
	scale = Vector2.ONE
	
	var w: float = master_system.get_total_sea_width()
	var d: float = master_system.get_total_sea_depth()
	
	if w <= 0.0 or d <= 0.0:
		return
		
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var step: float = w / float(wave_count)
	
	for i in range(wave_count + 1):
		var x: float = i * step
		vertices.append(Vector2(x, 0.0))
		uvs.append(Vector2(x / w, 0.0))
		
	var deep_pad: float = d + 400.0
	
	vertices.append(Vector2(w, deep_pad))
	uvs.append(Vector2(1.0, 1.0))
	
	vertices.append(Vector2(0.0, deep_pad))
	uvs.append(Vector2(0.0, 1.0))
	
	polygon = vertices
	uv = uvs
	
	var mat = material as ShaderMaterial
	if mat:
		var cz = master_system.get_cumulative_zones()
		var cd = master_system.get_cumulative_depths()
		
		if cz.size() >= 3 and cd.size() >= 3:
			mat.set_shader_parameter("zone_1_end_ratio", cz[0] / w)
			mat.set_shader_parameter("zone_2_end_ratio", cz[1] / w)
			mat.set_shader_parameter("depth_1_end_ratio", cd[0] / d)
			mat.set_shader_parameter("depth_2_end_ratio", cd[1] / d)

func _animate_waves() -> void:
	if polygon.size() < (wave_count + 3) or not master_system:
		return
		
	var w: float = master_system.get_total_sea_width()
	var step: float = w / float(wave_count)
	var current_vertices := polygon
	
	for i in range(wave_count + 1):
		var x: float = i * step
		var y: float = sin(_time * wave_speed + x * wave_frequency) * wave_amplitude
		y += cos(_time * (wave_speed * 0.7) + x * (wave_frequency * 1.2)) * (wave_amplitude * 0.3)
		current_vertices[i] = Vector2(x, y)
		
	polygon = current_vertices
