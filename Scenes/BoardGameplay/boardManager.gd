extends Node3D

@export var tile_size: float = 2.0;
@export var grid_size: Vector2i = Vector2i(6, 3);
@export var spacing = 0.6;

#state management
enum GameState {PLANNING, EXECUTING, ENEMY_TURN};
var current_state = GameState.PLANNING;

var grid_data = {};


# Added these to sync the clicking math with the centered board
var grid_offset: Vector3
var total_width: float
var total_depth: float

#current held piece 
var held_piece_type = null;
var hand_pieces = [];

#mouse tracking for interaction
var selected_piece_node: Node3D = null;
var mouse_velocity: float = 0.0;
var spin_velocity: float = 0.0;
@export var spin_friction: float = 0.96;
@export var spin_sensitivity: float = 0.5;


func _on_coin_clicked(piece_node):
	# Check if we are clicking the piece we already have selected
	if selected_piece_node == piece_node:
		selected_piece_node = null # Deselect
		held_piece_type = null
		print("Deselected piece")
		return

	# IMPORTANT: Update the variable so _process knows to lift this node
	selected_piece_node = piece_node
	held_piece_type = piece_node.get_meta("piece_type") 
	
	print("Picked Up: ", held_piece_type, " (", selected_piece_node.name, ")")
	
	# Reset spin speed when picking up a new one
	spin_velocity = 0.0
	
func create_mock_hand():
	
	for i in range(5):
		var piece_path = ""
		@warning_ignore("shadowed_global_identifier")
		var type_string = ""
		var debug_color = Color.WHITE

		# Alternate between Bottom (Legs) and Top (Head)
		if i % 2 == 0:
			piece_path = "res://Scenes/BoardGameplay/Pieces/BaseBottom.tscn"
			type_string = "bottom"
			debug_color = Color.MEDIUM_SPRING_GREEN # Green for Bottoms
		else:
			piece_path = "res://Scenes/BoardGameplay/Pieces/BaseTop.tscn"
			type_string = "top"
			debug_color = Color.SKY_BLUE # Blue for Tops

		var piece = load(piece_path).instantiate()
		$Camera3D.add_child(piece)
		
		# Position and Rotate (Sideways Stack)
		var x_pos = (i - 2) * spacing;
		piece.position = Vector3(x_pos, -1, -2.0)
		piece.rotation_degrees = Vector3(90, 90, 0)
		piece.name = "HandPiece_" + str(i)
		
		# Assign the type so _on_coin_clicked knows what it is
		piece.set_meta("piece_type", type_string)
		
		# Temporary Coloring (Assumes your scene has a MeshInstance3D child)
		# This makes it easy to see which is which in the tray
		var mesh = piece.get_child(0) # Grabs the Cylinder
		if mesh is MeshInstance3D:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = debug_color
			mesh.material_override = mat

		hand_pieces.append(piece)
#Data Storing
#Checks each tile and what is on it currently 
func _ready():
	# Calculate centering math once so spawning and clicking align
	total_width = (grid_size.x - 1) * tile_size
	total_depth = (grid_size.y - 1) * tile_size
	grid_offset = Vector3(-total_width / 2, 0.05, -total_depth / 2)
	
	initialize_grid();
	
	create_mock_hand();

func initialize_grid():
	
	var offset = Vector3(-total_width / 2, 0.05, -total_depth / 2);
	
	for x in grid_size.x:
		for z in grid_size.y:
			grid_data[Vector2i(x,z)] = {"bottom": null, "top": null, "terrain": null}; 
			
			#create the visual of the grid
			var tile_mesh = MeshInstance3D.new();
			tile_mesh.mesh = BoxMesh.new();
			
			#flatten tile 
			tile_mesh.scale = Vector3(tile_size * 0.9, 0.1, tile_size * 0.9);
			
			#position the tiles
			tile_mesh.position = offset + Vector3(x * tile_size, 0, z * tile_size);
			
			#materials
			var mat = StandardMaterial3D.new();
			mat.albedo_color = Color.DARK_GRAY;
			tile_mesh.material_override = mat;
			
			$GridRoot.add_child(tile_mesh);
			
			#Add hitbox to tile meshes
			var static_body = StaticBody3D.new();
			var collision_shape = CollisionShape3D.new();
			var box_shape = BoxShape3D.new();
			
			#set shape to size of tile
			box_shape.size = Vector3(tile_size, 0.1, tile_size);
			collision_shape.shape = box_shape;
			
			tile_mesh.add_child(static_body);
			static_body.add_child(collision_shape);

#interaction logic
func _input(event):
	#only allow placement during planning
	if current_state != GameState.PLANNING:
		return;
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		#raycast logic for piecce selection
		var space_state = get_world_3d().direct_space_state;
		var mouse_pos = get_viewport().get_mouse_position()
		var ray_origin = $Camera3D.project_ray_origin(mouse_pos);
		var ray_target = ray_origin + $Camera3D.project_ray_normal(mouse_pos) * 100;
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_target);
		var result = space_state.intersect_ray(query);
	
		if result:
			var hit_node = result.collider.get_parent();
			if hit_node.name.begins_with("HandPiece"):
				_on_coin_clicked(hit_node);
				return;
				
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var coords = get_grid_coords_at_mouse();
			if coords != null:
				handle_tile_click(coords);

