extends CharacterBody3D;

@export var stepSize: float = 2.0;
@export var moveSpeed: float = 0.3;
@onready var ray = $RayCast3D; 
@onready var cam = $Camera3D;

var is_moving: bool = false;



func _physics_process(_delta):
	#if we are moving dont allow input
	if is_moving:
		return;
	
	#check for arrow keys or wasd
	if Input.is_action_just_pressed("ui_up"):
		movePlayer(Vector3.FORWARD);
	if Input.is_action_just_pressed("ui_down"):
		movePlayer(Vector3.BACK);
	if Input.is_action_just_pressed("ui_left"):
		rotatePlayer(90);
	if Input.is_action_just_pressed("ui_right"):
		rotatePlayer(-90);

func movePlayer(direction: Vector3):
	#New raycast addition make sure its pointing in the right dir
	ray.target_position = direction * stepSize;
	
	#cause the ray cast to update automatically
	ray.force_raycast_update();
	
	if ray.is_colliding():
		#create var for shake tween
		var shake = create_tween();
		#move cam .2 units and back
		shake.tween_property(cam, "position:z", -.2, 0.05);
		shake.tween_property(cam,"position:z", 0.0, 0.1);
		print("Wall Collide.");
		return;
	
	is_moving = true;
	#calc direction
	var target_position = global_position + (transform.basis * direction * stepSize);
	#smoothing lerp
	var tween = create_tween();
	tween.tween_property(self, "global_position", target_position, moveSpeed);
	
	tween.finished.connect(func(): is_moving = false);
	
func rotatePlayer(angleDegrees: float):
	is_moving = true;
	var tween = create_tween();
	#rotate using y property on player
	var target_rotation = rotation.y + deg_to_rad(angleDegrees);
	tween.tween_property(self, "rotation:y", target_rotation, moveSpeed);
	
	var camTween = create_tween();
	var tiltAngle = deg_to_rad(2.0) if angleDegrees > 0 else deg_to_rad(-2.0);
	camTween.tween_property(cam, "rotation:z", tiltAngle, moveSpeed /2.0);
	camTween.tween_property(cam, "rotation:z", 0.0, moveSpeed /2.0);
	
	
	tween.finished.connect(func(): is_moving = false);
