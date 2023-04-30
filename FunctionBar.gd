extends TextEdit

signal function_fucked

const WHITESPACE := [" ", "\t", "\n"]

const NUMERICS := "1234567890i."

#TODO add sqrt

const FUNC_ENCODE = {
	"sqrt": "Š",
	"sin": "Ś",
	"cos": "Ć",
	"exp": "É",
	"log": "Ĺ",
	"ln": "Ĺ",
	"pow": "Ṕ",
	"tan": "Ṫ",
	"re": "Ŕ",
	"im": "Í",
	"arg": "Á",
	"mod": "Ḿ",
	"abs": "Ḿ",
	"conj": "ć",
	"e": "2.7182818284590452353602874713527",
	"pi": "3.14159265359"
	}

const FUNC_DECODE = {
	"Š": "csqrt",
	"Ś": "csin",
	"Ć": "ccos",
	"É": "cexp",
	"Ĺ": "clog",
	"Ṕ": "cpow",
	"Ṫ": "ctan",
	"Ŕ": "creal",
	"Í": "cimag",
	"Á": "carg",
	"Ḿ": "cmod",
	"ć": "cconj",
	"+": "cadd", 
	"-": "csub", 
	"*": "cmult", 
	"/": "cdiv", 
	"^": "cpow"
}

const LATEX_DECODE = {
	"Š": "\\sqrt",
	"Ś": "\\sin",
	"Ć": "\\cos",
	"É": "\\exp",
	"Ĺ": "\\ln",
	"Ṕ": "^",
	"Ṫ": "\\tan",
	"Ŕ": "\\mathrm{Re}",
	"Í": "\\mathrm{Im}",
	"Á": "\\mathrm{Arg}",
	"Ḿ": "\\mathrm{Mod}",
	"ć": "\\mathrm{Conj}",
	"+": "+", 
	"-": "-", 
	"*": "*", 
	"/": "\\frac", 
	"^": "^"
}

onready var shader_plot := $"%Input"

onready var LaTeX := $"%LaTeX"

onready var default_shadercode : String = shader_plot.material.shader.code

func is_numeric_index(index: int, text: String) -> bool:
	if text[index] in NUMERICS:
		return true
	
	if text[index] == "-":
		if index == 0:
			return true
		else:
			return text[index - 1] in "+-*/^("
	
	return false

