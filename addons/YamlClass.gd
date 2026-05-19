class_name YAMLParser
extends RefCounted

## A comprehensive YAML parser for Godot 4.5 with full read/write support
## 
## Features:[br]
## - Parses YAML/YML files into Godot dictionaries with proper type conversion[br]
## - Saves Godot dictionaries back to properly formatted YAML files[br]
## - Supports all essential YAML data types: strings, integers, floats, booleans, null, arrays, and dictionaries[br]
## - Handles complex nested structures and mixed-type collections[br]
## - Date/time parsing with automatic conversion to Godot time dictionaries[br]
## - Inline and multi-line array/dictionary notation support[br]
## - Strict typing throughout for optimal performance and reliability[br]
## - Comprehensive error handling for file operations[br]
## - Comment support (ignores # comments during parsing)[br]
## [br]
## Supported Data Types:[br]
## - Strings: quoted, unquoted, with automatic ambiguity resolution[br]
## - Numbers: integers, floats, negative values, scientific notation[br]
## - Booleans: true/false, yes/no, on/off variations[br]
## - Null: null, ~, and implicit null values[br]
## - Arrays: inline [1,2,3] and multi-line list formats[br]
## - Dictionaries: nested objects with unlimited depth[br]
## - Dates: ISO format (YYYY-MM-DD) and datetime strings[br]
##[br]
## Use Cases: Configuration files, save data, asset metadata, localization data, game settings

