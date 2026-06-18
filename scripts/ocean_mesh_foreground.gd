@tool
extends Polygon2D

var master_system: Node2D = null
var background_mesh: Polygon2D = null

func _ready() -> void:
	z_index = 2 # Correct foreground layering above game assets
	_cache_nodes()
	_sync_with_master()

func _process(_delta: float) -> void:
	_cache_nodes()
	_sync_with_master()

func _cache_nodes() -> void:
	master_system = get_parent()
	if master_system:
		background_mesh = master_system.get_node_or_null("OceanMesh")

func _sync_with_master() -> void:
	if not background_mesh:
		return
	# Real-time synchronization of wave geometry only, leaving coloration entirely to the shader
	polygon = background_mesh.polygon
	uv = background_mesh.uv