func parse_string(text: String) -> Dictionary:
	# Clean whitespace
	var clean_text := text.to_lower()
	for whitespace in WHITESPACE:
		clean_text = clean_text.replace(whitespace, "")
	
	# Make sure string isn't too long
	if clean_text.length() > 200:
		emit_signal("function_fucked", "You definitely don't need an input that long")
		return {}
	
	# Make sure brackets work
	if clean_text.count("(") != clean_text.count(")"):
		emit_signal("function_fucked", "Unmatched bracket in function")
		return {}
	# TODO: Make sure every character in string is legal
	# TODO: Make sure only one letter functions
	
	# Make sure the text is formatted properly
	if clean_text.length() < 6 or clean_text[1] != "(" or clean_text[3] != ")" or clean_text[4] != "=":
		emit_signal("function_fucked", 
		"Something is wrong with your input. \n"
		+ "Make sure it has the form 'f(z) = expression'")
		
		return {}
	
	# Split the text and get the input variable
	var split_text := clean_text.split("=")
	var input_var := split_text[0][2]
	var code_function := split_text[1]
	
	# Replace all function keywords with unique symbols
	for key in FUNC_ENCODE.keys():
		code_function = code_function.replace(key, FUNC_ENCODE[key])
	
	# Replace the input variable with z
	code_function = code_function.replace(input_var, "(z)")
	
	# While any combo of */+-(^ followed by a + or - is in the code, replace
	var doubles := true
	while doubles:
		
		code_function = code_function.replace(
												"*+", "*").replace(
												"/+", "/").replace(
												"++", "+").replace(
												"-+", "-").replace(
												"(+", "(").replace(
												"^+", "^").replace(
												"+-", "-").replace(
												"--", "+")
		
		doubles = false
		for symbol in "*/+-(^":
			doubles = doubles or (symbol + "+") in code_function
		doubles = doubles or "+-" in code_function or "--" in code_function
	if code_function[0] == "+":
		code_function.erase(0, 1)
	
	# Surround numerics with brackets
	var num_starts := []
	var num_ends := []
	var prev_char_index := -1
	for char_index in code_function.length():
		if ((prev_char_index == -1 or not is_numeric_index(prev_char_index, code_function)) 
				and is_numeric_index(char_index, code_function)):
			num_starts.append(char_index)
		
		if ((prev_char_index >= 0 and is_numeric_index(prev_char_index, code_function)) 
				and not is_numeric_index(char_index, code_function)):
			num_ends.append(char_index)
		
		prev_char_index = char_index
	
	if num_ends.size() < num_starts.size():
		num_ends.append(code_function.length())
	
	var brackets_inserted := 0
	for index in code_function.length() + 1:
		if num_starts.size() > 0 and num_starts[0] == index:
			code_function = code_function.insert(num_starts.pop_front() 
					+ brackets_inserted, "(")
			brackets_inserted += 1
		
		if num_ends.size() > 0 and num_ends[0] == index:
			code_function = code_function.insert(num_ends.pop_front() 
					+ brackets_inserted, ")")
			brackets_inserted += 1
	
	# Replace negatives that have *, /, +, -, ( in front of them with 0-
	if code_function[0] == "-":
		code_function = code_function.insert(0, "0")
	for symbol in "*/+-(^":
		code_function = code_function.replace(symbol + "-", symbol + "0-")
	
	# Add a * in between )(
	code_function = code_function.replace(")(", ")*(")
	
	# Parse the expression and return the parsed Dict
	return parse(code_function)

func get_substr_indices(text: String, substr: String) -> Array:
	var indices := [text.findn(substr)]
	while indices[-1] != -1:
		indices.append(text.findn(substr, indices[-1] + 1))
	indices.remove(indices.size() - 1)
	
	return indices

func slice(text: String, start: int, stop: int) -> String:
	return text.substr(start, stop - start)

func parse(text: String) -> Dictionary:
	# If entirely numeric, return numeric
	var numeric_string := true
	for character in text:
		numeric_string = numeric_string and character in NUMERICS
	if numeric_string:
		return {"": [text]}
	
	# If it's the function variable, return itself
	if text == "z":
		return {"": "z"}
	
	
	# Otherwise
	# Initialize an array to store the slices between bracket groups
	var between_slices := []
	# Initialize an array to store the strings inside the brackets
	var bracket_slices := []
	
	# Loop until you reach the end of the text, storing text in or out of
	# brackets
	var bracket_level := 0
	var l_index := -1
	var r_index := -1
	for char_index in text.length():
		# If you reach a beginning of a bracket group, stick the segment before 
		# it into the "between_slices" array
		if text[char_index] == "(":
			if bracket_level == 0:
				l_index = char_index
				between_slices.append(slice(text, r_index + 1, l_index))
			bracket_level += 1
		
		# If you reach an end of a bracket group, stick the segment from the 
		# bracket into "bracket_slices"
		if text[char_index] == ")":
			bracket_level -= 1
			if bracket_level == 0:
				r_index = char_index
				bracket_slices.append(slice(text, l_index + 1, r_index))
		
		# Reach the end of the string and add the last substring between slices
		if char_index == text.length() - 1:
			between_slices.append(slice(text, r_index + 1, char_index + 1))
	
	# Join all the elements in the first array into one string using a delimiter to 
	# indicate brackets
	var text_no_brackets := ""
	for slice in between_slices:
		text_no_brackets += slice + "β"
	# Remove the last β
	text_no_brackets = text_no_brackets.trim_suffix("β")
	
	# If there is only one bracket and no other characters, return {"": [parse(bracket)]}
	if text_no_brackets == "β":
		return {"": [parse(bracket_slices[0])]}
	
	# If there is one bracket and one character to the left, 
	# return {"left": [parse(bracket)]}
	if text_no_brackets.ends_with("β") and text_no_brackets.length() == 2:
		return {text_no_brackets[0]: [parse(bracket_slices[0])]}
	
	# Look for addition/subtraction, return {"+" or "-": [parse(left), parse(right)]} 
	var pm_split = lookfor("+", "-", text_no_brackets, bracket_slices)
	if pm_split != null:
		return pm_split
	
	# Look for mult/div, return {"*" or "/": [parse(left), parse(right)]}
	var md_split = lookfor("*", "/", text_no_brackets, bracket_slices)
	if md_split != null:
		return md_split
	
	# Look for exp, return {"^": [parse(left), parse(right)]}
	var exp_split = lookfor("^", "**", text_no_brackets, bracket_slices)
	if exp_split != null:
		return exp_split
	
	# If you got to the end here without returning, there's an error
	emit_signal("function_fucked", 
		"Either you fucked up your function or the programmer fucked up DesMOST. "
		+ "Quadruple check your input is valid and then go yell at the programmer if it is.")
	return {}

