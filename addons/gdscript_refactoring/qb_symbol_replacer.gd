@tool
extends RefCounted

## Finds and replaces a GDScript symbol inside a file or string.
## Each line is split into code / string-literal / comment segments
## so each zone can be handled independently.


# -------------------------------------------------------------------------
# Public API
# -------------------------------------------------------------------------

## Scans a file and returns:
##   { path: String, count: int, lines: [{line: int, content: String}] }
func find_occurrences(
		file_path:      String,
		symbol:         String,
		whole_word:     bool,
		case_sensitive: bool,
		in_comments:    bool,
		in_strings:     bool
) -> Dictionary:
	var result := { "path": file_path, "count": 0, "lines": [] }
	var content := _read_file(file_path)
	if content.is_empty():
		return result
	var regex := _build_regex(symbol, whole_word, case_sensitive)
	if regex == null:
		return result
	var lines := content.split("\n")
	for i in lines.size():
		var line: String = lines[i]
		var count := _count_in_line(line, regex, in_comments, in_strings)
		if count > 0:
			result["count"] += count
			result["lines"].append({"line": i, "content": line.strip_edges()})
	return result


## Applies replacement in a file on disk. Returns number replaced, -1 on error.
func apply_replacement(
		file_path:      String,
		old_symbol:     String,
		new_symbol:     String,
		whole_word:     bool,
		case_sensitive: bool,
		in_comments:    bool,
		in_strings:     bool
) -> int:
	var content := _read_file(file_path)
	if content.is_empty():
		return -1
	var regex := _build_regex(old_symbol, whole_word, case_sensitive)
	if regex == null:
		return -1
	var lines     := content.split("\n")
	var new_lines := PackedStringArray()
	var total     := 0
	for line in lines:
		var processed := _replace_in_line(line, regex, new_symbol, in_comments, in_strings)
		total        += processed["count"]
		new_lines.append(processed["line"])
	if total == 0:
		return 0
	return _write_file(file_path, "\n".join(new_lines), total)


## Writes the replacement to disk AND returns the new content string.
## Used when both disk write and the new content are needed.
func replace_file(
		file_path:      String,
		old_symbol:     String,
		new_symbol:     String,
		whole_word:     bool,
		case_sensitive: bool,
		in_comments:    bool,
		in_strings:     bool
) -> String:
	var content := _read_file(file_path)
	if content.is_empty():
		return ""
	var new_content := replace_in_text(
		content, old_symbol, new_symbol,
		whole_word, case_sensitive, in_comments, in_strings
	)
	if new_content != content:
		_write_file(file_path, new_content, 1)
	return new_content


## Applies replacement on an in-memory string. Returns the modified string.
func replace_in_text(
		source:         String,
		old_symbol:     String,
		new_symbol:     String,
		whole_word:     bool,
		case_sensitive: bool,
		in_comments:    bool,
		in_strings:     bool
) -> String:
	var regex := _build_regex(old_symbol, whole_word, case_sensitive)
	if regex == null:
		return source
	var lines     := source.split("\n")
	var new_lines := PackedStringArray()
	for line in lines:
		var processed := _replace_in_line(line, regex, new_symbol, in_comments, in_strings)
		new_lines.append(processed["line"])
	return "\n".join(new_lines)


# -------------------------------------------------------------------------
# Line-level helpers
# -------------------------------------------------------------------------

func _count_in_line(line: String, regex: RegEx, in_comments: bool, in_strings: bool) -> int:
	var count := 0
	for seg in _parse_segments(line):
		match seg["type"]:
			"code":    count += regex.search_all(seg["text"]).size()
			"comment": if in_comments: count += regex.search_all(seg["text"]).size()
			"string":  if in_strings:  count += regex.search_all(seg["text"]).size()
	return count


