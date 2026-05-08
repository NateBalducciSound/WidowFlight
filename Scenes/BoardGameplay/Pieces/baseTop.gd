extends Node3D

@export var base_attack: int = 3;
@export var base_hp_bonus: int = 2; #if has top gain extra health
@export var attack_range: int = 1;

#lose attack if no legs
func get_effective_attack() -> int:
	# If the parent is PieceRoot, it means it's sitting on the board without legs
	if get_parent().name == "PieceRoot":
		return base_attack - 1;
	return base_attack;
	
func get_stats():
	return {
		"atk": get_effective_attack(),
		"range": attack_range,
		"has_legs": get_parent() is Marker3D
	}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# If not attached to a TopSocket (Marker3D), dim the piece
	if not get_parent() is Marker3D:
		# 3D FIX: We must dim the material albedo, not 'modulate'
		var mesh = get_node_or_null("MeshInstance3D")
		if mesh:
			# Create a unique material so we don't dim ALL tops at once
			var mat = mesh.get_active_material(0).duplicate()
			mat.albedo_color = Color(0.6, 0.6, 0.6) # Dimmed gray
			mesh.material_override = mat


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
