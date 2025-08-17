extends Node3D

var move_input: Vector2

var rot: float = PI/4.
var pos: Vector3 = Vector3.ZERO

func _input(event: InputEvent) -> void:
	move_input = Input.get_vector("move_left","move_right","move_forward"," move_backward")

	if Input.is_action_just_pressed("turn_left"): turn(-1)
	if Input.is_action_just_pressed("turn_right"): turn(1)

func _process(delta: float) -> void:
	var move_dir: Vector3 = basis*Vector3(move_input.x,0.,move_input.y)
	pos += move_dir*delta*6.

	# apply pos and rot
	global_position = global_position.lerp(pos, delta * 8.) if global_position.distance_to(pos) > 0.02 else pos
	rotation.y = lerp_angle(rotation.y, rot, delta * 8.0) if abs(rotation.y - rot) > .002 else rot

func turn(dir: float) -> void:
	rot += (PI*.125)*dir
