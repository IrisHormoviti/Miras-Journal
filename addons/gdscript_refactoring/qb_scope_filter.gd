@tool
class_name QbScopeFilter
extends RefCounted
## Scope-aware occurrence analysis for GDScript identifiers, compensating the
## language server's name-only matching (a member `var x` and a local `var x`
## in a function are otherwise merged, and some usages are missed).
##
## Given a file's source lines, a symbol, and the caret line, it decides whether
## the caret refers to the member variable or a function-local one, and returns
## the occurrences (line + column spans) that belong to that scope, honoring
## GDScript shadowing rules.

const LspClient = preload("res://addons/gdscript_refactoring/qb_lsp_client.gd")


## Result: { "kind": "member"|"local", "occurrences": [ {line, sc, ec}, ... ] }
## Returns an empty dict if the source can't be analyzed (caller should then
## keep the LSP results unchanged).
static func analyze(lines: Array, symbol: String, caret_line: int) -> Dictionary:
	if lines.is_empty() or not _is_identifier(symbol):
		return {}
	var scope := _resolve_scope(lines, symbol, caret_line)
	if scope.is_empty():
		return {}
	var occ := _collect_scope_occurrences(lines, symbol, scope)
	return {"kind": scope["kind"], "occurrences": occ}


static func _resolve_scope(lines: Array, symbol: String, caret_line: int) -> Dictionary:
	var func_start := -1
	var i := caret_line
	while i >= 0 and i < lines.size():
		var l: String = lines[i]
		if _indent_of(l) == 0 and l.strip_edges().begins_with("func "):
			func_start = i
			break
		i -= 1
	if func_start != -1:
		var func_end := _block_end(lines, func_start)
		var local_decl := _find_local_decl(lines, symbol, func_start + 1, func_end)
		if local_decl != -1 and caret_line >= local_decl:
			return {"kind": "local", "start": func_start, "end": func_end,
					"decl": local_decl}
	return {"kind": "member", "start": 0, "end": lines.size() - 1}


static func _collect_scope_occurrences(lines: Array, symbol: String, scope: Dictionary) -> Array:
	var out: Array = []
	var rx := RegEx.new()
	rx.compile("\\b" + _regex_escape(symbol) + "\\b")

	if scope["kind"] == "local":
		var lstart: int = scope["decl"]
		var lend: int = scope["end"]
		for ln in range(lstart, lend + 1):
			_append_line_matches(out, rx, lines, ln)
		return out

	var shadow := _shadow_ranges(lines, symbol)
	for ln in range(0, lines.size()):
		var shadowed := false
		for rng in shadow:
			if ln >= rng[0] and ln <= rng[1]:
				shadowed = true
				break
		if shadowed:
			continue
		_append_line_matches(out, rx, lines, ln)
	return out


static func _shadow_ranges(lines: Array, symbol: String) -> Array:
	var ranges: Array = []
	var i := 0
	while i < lines.size():
		var l: String = lines[i]
		if _indent_of(l) == 0 and l.strip_edges().begins_with("func "):
			var fend := _block_end(lines, i)
			var decl := _find_local_decl(lines, symbol, i + 1, fend)
			if decl != -1:
				ranges.append([decl, fend])
			i = fend + 1
		else:
			i += 1
	return ranges


static func _append_line_matches(out: Array, rx: RegEx, lines: Array, ln: int) -> void:
	if ln < 0 or ln >= lines.size():
		return
	var line: String = lines[ln]
	for m in rx.search_all(line):
		var col := m.get_start()
		if _is_in_comment_or_string(line, col):
			continue
		out.append({"line": ln, "sc": col, "ec": m.get_end()})


static func _find_local_decl(lines: Array, symbol: String, from: int, to: int) -> int:
	var rx := RegEx.new()
	rx.compile("^\\s*(?:var|const)\\s+" + _regex_escape(symbol) + "\\b")
	for ln in range(from, mini(to + 1, lines.size())):
		if rx.search(lines[ln]):
			return ln
	return -1


static func _block_end(lines: Array, header: int) -> int:
	var base := _indent_of(lines[header])
	var last := header
	for ln in range(header + 1, lines.size()):
		var l: String = lines[ln]
		if l.strip_edges() == "":
			continue
		if _indent_of(l) <= base:
			break
		last = ln
	return last


static func _indent_of(line: String) -> int:
	var n := 0
	for ch in line:
		if ch == "\t" or ch == " ":
			n += 1
		else:
			break
	return n


static func _is_identifier(s: String) -> bool:
	var rx := RegEx.new()
	rx.compile("^[A-Za-z_]\\w*$")
	return rx.search(s) != null


static func _is_in_comment_or_string(line: String, col: int) -> bool:
	var in_str := false
	var quote := ""
	var i := 0
	while i < col and i < line.length():
		var ch := line[i]
		if in_str:
			if ch == quote:
				in_str = false
		else:
			if ch == "#":
				return true
			if ch == "\"" or ch == "'":
				in_str = true
				quote = ch
		i += 1
	return in_str


static func _regex_escape(s: String) -> String:
	var special := ["\\", ".", "^", "$", "*", "+", "?", "(", ")", "[", "]", "{", "}", "|"]
	var out := s
	for ch in special:
		out = out.replace(ch, "\\" + ch)
	return out
