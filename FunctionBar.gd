extends TextEdit

const WHITESPACE := [" ", "\t", "\n"]

const NUMERICS := "1234567890i."

const FUNC_ENCODE = {
	"sin": "Ś", 
	"cos": "Ć", 
	"exp": "É", 
	"e^": "É", 
	"log": "Ĺ", 
	"ln": "Ĺ", 
	"pow": "Ṕ", 
	"tan": "Ṫ"
	}

const FUNC_DECODE = {
	"Ś": "csin", 
	"Ć": "ccos", 
	"É": "cexp", 
	"Ĺ": "clog", 
	"Ṕ": "cpow", 
	"Ṫ": "ctan"
}

onready var shader_plot := $"%Input"

onready var default_shadercode : String = shader_plot.material.shader.code


# Make sure f(z) is formatted properly
# No "i" as the input variable
# f(z) = log(exp(z + 2i) - i) + 1 breaks it
# Have viewport separate from the ViewportContainer so it doesn't rescale
# i is upside down. i is on the bottom for some reason. No idea why

func _on_Button_pressed():
	# Get the text
	var formatted_text := text
	# Remove whitespace from the text
	for whitespace in WHITESPACE:
		formatted_text = formatted_text.replace(whitespace, "")
	
	# Split the text around the equals sign
	var split_text := formatted_text.split("=")
	
	# Get the input variable to the function
	var input_var := split_text[0][2]
	
	# Get the function
	var code_function := split_text[1]
	# Replace all function keywords with unique symbols
	for key in FUNC_ENCODE.keys():
		code_function = code_function.replace(key, FUNC_ENCODE[key])
	# Replace all instances of the input variables with "cuv"
	code_function = code_function.replace(input_var, "(cuv)")
	
	# Find all instances of numbers and put them in lists
	var prev_char_num := false
	var num_list := {}
	var start_index := -1
	for index in code_function.length():
		if code_function[index] in NUMERICS and not prev_char_num:
			start_index = index
			prev_char_num = true
		if (not code_function[index] in NUMERICS) and prev_char_num:
			prev_char_num = false
			var num := code_function.substr(start_index, index - start_index)
			num_list[start_index] = num
			start_index = -1
	if start_index != -1:
		prev_char_num = false
		var num := code_function.substr(start_index)
		num_list[start_index] = num
		start_index = -1
	
	# Use those instances of numbers to replace with the appropriate vectors
	var sorted_num_indices = num_list.keys()
	sorted_num_indices.sort()
	var offset = 0
	for number_id in sorted_num_indices.size():
		
		var index : int = sorted_num_indices[number_id]
		var number : String = num_list[index]
		var offset_add := 9 if "i" in number and number.length() > 1 else 10
		var i_free_num := number.replace("i", "")
		if i_free_num == "":
			i_free_num = "1"
		
		code_function.erase(index + offset, number.length())
		if "i" in number:
			code_function = code_function.insert(index + offset, "vec2(0.0,{num})".format(
					{"num": i_free_num}))
		else:
			code_function = code_function.insert(index + offset, "vec2({num},0.0)".format(
					{"num": i_free_num}))
		
		offset += offset_add
	
	# Replace all unique symbols with their complex functions
	for key in FUNC_DECODE.keys():
		code_function = code_function.replace(key, FUNC_DECODE[key])
	
	print(code_function)
	
	# Stick that all into the shader code
	var new_code := default_shadercode.replace("cuv_to_uv(cuv)", 
			"cuv_to_uv({function})".format({"function": code_function}))
	
	# Assign the new shader code to the shader
	shader_plot.material.shader.code = new_code