func lookfor(a: String, b: String, text_no_brackets: String, bracket_slices: Array):
	var first_a := text_no_brackets.find_last(a)
	var first_b := text_no_brackets.find_last(b)
	
	if first_a != -1 or first_b != -1:
		var split_text: PoolStringArray
		if first_b == -1 or (first_a != -1 and first_a > first_b):
			# Split the text around the first additition
			split_text = text_no_brackets.rsplit(a, true, 1)
		else:
			# Split text around first subtraction
			split_text = text_no_brackets.rsplit(b, true, 1)
		
		# Find the number of β in each segment
		var first_bracket_num := split_text[0].count("β")
		
		# Make two arrays of bracket contents for the two
		var first_brackets := bracket_slices.slice(0, first_bracket_num - 1)
		var second_brackets := bracket_slices.slice(first_bracket_num, 
				bracket_slices.size() - 1)
		
		# Make new strings with β swapped in for actual values
		var bracketed_first_brackets := []
		for elem in first_brackets:
			bracketed_first_brackets.append("(" + elem + ")")
		var bracketed_second_brackets := []
		for elem in second_brackets:
			bracketed_second_brackets.append("(" + elem + ")")
		
		var first_input := split_text[0].format(bracketed_first_brackets, "β")
		var second_input := split_text[1].format(bracketed_second_brackets, "β")
		
		# Replace empty inputs with 0s
		if first_input == "":
			first_input = "0" if a in "+-" else "1"
		if second_input == "":
			second_input = "0" if a in "+-" else "1"
		
		if first_b == -1 or (first_a != -1 and first_a > first_b):
			return {a: [parse(first_input), parse(second_input)]}
		else:
			return {b: [parse(first_input), parse(second_input)]}


func deparse(expression: Dictionary) -> String:
	if expression.keys()[0] == "":
		if expression.values()[0][0] is String:
			return expression.values()[0][0]
		else:
			return deparse(expression.values()[0][0])
	else:
		var parameters := ""
		for param in expression.values()[0]:
			parameters += deparse(param) + ", "
		parameters = parameters.trim_suffix(", ")
		
		return expression.keys()[0] + "(" + parameters + ")"