func _replace_in_line(line: String, regex: RegEx, new_symbol: String,
		in_comments: bool, in_strings: bool) -> Dictionary:
	var segments := _parse_segments(line)
	var result   := ""
	var count    := 0
	for seg in segments:
		var text: String = seg["text"]
		match seg["type"]:
			"code":
				var r := _replace_in_text_chunk(text, regex, new_symbol)
				result += r["text"]; count += r["count"]
			"comment":
				if in_comments:
					var r := _replace_in_text_chunk(text, regex, new_symbol)
					result += r["text"]; count += r["count"]
				else:
					result += text
			"string":
				if in_strings:
					var delimiter := text[0]
					var inner     := text.substr(1, text.length() - 2)
					var r         := _replace_in_text_chunk(inner, regex, new_symbol)
					result += delimiter + r["text"] + delimiter
					count  += r["count"]
				else:
					result += text
	return {"line": result, "count": count}


func _replace_in_text_chunk(text: String, regex: RegEx, new_symbol: String) -> Dictionary:
	var out      := ""
	var count    := 0
	var last_end := 0
	for m in regex.search_all(text):
		out      += text.substr(last_end, m.get_start() - last_end)
		out      += new_symbol
		last_end  = m.get_end()
		count    += 1
	out += text.substr(last_end)
	return {"text": out, "count": count}


# -------------------------------------------------------------------------
# Segment parser  (code / string / comment)
# -------------------------------------------------------------------------

func _parse_segments(line: String) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	var in_single := false
	var in_double := false
	var seg_start := 0
	var i := 0

	while i < line.length():
		var c := line[i]

		if c == "\\" and (in_single or in_double):
			i += 2
			continue

		if in_single:
			if c == "'":
				segments.append({"type": "string", "text": line.substr(seg_start, i - seg_start + 1)})
				seg_start = i + 1
				in_single = false
		elif in_double:
			if c == '"':
				segments.append({"type": "string", "text": line.substr(seg_start, i - seg_start + 1)})
				seg_start = i + 1
				in_double = false
		else:
			if c == "'":
				if i > seg_start:
					segments.append({"type": "code", "text": line.substr(seg_start, i - seg_start)})
				seg_start = i
				in_single = true
			elif c == '"':
				if i > seg_start:
					segments.append({"type": "code", "text": line.substr(seg_start, i - seg_start)})
				seg_start = i
				in_double = true
			elif c == "#":
				if i > seg_start:
					segments.append({"type": "code", "text": line.substr(seg_start, i - seg_start)})
				segments.append({"type": "comment", "text": line.substr(i)})
				return segments
		i += 1

	if seg_start < line.length():
		var final_type := "string" if (in_single or in_double) else "code"
		segments.append({"type": final_type, "text": line.substr(seg_start)})

	return segments


# -------------------------------------------------------------------------
# Regex builder
# -------------------------------------------------------------------------

func _build_regex(symbol: String, whole_word: bool, case_sensitive: bool) -> RegEx:
	var regex := RegEx.new()
	var safe := symbol \
		.replace("\\", "\\\\").replace(".", "\\.") \
		.replace("*",  "\\*" ).replace("+", "\\+") \
		.replace("?",  "\\?" ).replace("(", "\\(") \
		.replace(")",  "\\)" ).replace("[", "\\[") \
		.replace("]",  "\\]" ).replace("{", "\\{") \
		.replace("}",  "\\}" ).replace("^", "\\^") \
		.replace("$",  "\\$" ).replace("|", "\\|")
	var pattern: String
	if whole_word:
		pattern = "(?<![\\w])%s(?![\\w])" % safe
	else:
		pattern = safe
	if not case_sensitive:
		pattern = "(?i)" + pattern
	var err := regex.compile(pattern)
	if err != OK:
		push_error("GDScript Renamer – invalid regex for \"%s\": %s" % [symbol, err])
		return null
	return regex


# -------------------------------------------------------------------------
# File I/O
# -------------------------------------------------------------------------

func _read_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("GDScript Renamer – cannot read: %s (error %d)" \
			% [path, FileAccess.get_open_error()])
		return ""
	var content := file.get_as_text()
	file.close()
	return content


func _write_file(path: String, content: String, count: int) -> int:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("GDScript Renamer – cannot write: %s (error %d)" \
			% [path, FileAccess.get_open_error()])
		return -1
	file.store_string(content)
	file.close()
	return count
