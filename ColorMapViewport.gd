# The viewport that stores the images to be transformed
extends Viewport

# Get the node that you drop images into
onready var input_rect := $"%Output"

# Define some variables
var selected_image : Sprite = null
var prev_mouse_pos := Vector2()

# Connect to the files dropped signal onready
func _ready():
	assert(get_tree().connect("files_dropped", self, "files_dropped") == 0, 
			"files_dropped connection failed")


func _process(_delta):
	# Select or deselect an image from input
	if Input.is_action_just_pressed("left_mouse"):
		selected_image = select_image()
	elif Input.is_action_just_released("left_mouse"):
		selected_image = null
	
	# If the mouse is being pressed, move the selected image with the mouse
	if Input.is_action_pressed("left_mouse"):
		if selected_image:
			var translation : Vector2 = input_rect.get_local_mouse_position() - prev_mouse_pos
			translation.x /= input_rect.rect_size.x
			translation.y /= input_rect.rect_size.y
			translation = Vector2(translation.x * size.x, translation.y * size.y)
			selected_image.position += translation
	
	# Update the mouse's previous position so you can track its movement
	prev_mouse_pos = input_rect.get_local_mouse_position()


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
		var drop_position : Vector2 = input_rect.get_local_mouse_position()
		drop_position.x /= input_rect.rect_size.x
		drop_position.y /= input_rect.rect_size.y
		var dropped_sprite := Sprite.new()
		dropped_sprite.texture = texture
		add_child(dropped_sprite)
		dropped_sprite.position = Vector2(drop_position.x * size.x, drop_position.y * size.y)

# Function to select the image the mouse is on
func select_image():
	# Get the click position in viewport's local coords
	var click_position : Vector2 = input_rect.get_local_mouse_position()
	click_position.x /= input_rect.rect_size.x
	click_position.y /= input_rect.rect_size.y
	click_position = Vector2(click_position.x * size.x, click_position.y * size.y)
	
	# Go through every child and find the one closest to the top that the mouse is clicking
	var children := get_children()
	children.invert()
	for child in children:
		if (child.is_class("Sprite") 
				and child.get_rect().has_point(child.to_local(click_position))):
			return child
	
	return null
