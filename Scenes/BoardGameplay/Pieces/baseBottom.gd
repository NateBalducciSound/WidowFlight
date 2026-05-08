extends Node3D

# basic stat declaration
@export var move_distance: int = 1;
@export var base_hp: int = 2;
@export var weight: int = 1;

# current stat check and state
@export var current_hp: int = 0;

func _ready():
	# Default to full health
	current_hp = base_hp;
	
	# Wait a tiny frame to ensure any Top pieces added by the board script are actually there
	await get_tree().process_frame
	refresh_status()

func refresh_status():
	var socket = get_node_or_null("TopSocket")
	
	# If the piece is in the Hand, we might not want to apply "headless" penalties yet
	if get_parent() and get_parent().name.begins_with("Camera3D"):
		return 

	if socket:
		if socket.get_child_count() == 0:
			current_hp = 1;
			print("Piece is headless: HP reduced to 1")
		else:
			current_hp = base_hp;
			print("Piece is whole: HP restored to ", base_hp)
	else:
		# Fallback if TopSocket is missing from the scene entirely
		current_hp = 1;
