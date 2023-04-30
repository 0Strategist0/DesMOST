# The viewport that stores the images to be transformed
extends Viewport

# Complex functions
func cconj(z: Vector2) -> Vector2:
	return Vector2(z.x, -z.y)
func cadd(a: Vector2, b: Vector2) -> Vector2:
	return a + b
func csub(a: Vector2, b: Vector2) -> Vector2:
	return a - b
func cmult(a: Vector2, b: Vector2) -> Vector2:
	return Vector2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x)
func cdiv(a: Vector2, b: Vector2) -> Vector2:
	return cmult(a, cconj(b)) / b.length_squared()
func cexp(z: Vector2) -> Vector2:
	return exp(z.x) * Vector2(cos(z.y), sin(z.y))
func clog(z: Vector2) -> Vector2:
	var polar_z := cartesian2polar(z.x, z.y)
	return Vector2(log(polar_z.x), polar_z.y)
func cpow(a: Vector2, b: Vector2) -> Vector2:
	return cexp(cmult(clog(a), b))
func csin(z: Vector2) -> Vector2:
	return cmult(Vector2(0.0, -0.5), 
				csub(cexp(cmult(Vector2(0.0, 1.0), z)), 
					cexp(cmult(Vector2(0.0, -1.0), z))))
func ccos(z: Vector2) -> Vector2:
	return cmult(Vector2(0.5, 0.0), 
				cadd(cexp(cmult(Vector2(0.0, 1.0), z)), 
					cexp(cmult(Vector2(0.0, -1.0), z))))
func ctan(z: Vector2) -> Vector2:
	return cdiv(csin(z), ccos(z))
func carg(z: Vector2) -> Vector2:
	return Vector2(cartesian2polar(z.x, z.y).y, 0.0)
func cmod(z: Vector2) -> Vector2:
	return Vector2(z.length(), 0.0)
func creal(z: Vector2) -> Vector2:
	return Vector2(z.x, 0.0)
func cimag(z: Vector2) -> Vector2:
	return Vector2(z.y, 0.0)
func csqrt(z: Vector2) -> Vector2:
	return cpow(z, Vector2(0.5, 0.0))

# Get the node that you drop images into
onready var input_rect := $"%Input"
onready var output_rect := $"%Output"
onready var txtbar := $"%FunctionBar"
onready var draw_button := $"%DrawButton"

# Define some variables
var scaling := 10.0
var selected_image : Sprite = null
var prev_mouse_pos := Vector2()
var line : Line2D
var expression := Expression.new()

# Connect to the files dropped signal onready
func _ready():
	assert(expression.parse("z", PoolStringArray(["z"])) == 0, "Expression could not be parsed")
	input_rect.material.set_shader_param("scaling", scaling)
	assert(get_tree().connect("files_dropped", self, "files_dropped") == 0, 
			"files_dropped connection failed")
	assert(expression.parse("z", PoolStringArray(["z"])) == 0, 
			"Input expression could not be parsed")


func _process(_delta):
	var new_mouse_pos := get_viewport_mouse_position()
	var mouse_move := new_mouse_pos - prev_mouse_pos
	
	if not draw_button.pressed:
		# Select or an image from input
		if Input.is_action_just_pressed("left_mouse"):
			selected_image = select_image()
		
		# Delete selected image if required
		if Input.is_action_just_pressed("delete") and selected_image:
			selected_image.queue_free()
			selected_image = null
		
		# If an image has been selected, check whether to modify that image
		if selected_image:
			var image_pos := selected_image.position
			# If the rotate key is being pressed, rotate the image with the mouse
			if Input.is_action_pressed("rotate"):
				selected_image.rotate((new_mouse_pos - image_pos).angle() 
						- (prev_mouse_pos - image_pos).angle())
			# If the scale key is being pressed, scale the image with the mouse
			elif Input.is_action_pressed("scale"):
				var instant_scale := ((new_mouse_pos - image_pos).length() 
					/ (prev_mouse_pos - image_pos).length())
				selected_image.scale *= instant_scale
			# If the mouse is being pressed, move the selected image with the mouse
			elif Input.is_action_pressed("left_mouse"):
				selected_image.position += mouse_move
	else:
		# TODO
		# Start drawing
		var projected_position := get_viewport_mouse_position()
		if Input.is_action_just_pressed("left_mouse"):
			line = Line2D.new()
			line.default_color = Color.white
			add_child(line)
			line.add_point(projected_position)
		elif Input.is_action_pressed("left_mouse") and prev_mouse_pos != new_mouse_pos:
			line.add_point(projected_position)
		elif Input.is_action_just_released("left_mouse"):
			line = null
	
	# Update the mouse's previous position so you can track its movement
	prev_mouse_pos = new_mouse_pos


