extends Control
class_name PixelContainer

@onready var container: SubViewportContainer = $SubViewportContainer
@onready var viewport: SubViewport = $SubViewportContainer/Viewport
@export var pixel_movement: bool = true
@export var sub_pixel_movement_at_integer_scale: bool = false


func _process(_delta: float) -> void:
	var screen_size: Vector2 = get_window().size
	
	# dynamically change viewport size based on aspect ratio
	viewport.size = Vector2i(screen_size / container.stretch_shrink)

	# viewport size minus padding
	var game_size: Vector2 = viewport.size - Vector2i(2, 2)
	var display_scale: Vector2 = screen_size / game_size

	# maintain aspect ratio
	var display_scale_min: float = minf(display_scale.x, display_scale.y)
	container.scale = Vector2(display_scale_min, display_scale_min)
	
	# scale and center control node
	size = (container.scale * game_size).round()
	position = ((screen_size - size) / 2).round()
	
	# smooth!
	if pixel_movement:
		var cam: Camera3DTexelSnapped = viewport.get_camera_3d()
		var pixel_error: Vector2 = cam.texel_error * container.scale
		container.position = container.position.lerp(-container.scale + pixel_error, _delta*15)
		var is_integer_scale: bool = display_scale == display_scale.floor()
		if is_integer_scale && !sub_pixel_movement_at_integer_scale:
			container.position = container.position.round()