func _process(_delta):
	if current_state != GameState.PLANNING: return;
	
	#track mouse velocity
	var current_mouse_x = get_viewport().get_mouse_position().x;
	if not self.has_meta("last_mouse_x"): self.set_meta("last_mouse_x", current_mouse_x);
	
	var mouse_velocity_x = current_mouse_x - self.get_meta("last_mouse_x");
	self.set_meta("last_mouse_x", current_mouse_x);
	
	
	#Hover Check
	var space_state = get_world_3d().direct_space_state;
	var mouse_pos = get_viewport().get_mouse_position();
	var ray_origin = $Camera3D.global_position;
	var ray_target = ray_origin + $Camera3D.project_ray_normal(mouse_pos) * 50;
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_target);
	var result = space_state.intersect_ray(query);
	
	for i in range(hand_pieces.size()):
		var p = hand_pieces[i]
		var is_hovered = result and result.collider.get_parent() == p
		var is_selected = (selected_piece_node == p)
		
		if is_selected:
			# LIFT UP: Moving Y toward 0 or positive moves it "up" the screen
			# We keep Z at -2.0 so it stays in line with the tray
			p.position.y = lerp(p.position.y, -0.2, 0.1) 
			p.position.z = lerp(p.position.z, -2.0, 0.1) 
			p.scale = p.scale.lerp(Vector3(1.2, 1.2, 1.2), 0.1)
				# Keep the coin vertical (X/Z at 0)
			p.rotation.x = lerp_angle(p.rotation.x, deg_to_rad(90), 0.1)
			p.rotation.z = lerp_angle(p.rotation.z, 0, 0.1)
				
				# Continuous Spin + Mouse Interaction
			if is_hovered:
				spin_velocity += mouse_velocity_x * spin_sensitivity
			
			# Rotation around the upright axis
			p.rotate_y(deg_to_rad(120 + spin_velocity) * _delta)
			spin_velocity *= spin_friction
			
		else:
			# --- BRANCH B: TRAY PIECES ---
			# Slight scale pop on hover, otherwise 1.0
			var target_scale = Vector3(1.15, 1.15, 1.15) if is_hovered else Vector3(1, 1, 1)
			p.scale = p.scale.lerp(target_scale, 0.2)
			
			# Stay low in the tray
			p.position.y = lerp(p.position.y, -1.0, 0.1)
			p.position.z = lerp(p.position.z, -2.0, 0.1)
			
			# Return to "standing on edge" orientation
			var tray_rot = Vector3(deg_to_rad(90), deg_to_rad(90), 0)
			p.rotation.x = lerp_angle(p.rotation.x, tray_rot.x, 0.1)
			p.rotation.y = lerp_angle(p.rotation.y, tray_rot.y, 0.1)
			p.rotation.z = lerp_angle(p.rotation.z, tray_rot.z, 0.1)

#converts mouse position to coords
func get_grid_coords_at_mouse() -> Variant:
	var mouse_pos = get_viewport().get_mouse_position();
	var ray_origin = $Camera3D.project_ray_origin(mouse_pos);
	var ray_target = ray_origin + $Camera3D.project_ray_normal(mouse_pos) * 100;
	
	var space_state = get_world_3d().direct_space_state;
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_target);
	var result = space_state.intersect_ray(query);
	
	if result:
		var local_pos = to_local(result.position);
		# Adjusted math: subtract the offset so clicking the center works correctly
		var gx = round((local_pos.x - grid_offset.x) / tile_size);
		var gz = round((local_pos.z - grid_offset.z) / tile_size);
		
		return Vector2i(clampi(gx, 0, grid_size.x -1), clampi(gz, 0, grid_size.y -1));
	return null
	
# gameplay Logic
func handle_tile_click(coords: Vector2i):
	var cell = grid_data[coords];
	
	# Only place if we are holding something
	if held_piece_type == "bottom":
		if cell["bottom"] == null:
			spawn_bottom(coords);
			held_piece_type = null # Reset hand after placing
		else:
			print("Already has a bottom!")
			
	elif held_piece_type == "top":
		if cell["bottom"] != null and cell["top"] == null:
			spawn_top(coords);
			held_piece_type = null # Reset hand after placing
		elif cell["bottom"] == null and cell["top"] != null:
			spawn_bottom(coords);
			reparent_top_to_bottom(coords);
			held_piece_type = null
			
func spawn_bottom(coords: Vector2i):
	var legs = load("res://Scenes/BoardGameplay/Pieces/BaseBottom.tscn").instantiate();
	$PieceRoot.add_child(legs);
	# Use grid_offset here so the checker spawns exactly on the visual tile
	legs.position = grid_offset + Vector3(coords.x * tile_size, 0.1, coords.y * tile_size);
	grid_data[coords]["bottom"] = legs;
	
func spawn_top(coords: Vector2i):
	var top = load("res://Scenes/BoardGameplay/Pieces/BaseTop.tscn").instantiate();
	var bottom = grid_data[coords]["bottom"];
	var socket = bottom.get_node("TopSocket")
	socket.add_child(top);
	top.position = Vector3.ZERO;
	grid_data[coords]["top"] = top;

func reparent_top_to_bottom(coords: Vector2i):
	var top = grid_data[coords]["top"];
	var bottom = grid_data[coords]["bottom"];
	var socket = bottom.get_node("TopSocket");
	
	top.get_parent().remove_child(top);
	socket.add_child(top);
	top.position= Vector3.ZERO;