# Function connected to the files_dropped signal
func files_dropped(files: PoolStringArray, _screen: int) -> void:
	# Loop through the files
	for file in files:
		# Try to load files as images
		var image := Image.new()
		var err := image.load(file)
		if err != OK:
			print(file, " could not be loaded")
			return
		var texture := ImageTexture.new()
		texture.create_from_image(image, 0)
		
		# If the file loaded, add a sprite with the image at the mouse position
		var drop_position : Vector2 = output_rect.get_local_mouse_position()
		drop_position.x /= output_rect.rect_size.x
		drop_position.y /= output_rect.rect_size.y
		var dropped_sprite := Sprite.new()
		dropped_sprite.texture = texture
		add_child(dropped_sprite)
		dropped_sprite.position = Vector2(drop_position.x * size.x, drop_position.y * size.y)
		selected_image = dropped_sprite

# Function to select the image the mouse is on
func select_image():
	# Get the click position in viewport's local coords
	var click_position : Vector2 = output_rect.get_local_mouse_position()
	click_position.x /= output_rect.rect_size.x
	click_position.y /= output_rect.rect_size.y
	click_position = Vector2(click_position.x * size.x, click_position.y * size.y)
	
	# Go through every child and find the one closest to the top that the mouse is clicking
	var children := get_children()
	children.invert()
	for child in children:
		if (child.is_class("Sprite") 
				and child.get_rect().has_point(child.to_local(click_position))):
			return child
	
	return null

func undo_zero(value: float) -> float:
	return value if value != 0.0 else 1.0

func get_rect_position(rect: TextureRect) -> Vector2:
	var click_position : Vector2 = rect.get_local_mouse_position()
	click_position.x /= undo_zero(rect.rect_size.x)
	click_position.y /= undo_zero(rect.rect_size.y)
	
	var x_y_ratio := min(rect.rect_size.x / undo_zero(rect.rect_size.y), 1.0)
	var x_offset := (1.0 - x_y_ratio) / 2.0
	var y_x_ratio := min(rect.rect_size.y / undo_zero(rect.rect_size.x), 1.0)
	var y_offset := (1.0 - y_x_ratio) / 2.0
	
	return Vector2(size.x * (click_position.x * x_y_ratio + x_offset), 
			size.y * (click_position.y * y_x_ratio + y_offset))

func get_viewport_mouse_position() -> Vector2:
	var root_size := get_tree().root.size
	var on_right : bool = output_rect.get_global_mouse_position().x >= root_size.x / 2.0
	
	if on_right:
		return get_rect_position(output_rect)
	else:
		var ratios := get_rect_position(input_rect)
		ratios.x /= size.x
		ratios.y /= size.y
		var complex := ratios - Vector2(0.5, 0.5)
		complex.y *= -1.0
		complex *= scaling
		var transformed_complex : Vector2 = expression.execute([complex], self)
		assert(not expression.has_execute_failed(), "Function failed to execute")
		var transformed_pos := transformed_complex / scaling
		transformed_pos.y /= -1.0
		transformed_pos += Vector2(0.5, 0.5)
		transformed_pos.x *= size.x
		transformed_pos.y *= size.y
		return transformed_pos
		



func _on_Button_pressed():
	var parsed_text : Dictionary = txtbar.parse_string(txtbar.text)
	if parsed_text.size() != 0:
		print(txtbar.parsed_to_gdscript(parsed_text))
		assert(expression.parse(txtbar.parsed_to_gdscript(txtbar.parse_string(txtbar.text)), 
				PoolStringArray(["cuv"])) == 0, "Expression could not be parsed")