func deparse_to_vectors(expression: Dictionary) -> String:
	if expression.keys()[0] == "":
		if expression.values()[0][0] is String:
			var number : String = expression.values()[0][0]
			if not "z" in number:
				if "i" in number:
					var imag := number.replace("i", "")
					if imag == "":
						imag = "1"
					return "vec2(0, " + imag + ")"
				else:
					return "vec2(" + number + ", 0)"
			else:
				return number
		else:
			return deparse_to_vectors(expression.values()[0][0])
	else:
		var parameters := ""
		for param in expression.values()[0]:
			parameters += deparse_to_vectors(param) + ", "
		parameters = parameters.trim_suffix(", ")
		
		return expression.keys()[0] + "(" + parameters + ")"

func deparse_to_Vector2s(expression: Dictionary) -> String:
	if expression.keys()[0] == "":
		if expression.values()[0][0] is String:
			var number : String = expression.values()[0][0]
			if not "z" in number:
				if "i" in number:
					var imag := number.replace("i", "")
					if imag == "":
						imag = "1"
					return "Vector2(0, " + imag + ")"
				else:
					return "Vector2(" + number + ", 0)"
			else:
				return number
		else:
			return deparse_to_Vector2s(expression.values()[0][0])
	else:
		var parameters := ""
		for param in expression.values()[0]:
			parameters += deparse_to_Vector2s(param) + ", "
		parameters = parameters.trim_suffix(", ")
		
		return expression.keys()[0] + "(" + parameters + ")"

func parsed_to_gdscript(expression: Dictionary) -> String:
	var code := deparse_to_Vector2s(expression)
	
	# Replace functions with their code counterparts
	for encoded_func in FUNC_DECODE:
		code = code.replace(encoded_func, FUNC_DECODE[encoded_func])
	
	# Replace the input variable with code counterparts
	code = code.replace("z", "cuv")
	
	return code

func parsed_to_shadercode(expression: Dictionary) -> String:
	var code := deparse_to_vectors(expression)
	
	# Replace functions with their code counterparts
	for encoded_func in FUNC_DECODE:
		code = code.replace(encoded_func, FUNC_DECODE[encoded_func])
	
	# Replace the input variable with code counterparts
	code = code.replace("z", "cuv")
	
	return code

func parsed_to_latex(expression: Dictionary) -> String:
	if expression.keys()[0] == "":
		if expression.values()[0][0] is String:
			return expression.values()[0][0].replace("2.7182818284590452353602874713527", "e").replace("3.14159265359", "\\pi")
		else:
			return "(" + parsed_to_latex(expression.values()[0][0]) + ")"
	else:
		var function : String = expression.keys()[0]
		if LATEX_DECODE[function] in "+-*^":
			return ("{" + parsed_to_latex(expression.values()[0][0]) + "}"
					+ LATEX_DECODE[function]
					+ "{" + parsed_to_latex(expression.values()[0][1]) + "}")
		elif LATEX_DECODE[function] == "\\frac":
			return ("\\frac{" + parsed_to_latex(expression.values()[0][0]) + "}{" 
					+ parsed_to_latex(expression.values()[0][1]) + "}")
		else:
			return (LATEX_DECODE[function] + "{" + parsed_to_latex(expression.values()[0][0]) + "}")

# Make sure f(z) is formatted properly
# No "i" as the input variable
# f(z) = log(exp(z + 2i) - i) + 1 breaks it
# Have viewport separate from the ViewportContainer so it doesn't rescale
# i is upside down. i is on the bottom for some reason. No idea why

func _on_Button_pressed():
	var parsed_expression := parse_string(text)
	if parsed_expression.size() != 0:
		print(parsed_to_shadercode(parse_string(text)))
		var new_code := default_shadercode.replace("cuv_to_uv(cuv)", 
				"cuv_to_uv({function})".format({"function": 
					parsed_to_shadercode(parsed_expression)}))

		# Assign the new shader code to the shader
		shader_plot.material.shader.code = new_code
		
		LaTeX._latexExpression = parsed_to_latex(parsed_expression)
		LaTeX.Render()


func _on_FunctionBar_text_changed():
	pass # Replace with function body.