## Loads a YAML file from the specified path and parses it into a Dictionary.[br]
## Returns an empty dictionary and logs an error if the file doesn't exist or can't be opened.
static func load_yaml_file(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		push_error("YAML file not found: " + file_path)
		return {}
	
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open YAML file: " + file_path)
		return {}
	
	var content: String = file.get_as_text()
	file.close()
	
	return parse_yaml_string(content)

## Parses a YAML-formatted string into a Dictionary.[br]
## Supports nested dictionaries, arrays, and automatic type inference.
static func parse_yaml_string(yaml_content: String) -> Dictionary:
	var lines: PackedStringArray = yaml_content.split("\n")
	var result: Dictionary = {}
	var current_dict: Dictionary = result
	var dict_stack: Array[Dictionary] = []
	var indent_stack: Array[int] = []
	var last_key: String = "" 
	var multiline_context: Dictionary = {}
	
	var line_num: int = 0
	while line_num < lines.size():
		var line: String = lines[line_num]
		
		if multiline_context.has("active") and multiline_context.active:
			var processed_lines: Array = _process_multiline_string(lines, line_num, multiline_context)
			var multiline_value: String = processed_lines[0]
			line_num = processed_lines[1]
			
			var target_dict: Dictionary = multiline_context.target_dict
			var key: String = multiline_context.key
			target_dict[key] = multiline_value
			
			multiline_context.clear()
			continue
		
		if line.strip_edges() == "" or line.strip_edges().begins_with("#"):
			line_num += 1
			continue
		
		var indent_level: int = _get_indent_level(line)
		line = line.strip_edges()
		
		while indent_stack.size() > 0 and indent_level <= indent_stack[-1]:
			indent_stack.pop_back()
			if dict_stack.size() > 0:
				dict_stack.pop_back()
				current_dict = dict_stack[-1] if dict_stack.size() > 0 else result
		
		if ":" in line:
			var parts: PackedStringArray = line.split(":", false, 1)
			if parts.size() >= 2:
				var key: String = parts[0].strip_edges()
				var value_str: String = parts[1].strip_edges()
				last_key = key
				
				if value_str == "|" or value_str == ">" or value_str.begins_with("|") or value_str.begins_with(">"):
					multiline_context = {
						"active": true,
						"type": value_str[0],
						"key": key,
						"target_dict": current_dict,
						"base_indent": indent_level,
						"strip_final_newlines": value_str.ends_with("-"),
						"keep_final_newlines": value_str.ends_with("+")
					}
					line_num += 1
					continue
				
				var value: Variant
				if value_str == "":
					value = {}
					current_dict[key] = value
					dict_stack.push_back(current_dict)
					current_dict = value as Dictionary
					indent_stack.push_back(indent_level)
				else:
					value = _parse_value(value_str)
					current_dict[key] = value
			else:
				var key: String = parts[0].strip_edges()
				last_key = key
				var value: Dictionary = {}
				current_dict[key] = value
				dict_stack.push_back(current_dict)
				current_dict = value
				indent_stack.push_back(indent_level)
		
		elif line.begins_with("- "):
			var item_value: String = line.substr(2).strip_edges()
			var parsed_item: Variant = _parse_value(item_value)
			
			if dict_stack.size() > 0 and last_key != "":
				var parent_dict: Dictionary = dict_stack[-1]
				if not parent_dict.has(last_key) or not (parent_dict[last_key] is Array):
					parent_dict[last_key] = []
				(parent_dict[last_key] as Array).append(parsed_item)
			else:
				if not current_dict.has("_items"):
					current_dict["_items"] = []
				(current_dict["_items"] as Array).append(parsed_item)
		
		line_num += 1
	
	return result

static func _process_multiline_string(lines: PackedStringArray, start_line: int, context: Dictionary) -> Array:
	var content_lines: Array[String] = []
	var base_indent: int = context.base_indent
	var string_type: String = context.type
	var line_num: int = start_line
	var block_indent: int = -1
	
	while line_num < lines.size():
		var line: String = lines[line_num]
		
		if line.strip_edges() == "":
			if block_indent >= 0:
				content_lines.append("")
			line_num += 1
			continue
		
		var current_indent: int = _get_indent_level(line)
		
		if current_indent <= base_indent:
			break
		
		if block_indent < 0:
			block_indent = current_indent
		
		if current_indent >= block_indent:
			var content_line: String = line.substr(block_indent) if line.length() > block_indent else ""
			content_lines.append(content_line)
		else:
			break
		
		line_num += 1
	
	var result: String = ""
	if string_type == "|":
		result = "\n".join(content_lines)
	elif string_type == ">":
		result = _fold_multiline_string(content_lines)
	
	if context.has("strip_final_newlines") and context.strip_final_newlines:
		result = result.rstrip("\n")
	elif context.has("keep_final_newlines") and context.keep_final_newlines:
		pass
	else:
		result = result.rstrip("\n") + "\n" if result.length() > 0 else ""
	
	return [result, line_num]

static func _fold_multiline_string(lines: Array[String]) -> String:
	if lines.is_empty():
		return ""
	
	var result: String = ""
	var current_paragraph: Array[String] = []
	
	for line: String in lines:
		if line.strip_edges() == "":
			if not current_paragraph.is_empty():
				result += " ".join(current_paragraph) + "\n"
				current_paragraph.clear()
			result += "\n"
		else:
			current_paragraph.append(line.strip_edges())
	
	if not current_paragraph.is_empty():
		result += " ".join(current_paragraph)
	
	return result

static func _get_indent_level(line: String) -> int:
	var indent: int = 0
	for i: int in range(line.length()):
		if line[i] == ' ':
			indent += 1
		elif line[i] == '\t':
			indent += 1
		else:
			break
	return indent

static func _parse_value(value_str: String) -> Variant:
	value_str = value_str.strip_edges()
	
	if (value_str.begins_with('"') and value_str.ends_with('"')) or \
	   (value_str.begins_with("'") and value_str.ends_with("'")):
		return value_str.substr(1, value_str.length() - 2)
	
	var lower_value: String = value_str.to_lower()
	if lower_value in ["true", "yes", "on"]:
		return true
	elif lower_value in ["false", "no", "off"]:
		return false
	elif lower_value in ["null", "~", ""]:
		return null
	
	if _is_datetime_string(value_str):
		return _parse_datetime(value_str)
	
	if value_str.is_valid_int():
		return value_str.to_int()
	elif value_str.is_valid_float():
		return value_str.to_float()
	
	if value_str.begins_with("[") and value_str.ends_with("]"):
		return _parse_inline_array(value_str)
	
	if value_str.begins_with("{") and value_str.ends_with("}"):
		return _parse_inline_dict(value_str)
	
	return value_str

static func _parse_inline_array(array_str: String) -> Array:
	var content: String = array_str.substr(1, array_str.length() - 2).strip_edges()
	if content == "":
		return []
	
	var items: PackedStringArray = content.split(",")
	var result: Array = []
	for item: String in items:
		result.append(_parse_value(item.strip_edges()))
	return result

static func _parse_inline_dict(dict_str: String) -> Dictionary:
	var content: String = dict_str.substr(1, dict_str.length() - 2).strip_edges()
	if content == "":
		return {}
	
	var pairs: PackedStringArray = content.split(",")
	var result: Dictionary = {}
	for pair: String in pairs:
		if ":" in pair:
			var parts: PackedStringArray = pair.split(":", false, 1)
			if parts.size() >= 2:
				var key: String = parts[0].strip_edges()
				var value: String = parts[1].strip_edges()
				result[key] = _parse_value(value)
	return result

## Saves a Dictionary to a YAML-formatted file at the specified path.[br]
## Returns true if the file was written successfully, false otherwise.
static func save_yaml_file(data: Dictionary, file_path: String) -> bool:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to create YAML file: " + file_path)
		return false
	
	var yaml_content: String = _dict_to_yaml(data, 0)
	file.store_string(yaml_content)
	file.close()
	return true

static func _dict_to_yaml(data: Variant, indent_level: int = 0) -> String:
	var indent: String = "  ".repeat(indent_level)
	var result: String = ""
	
	if data is Dictionary:
		var dict_data: Dictionary = data as Dictionary
		for key: Variant in dict_data.keys():
			var value: Variant = dict_data[key]
			
			if value is String and _should_use_multiline_format(value as String):
				result += indent + str(key) + ": |\n"
				var string_value: String = value as String
				var lines: PackedStringArray = string_value.split("\n")
				for line: String in lines:
					result += indent + "  " + line + "\n"
			else:
				result += indent + str(key) + ":"
				
				if value is Dictionary:
					var dict_value: Dictionary = value as Dictionary
					if dict_value.size() > 0:
						result += "\n" + _dict_to_yaml(value, indent_level + 1)
					else:
						result += " {}\n"
				elif value is Array:
					var array_value: Array = value as Array
					if array_value.size() > 0:
						result += "\n"
						for item: Variant in array_value:
							result += indent + "  - " + _value_to_yaml_string(item) + "\n"
					else:
						result += " []\n"
				else:
					result += " " + _value_to_yaml_string(value) + "\n"
	
	return result


static func _should_use_multiline_format(text: String) -> bool:
	return "\n" in text or text.length() > 80


static func _value_to_yaml_string(value: Variant) -> String:
	if value is String:
		var string_value: String = value as String

		if string_value.is_valid_int() or string_value.is_valid_float() or \
		   string_value.to_lower() in ["true", "false", "null", "yes", "no", "on", "off"]:
			return '"' + string_value + '"'
		return string_value
	elif value is bool:
		return "true" if (value as bool) else "false"
	elif value == null:
		return "null"
	elif value is Dictionary and value.has("year"):
		return _datetime_dict_to_string(value as Dictionary)
	else:
		return str(value)

static func _is_datetime_string(value_str: String) -> bool:
	var date_regex: RegEx = RegEx.new()
	date_regex.compile(r"^\d{4}-\d{2}-\d{2}$")
	if date_regex.search(value_str):
		return true
	
	var datetime_regex: RegEx = RegEx.new()
	datetime_regex.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})?$")
	return datetime_regex.search(value_str) != null


static func _parse_datetime(value_str: String) -> Dictionary:
	return Time.get_datetime_dict_from_datetime_string(value_str, true)

static func _datetime_dict_to_string(datetime_dict: Dictionary) -> String:
	return "%04d-%02d-%02d" % [datetime_dict.year, datetime_dict.month, datetime_dict.day]
