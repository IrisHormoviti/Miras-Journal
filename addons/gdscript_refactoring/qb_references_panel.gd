@tool
extends Control
## Bottom-panel view that lists every reference (usage) of a symbol, grouped by
## file, with syntax-colored source lines (RichTextLabel + BBCode, like the
## rename preview). Clicking a line opens that file in the script editor at the
## exact position.

const LspClient   = preload("res://addons/gdscript_refactoring/qb_lsp_client.gd")
const FileScanner = preload("res://addons/gdscript_refactoring/qb_file_scanner.gd")

var editor_plugin: EditorPlugin

var _header:  Label
var _body:    RichTextLabel
var _busy:    bool = false
var _jump: Array = []
var _last_allowed_classes: Array = []   # class names kept by the last filter
var _context_menu: PopupMenu
var _plain_lines: PackedStringArray = PackedStringArray()  # plain text for copy

# Search progress animation.
var _spin_timer: Timer
var _spin_frame: int = 0
var _spin_symbol: String = ""
const SPIN_FRAMES := ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

const CTX_COPY := 0
const CTX_SELECT_ALL := 1
var _scope_note: String = ""


func _init() -> void:
	name = "References"
	_build_ui()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2(0, 180)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 4)
	add_child(vb)

	_header = Label.new()
	_header.text = "Find all references — right-click a symbol and choose \"Find all references\" (Alt+Shift+F2)."
	_header.add_theme_color_override("font_color", Color(0.6, 0.62, 0.66))
	vb.add_child(_header)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.scroll_active = true
	_body.selection_enabled = true
	_body.focus_mode = Control.FOCUS_CLICK
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.autowrap_mode = TextServer.AUTOWRAP_OFF
	_body.meta_clicked.connect(_on_meta_clicked)
	_body.gui_input.connect(_on_body_gui_input)
	_apply_monospace_font(_body)
	vb.add_child(_body)

	# Right-click context menu (Copy / Select All), like the Output panel.
	_context_menu = PopupMenu.new()
	_context_menu.add_item("Copy", CTX_COPY)
	_context_menu.add_item("Select All", CTX_SELECT_ALL)
	_context_menu.id_pressed.connect(_on_context_menu_id)
	add_child(_context_menu)

	# Spinner timer for the "searching…" animation.
	_spin_timer = Timer.new()
	_spin_timer.wait_time = 0.1
	_spin_timer.timeout.connect(_on_spin_tick)
	add_child(_spin_timer)


func find_references(symbol: String, symbol_pos: Dictionary) -> void:
	if _busy:
		return
	if symbol_pos.is_empty():
		_header.text = "No cursor position available. Right-click on the symbol first."
		return
	_busy = true
	_spin_symbol = symbol
	_start_spinner()
	_body.text = ""
	_jump.clear()
	# Free any leftover detached highlighter from a previous search immediately
	# (queue_free is deferred; a lingering hidden CodeEdit child can make the
	# next _make_highlighter_edit pick the wrong editor / produce empty output).
	for child in get_children():
		if child is CodeEdit:
			remove_child(child)
			child.free()
	if editor_plugin:
		editor_plugin.make_bottom_panel_item_visible(self)
	_search_coroutine(symbol, symbol_pos)


func _search_coroutine(symbol: String, symbol_pos: Dictionary) -> void:
	var lsp := LspClient.new()
	lsp.setup(Engine.get_main_loop() as SceneTree)

	var project_abs := ProjectSettings.globalize_path("res://")
	var root_uri    := LspClient.path_to_uri(project_abs.trim_suffix("/").trim_suffix("\\"))

	var ok := await lsp.connect_to_lsp(root_uri)
	if not ok:
		_stop_spinner()
		_header.text = "Cannot connect to the GDScript language server."
		_busy = false
		return

	var sync_version := Time.get_ticks_msec()
	var scanner := FileScanner.new()
	var gd_files := scanner.collect_gd_files("res://")
	var _t_scan := Time.get_ticks_msec()
	var sent := 0
	var total_files := gd_files.size()
	for abs_path in gd_files:
		var uri := LspClient.path_to_uri(abs_path)
		var f := FileAccess.open(abs_path, FileAccess.READ)
		if f:
			var source := f.get_as_text()
			f.close()
			await lsp.did_open_async(uri, source, sync_version)
			sent += 1
			if sent % 10 == 0:
				_update_send_progress(sent, total_files)
				await Engine.get_main_loop().process_frame
	print("[PERF] did_open %d files: %d ms" % [sent, Time.get_ticks_msec() - _t_scan])

	await Engine.get_main_loop().create_timer(1.0).timeout

	var locations = await lsp.references(
		symbol_pos["uri"], symbol_pos["line"], symbol_pos["character"], true)
	lsp.disconnect_from_lsp()

	if locations == null or (locations is Array and (locations as Array).is_empty()):
		_stop_spinner()
		_header.text = "No references found for \"%s\"." % symbol
		_busy = false
		return

	_populate(symbol, locations as Array, symbol_pos)
	_busy = false


# Godot virtual / built-in callback methods: the language server lists every
# class that defines them, not just the one under the caret. For these we
# restrict the results to the starting class and the classes that extend it.
const VIRTUAL_METHODS := {
	"_init": true, "_ready": true, "_process": true, "_physics_process": true,
	"_input": true, "_unhandled_input": true, "_unhandled_key_input": true,
	"_shortcut_input": true, "_gui_input": true, "_draw": true,
	"_enter_tree": true, "_exit_tree": true, "_notification": true,
	"_get": true, "_set": true, "_get_property_list": true,
	"_property_can_revert": true, "_property_get_revert": true,
	"_to_string": true, "_validate_property": true,
	"_get_configuration_warnings": true,
}


## -------------------------------------------------------------------------
## Search progress spinner
## -------------------------------------------------------------------------

func _start_spinner() -> void:
	_spin_frame = 0
	_update_spinner_text()
	_spin_timer.start()


func _stop_spinner() -> void:
	if _spin_timer:
		_spin_timer.stop()


func _on_spin_tick() -> void:
	_spin_frame = (_spin_frame + 1) % SPIN_FRAMES.size()
	_update_spinner_text()


func _update_spinner_text() -> void:
	var dots := ".".repeat((_spin_frame / 3) % 4)   # 0..3 trailing dots
	_header.text = "%s  Searching for references to \"%s\"%s" % [
		SPIN_FRAMES[_spin_frame], _spin_symbol, dots]


## Shows file-streaming progress in the header (the spinner can't animate during
## the synchronous send, so a live counter gives clear feedback instead).
func _update_send_progress(sent: int, total: int) -> void:
	_header.text = "%s  Indexing project for \"%s\"…  (%d / %d files)" % [
		SPIN_FRAMES[_spin_frame], _spin_symbol, sent, total]


func _populate(symbol: String, locations: Array, symbol_pos: Dictionary) -> void:
	_stop_spinner()

	# Property access (e.g. "velocity.y"): the LSP matches the trailing member
	# (".y") on every object, which is meaningless. Handle it ourselves: find
	# self-accesses to this exact path in the starting class and its related
	# classes, and report (but don't follow) external "obj.velocity.y" accesses.
	# A bare native property (velocity, position, …) is handled the same way,
	# searching self-accesses to that property.
	var access_path: String = symbol_pos.get("access_path", "")
	var is_native_prop: bool = symbol_pos.get("native_property", false)
	if access_path.find(".") != -1:
		_populate_property_access(access_path, symbol_pos)
		return
	if is_native_prop:
		_populate_property_access(symbol, symbol_pos)
		return

	var filtered_note := ""
	if VIRTUAL_METHODS.has(symbol):
		var before := locations.size()
		locations = _filter_virtual_to_hierarchy(symbol, locations, symbol_pos)
		var removed := before - locations.size()
		if removed > 0:
			filtered_note = "  (virtual method — %d result%s in unrelated classes hidden)" % [
				removed, "" if removed == 1 else "s"]
		# For the constructor specifically, also list every `.new(` call on the
		# starting class and its subclasses — those are the real invocations of
		# _init, which the language server does not report.
		if symbol == "_init":
			var new_calls := _find_new_calls(_last_allowed_classes)
			if not new_calls.is_empty():
				locations.append_array(new_calls)
				filtered_note += "  •  %d .new() call%s included" % [
					new_calls.size(), "" if new_calls.size() == 1 else "s"]
		if locations.is_empty():
			_header.text = "No references to \"%s\" in this class or its subclasses." % symbol
			return

	# Scope-aware correction for variables. Godot's LSP matches variables by
	# name only: a member `var x` and a local `var x` in a function are merged,
	# and some usages are missed entirely. When the symbol is an identifier
	# (not a virtual method), we recompute the occurrences in the START file
	# ourselves, honoring GDScript scoping (member vs local, with shadowing).
	var scope_note := ""
	if not VIRTUAL_METHODS.has(symbol) and _is_identifier(symbol):
		locations = _apply_scope_filter(symbol, locations, symbol_pos)
		scope_note = _scope_note

	var by_file: Dictionary = {}
	for loc in locations:
		var abs_path := LspClient.uri_to_path(loc["uri"])
		var r: Dictionary = loc["range"]
		var entry := {
			"line": int(r["start"]["line"]),
			"sc":   int(r["start"]["character"]),
			"ec":   int(r["end"]["character"]),
		}
		if not by_file.has(abs_path):
			by_file[abs_path] = []
		by_file[abs_path].append(entry)

	var total := locations.size()
	var file_count := by_file.size()
	_header.text = "%d reference%s to \"%s\" in %d file%s   —   click a line to open it%s%s" % [
		total, "" if total == 1 else "s", symbol,
		file_count, "" if file_count == 1 else "s", filtered_note, scope_note]

	_render_by_file(by_file)


## Renders occurrences grouped by file into the body (BBCode, colored, clickable)
## and fills _plain_lines for copy. [by_file] maps abs_path → Array of
## {line, sc, ec}.
func _render_by_file(by_file: Dictionary) -> void:
	var string_color := _hex(_theme_color("string_color", Color(0.8, 0.8, 0.4)))
	var num_color    := _hex(_theme_color("line_number_color", Color(0.5, 0.5, 0.55)))

	var hl := _make_highlighter_edit()

	_plain_lines = PackedStringArray()
	var bb := ""
	var files := by_file.keys()
	files.sort()
	for abs_path in files:
		var res_path := ProjectSettings.localize_path(abs_path)
		var entries: Array = by_file[abs_path]
		bb += "[color=#%s][b]%s[/b][/color]  [color=#888888](%d)[/color]\n" % [
			string_color, res_path, entries.size()]
		_plain_lines.append("%s (%d)" % [res_path, entries.size()])

		var lines := _read_lines(abs_path)
		if hl and not lines.is_empty():
			hl.text = "\n".join(PackedStringArray(lines))
		var members := _collect_member_variables(lines)

		var max_ln := 0
		for e in entries:
			max_ln = maxi(max_ln, int(e["line"]) + 1)
		var num_w := str(max_ln).length()

		entries.sort_custom(func(a, b): return a["line"] < b["line"])
		for e in entries:
			var ln: int = e["line"]
			var raw: String = lines[ln] if ln < lines.size() else ""
			var jump_idx := _jump.size()
			_jump.append({"path": res_path, "line": ln, "col": int(e["sc"])})

			var num := str(ln + 1).lpad(num_w)
			var colored := _colorize_line(hl, raw, ln, int(e["sc"]), int(e["ec"]), members)
			bb += "  [color=#%s]%s[/color]  [url=%d]%s[/url]\n" % [
				num_color, num, jump_idx, colored]
			_plain_lines.append("%s: %s" % [num, raw.strip_edges(true, false)])
		bb += "\n"
		_plain_lines.append("")

	_body.text = bb

	if hl and is_instance_valid(hl):
		remove_child(hl)
		hl.free()


# -------------------------------------------------------------------------
# Property-access references (e.g. "velocity.y")
# -------------------------------------------------------------------------

## Handles a property-access path like "velocity.y". Finds self-accesses to the
## exact path in the starting file and its related classes (ancestors +
## descendants), and counts external "obj.<path>" accesses without following
## them (their object's type can't be resolved reliably from text).
func _populate_property_access(access_path: String, symbol_pos: Dictionary) -> void:
	var start_abs := LspClient.uri_to_path(symbol_pos.get("uri", ""))
	var start_norm := _norm(start_abs)

	var related := _related_class_files(start_norm)
	related[start_norm] = true

	# self-access: the path NOT preceded by another ".identifier" (i.e. not
	# obj.velocity.y). Allow an optional leading "self.".
	var rx_self := RegEx.new()
	rx_self.compile("(?<![.\\w])(?:self\\.)?" + _regex_escape(access_path) + "\\b")
	var rx_any := RegEx.new()
	rx_any.compile("\\b" + _regex_escape(access_path) + "\\b")

	var by_file: Dictionary = {}
	var external_count := 0

	var scanner := FileScanner.new()
	for abs_path in scanner.collect_gd_files("res://"):
		var np := _norm(abs_path)
		var lines := _read_lines(abs_path)
		var is_related: bool = related.has(np)
		for ln in lines.size():
			var line: String = lines[ln]
			if is_related:
				for m in rx_self.search_all(line):
					var col := _path_start_col(m, access_path)
					if _is_in_comment_or_string(line, col):
						continue
					if not by_file.has(abs_path):
						by_file[abs_path] = []
					by_file[abs_path].append({
						"line": ln, "sc": col, "ec": col + access_path.length()})
			for m2 in rx_any.search_all(line):
				var c2 := m2.get_start()
				if _is_in_comment_or_string(line, c2):
					continue
				if c2 >= 1 and line[c2 - 1] == ".":
					external_count += 1

	var total := 0
	for k in by_file:
		total += (by_file[k] as Array).size()
	var fcount := by_file.size()

	var ext_note := ""
	if external_count > 0:
		ext_note = "   •   %d external \"obj.%s\" access%s not followed (type-dependent)" % [
			external_count, access_path, "" if external_count == 1 else "es"]

	if total == 0:
		_header.text = "No self-access to \"%s\" found in this class or related classes.%s" % [
			access_path, ext_note]
		_body.text = ""
		return

	_header.text = "%d reference%s to \"%s\" in %d file%s   —   click a line to open it%s" % [
		total, "" if total == 1 else "s", access_path,
		fcount, "" if fcount == 1 else "s", ext_note]
	_render_by_file(by_file)


## Returns { norm_path: true } for the starting class file, its ancestor class
## files, and its descendant class files (project classes only).
func _related_class_files(start_norm: String) -> Dictionary:
	var info_by_path := {}
	var path_by_class := {}
	var scanner := FileScanner.new()
	for abs_path in scanner.collect_gd_files("res://"):
		var np := _norm(abs_path)
		var decl := _read_class_decl(abs_path)
		info_by_path[np] = decl
		if decl["cls"] != "":
			path_by_class[decl["cls"]] = np

	var result := {}
	var start_info = info_by_path.get(start_norm, null)
	if start_info == null or start_info["cls"] == "":
		result[start_norm] = true
		return result
	var start_cls: String = start_info["cls"]

	# Descendants (transitively extend start_cls).
	var fam := {start_cls: true}
	var changed := true
	while changed:
		changed = false
		for p in info_by_path:
			var d = info_by_path[p]
			if d["cls"] == "" or fam.has(d["cls"]):
				continue
			if fam.has(d["base"]):
				fam[d["cls"]] = true
				changed = true
	# Ancestors (walk the base chain through project classes).
	var cur: String = start_info["base"]
	var guard := 0
	while cur != "" and path_by_class.has(cur) and guard < 100:
		fam[cur] = true
		var anc = info_by_path[path_by_class[cur]]
		cur = anc["base"]
		guard += 1

	for cls in fam:
		if path_by_class.has(cls):
			result[path_by_class[cls]] = true
	return result


func _path_start_col(m: RegExMatch, access_path: String) -> int:
	var s := m.get_string()
	var off := s.find(access_path)
	return m.get_start() + (off if off >= 0 else 0)


# -------------------------------------------------------------------------
# Virtual-method filtering (keep the starting class + its subclasses)
# -------------------------------------------------------------------------

## For a virtual method, keeps only the locations whose file defines the
## starting class or a class that (transitively) extends it.
func _filter_virtual_to_hierarchy(symbol: String, locations: Array,
		symbol_pos: Dictionary) -> Array:
	var start_path := _norm(LspClient.uri_to_path(symbol_pos.get("uri", "")))
	if start_path == "":
		return locations

	# Build the project class graph: file → {class_name, extends_name, path}.
	var info_by_path := {}       # norm abs_path → {"cls":.., "base":..}
	var path_by_class := {}      # class_name → norm abs_path
	var scanner := FileScanner.new()
	for abs_path in scanner.collect_gd_files("res://"):
		var np := _norm(abs_path)
		var decl := _read_class_decl(abs_path)
		info_by_path[np] = decl
		if decl["cls"] != "":
			path_by_class[decl["cls"]] = np

	# Identify the starting class from the file under the caret.
	var start_info = info_by_path.get(start_path, null)
	if start_info == null or start_info["cls"] == "":
		# No class_name to anchor the hierarchy: fall back to same-file only.
		return _keep_paths(locations, {start_path: true})

	var start_class: String = start_info["cls"]

	# Allowed = starting class + everything that extends it (transitively).
	var allowed_classes := {start_class: true}
	var changed := true
	while changed:
		changed = false
		for p in info_by_path:
			var d = info_by_path[p]
			if d["cls"] == "" or allowed_classes.has(d["cls"]):
				continue
			if allowed_classes.has(d["base"]):
				allowed_classes[d["cls"]] = true
				changed = true

	# Translate allowed classes back to file paths (+ always the start file).
	var allowed_paths := {start_path: true}
	for cls in allowed_classes:
		if path_by_class.has(cls):
			allowed_paths[path_by_class[cls]] = true

	# Remember the allowed class names for the .new() constructor search below.
	_last_allowed_classes = allowed_classes.keys()

	return _keep_paths(locations, allowed_paths)


func _keep_paths(locations: Array, allowed_paths: Dictionary) -> Array:
	var out: Array = []
	for loc in locations:
		var p := _norm(LspClient.uri_to_path(loc["uri"]))
		if allowed_paths.has(p):
			out.append(loc)
	return out


## Normalizes a filesystem path for comparison: forward slashes, lower-cased
## drive letter on Windows (paths are case-insensitive there).
func _norm(p: String) -> String:
	var s := p.replace("\\", "/")
	if s.length() >= 2 and s[1] == ":":
		s = s[0].to_lower() + s.substr(1)
	return s


## Reads the class_name and the base (extends) of a .gd file. Handles both
## "class_name X extends Y" on one line and separate "extends Y" / "class_name X"
## lines. Base may be a class_name, a native type, or a res:// path string.
func _read_class_decl(abs_path: String) -> Dictionary:
	var cls := ""
	var base := ""
	var f := FileAccess.open(abs_path, FileAccess.READ)
	if f == null:
		return {"cls": cls, "base": base}
	var checked := 0
	while not f.eof_reached() and checked < 40:
		var line := f.get_line().strip_edges()
		checked += 1
		if line == "" or line.begins_with("#"):
			continue
		if line.begins_with("class_name"):
			var rest := line.substr("class_name".length()).strip_edges()
			var ext_idx := rest.find("extends")
			if ext_idx != -1:
				cls = rest.substr(0, ext_idx).strip_edges()
				base = rest.substr(ext_idx + "extends".length()).strip_edges()
			else:
				cls = rest.strip_edges()
		elif line.begins_with("extends"):
			base = line.substr("extends".length()).strip_edges()
		# Stop once we've passed the header (first non-annotation code line).
		if cls != "" and base != "":
			break
		var is_header := line.begins_with("class_name") or line.begins_with("extends") or line.begins_with("@")
		if not is_header:
			break
	f.close()
	# Normalize a quoted path base to nothing (can't match a class_name).
	if base.begins_with("\"") or base.begins_with("'"):
		base = ""
	return {"cls": cls, "base": base}


## Searches the whole project for `ClassName.new(` calls for any of the given
## class names, returning them as LSP-style Location dicts. This complements
## _init references (the LSP reports the declaration and super() calls, but not
## the actual constructor invocations via .new()).
func _find_new_calls(class_names: Array) -> Array:
	var out: Array = []
	if class_names.is_empty():
		return out
	# Build a regex alternation of the class names, e.g. \b(A|B|C)\.new\s*\(
	var names_escaped: Array = []
	for c in class_names:
		names_escaped.append(_regex_escape(c))
	var rx := RegEx.new()
	rx.compile("\\b(" + "|".join(names_escaped) + ")\\.new\\s*\\(")

	var scanner := FileScanner.new()
	for abs_path in scanner.collect_gd_files("res://"):
		var f := FileAccess.open(abs_path, FileAccess.READ)
		if f == null:
			continue
		var src := f.get_as_text()
		f.close()
		var uri := LspClient.path_to_uri(abs_path)
		var line_no := 0
		for raw in src.split("\n"):
			var line: String = raw
			# Skip full-line comments quickly.
			var stripped := line.strip_edges()
			if stripped.begins_with("#"):
				line_no += 1
				continue
			for m in rx.search_all(line):
				var col := m.get_start(1)          # start of the class name
				# Ignore matches inside a line comment or a string literal.
				if _is_in_comment_or_string(line, col):
					continue
				var name_len := m.get_end(1) - m.get_start(1)
				out.append({
					"uri": uri,
					"range": {
						"start": {"line": line_no, "character": col},
						"end":   {"line": line_no, "character": col + name_len},
					}
				})
			line_no += 1
	return out


## Rough check: is column [col] in [line] inside a line comment or a string?
func _is_in_comment_or_string(line: String, col: int) -> bool:
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


func _regex_escape(s: String) -> String:
	var special := ["\\", ".", "^", "$", "*", "+", "?", "(", ")", "[", "]", "{", "}", "|"]
	var out := s
	for ch in special:
		out = out.replace(ch, "\\" + ch)
	return out


# -------------------------------------------------------------------------
# Context menu (Copy / Select All), mirroring the Output panel
# -------------------------------------------------------------------------

func _on_body_gui_input(event: InputEvent) -> void:
	# Right-click opens the context menu at the cursor.
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		_show_context_menu(event.position)
		_body.accept_event()
		return
	# Ctrl+C copies the current selection (Output panel behavior).
	if event is InputEventKey and event.pressed and event.keycode == KEY_C \
			and event.ctrl_pressed:
		_copy_selection()
		_body.accept_event()


func _show_context_menu(local_pos: Vector2) -> void:
	if _plain_lines.is_empty():
		return
	# Copy is enabled only when there is a selection.
	var has_sel := _body.get_selected_text() != ""
	_context_menu.set_item_disabled(_context_menu.get_item_index(CTX_COPY), not has_sel)
	# A PopupMenu needs an absolute SCREEN position. Convert the click point
	# (local to the RichTextLabel) through the canvas + window transforms.
	var screen_pos: Vector2 = _body.get_screen_transform() * local_pos
	_context_menu.reset_size()
	_context_menu.position = Vector2i(screen_pos)
	_context_menu.popup()


func _on_context_menu_id(id: int) -> void:
	match id:
		CTX_COPY:
			_copy_selection()
		CTX_SELECT_ALL:
			_body.select_all()


func _copy_selection() -> void:
	var sel := _body.get_selected_text()
	if sel != "":
		DisplayServer.clipboard_set(sel)


# -------------------------------------------------------------------------
# Scope-aware variable filtering (compensates the LSP's name-only matching)
# -------------------------------------------------------------------------

## Recomputes occurrences of [symbol] in the START file honoring GDScript
## scoping, then merges them with the LSP results from OTHER files (which the
## intra-file shadowing problem does not affect). Sets _scope_note.
func _apply_scope_filter(symbol: String, locations: Array,
		symbol_pos: Dictionary) -> Array:
	_scope_note = ""
	var start_path := _norm(LspClient.uri_to_path(symbol_pos.get("uri", "")))
	if start_path == "":
		return locations
	var abs_start := LspClient.uri_to_path(symbol_pos.get("uri", ""))
	var lines := _read_lines(abs_start)
	if lines.is_empty():
		return locations

	var caret_line := int(symbol_pos.get("line", -1))

	# Determine whether the caret sits on the member declaration/use or inside
	# a function's local scope, and get that scope's line range.
	var scope := _resolve_scope(lines, symbol, caret_line)
	if scope.is_empty():
		return locations   # couldn't analyze — leave LSP results untouched

	# Collect in-file occurrences for the resolved scope.
	var in_file := _collect_scope_occurrences(lines, symbol, scope, symbol_pos.get("uri", ""))

	# Keep LSP results from OTHER files only if this is a member (a local
	# variable never leaks outside its file). Replace the start-file results
	# with our scope-correct ones.
	var out: Array = []
	if scope["kind"] == "member":
		for loc in locations:
			var p := _norm(LspClient.uri_to_path(loc["uri"]))
			if p != start_path:
				out.append(loc)
	out.append_array(in_file)

	var kind_label = "local variable" if scope["kind"] == "local" else "member variable"
	_scope_note = "  •  scope-aware (%s)" % kind_label
	return out


## Figures out, from the caret line, whether we are looking at the member
## variable or a local one, and returns {"kind": "member"|"local",
## "start": <int>, "end": <int>} (line range for local; whole file for member).
func _resolve_scope(lines: Array, symbol: String, caret_line: int) -> Dictionary:
	# Find the enclosing function block of the caret (if any).
	var func_start := -1
	var func_end := -1
	var i := caret_line
	# Walk upward to find a "func" line at indent 0 that encloses the caret.
	while i >= 0 and i < lines.size():
		var l: String = lines[i]
		if _indent_of(l) == 0 and l.strip_edges().begins_with("func "):
			func_start = i
			break
		i -= 1
	if func_start != -1:
		func_end = _block_end(lines, func_start)
		# Does this function declare a local `var symbol`? And is the caret at
		# or after that declaration (i.e. within the local's scope)?
		var local_decl := _find_local_decl(lines, symbol, func_start + 1, func_end)
		if local_decl != -1 and caret_line >= local_decl:
			return {"kind": "local", "start": func_start, "end": func_end,
					"decl": local_decl}
	# Otherwise treat it as the member variable.
	return {"kind": "member", "start": 0, "end": lines.size() - 1}


## Collects occurrences of [symbol] within the given scope, applying shadowing:
## for a member scope, usages inside a function that declares its own local
## `var symbol` are excluded.
func _collect_scope_occurrences(lines: Array, symbol: String, scope: Dictionary,
		uri: String) -> Array:
	var out: Array = []
	var rx := RegEx.new()
	rx.compile("\\b" + _regex_escape(symbol) + "\\b")

	if scope["kind"] == "local":
		var lstart: int = scope["decl"]
		var lend: int = scope["end"]
		for ln in range(lstart, lend + 1):
			_append_line_matches(out, rx, lines, ln, uri)
		return out

	# Member scope: whole file, but skip regions shadowed by a local var.
	var shadow := _shadow_ranges(lines, symbol)
	for ln in range(0, lines.size()):
		var shadowed := false
		for rng in shadow:
			if ln >= rng[0] and ln <= rng[1]:
				shadowed = true
				break
		if shadowed:
			continue
		_append_line_matches(out, rx, lines, ln, uri)
	return out


## Returns [start,end] line ranges of functions that declare a local `var
## symbol`, i.e. regions where the member is shadowed. The shadow starts at the
## local declaration line (before it, the member is still visible).
func _shadow_ranges(lines: Array, symbol: String) -> Array:
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


func _append_line_matches(out: Array, rx: RegEx, lines: Array, ln: int, uri: String) -> void:
	if ln < 0 or ln >= lines.size():
		return
	var line: String = lines[ln]
	for m in rx.search_all(line):
		var col := m.get_start()
		if _is_in_comment_or_string(line, col):
			continue
		out.append({
			"uri": uri,
			"range": {
				"start": {"line": ln, "character": col},
				"end":   {"line": ln, "character": m.get_end()},
			}
		})


## Finds the line of a local `var symbol` (or `var symbol:` / `var symbol =`)
## declaration within [from,to], else -1.
func _find_local_decl(lines: Array, symbol: String, from: int, to: int) -> int:
	var rx := RegEx.new()
	rx.compile("^\\s*(?:var|const)\\s+" + _regex_escape(symbol) + "\\b")
	for ln in range(from, mini(to + 1, lines.size())):
		if rx.search(lines[ln]):
			return ln
	return -1


## Returns the last line index of the block starting at [header] (a func/class
## line at some indent): the block spans until the next line at the same or
## lower indent that is not blank.
func _block_end(lines: Array, header: int) -> int:
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


func _indent_of(line: String) -> int:
	var n := 0
	for ch in line:
		if ch == "\t" or ch == " ":
			n += 1
		else:
			break
	return n


func _is_identifier(s: String) -> bool:
	var rx := RegEx.new()
	rx.compile("^[A-Za-z_]\\w*$")
	return rx.search(s) != null


func _on_meta_clicked(meta: Variant) -> void:
	var idx := int(str(meta))
	if idx < 0 or idx >= _jump.size():
		return
	var jump: Dictionary = _jump[idx]
	var scr = load(jump["path"])
	if scr is Script:
		# The LSP reports 0-based lines; edit_script expects a 1-based line
		# (passing the 0-based value lands the caret one line too high).
		EditorInterface.edit_script(scr, int(jump["line"]) + 1, int(jump["col"]))


func _colorize_line(hl: CodeEdit, raw: String, line_index: int,
		sc: int, ec: int, members: Dictionary) -> String:
	if raw == "":
		return ""
	var default_col := _theme_color("text_color", Color(0.86, 0.86, 0.86))
	var member_col  := _theme_color("member_variable_color", Color(0.6, 0.75, 1.0))

	var col_map: Dictionary = {}
	if hl and line_index < hl.get_line_count():
		var sh = hl.syntax_highlighter
		if sh:
			col_map = sh.get_line_syntax_highlighting(line_index)

	var change_cols: Array = col_map.keys()
	change_cols.sort()

	# Clamp the highlight span to the actual line bounds so we never open a
	# [bgcolor] tag we can't close (an unbalanced tag makes the whole
	# RichTextLabel render empty — this was the intermittent blank-body bug).
	var hl_start := sc
	var hl_end   := ec
	if hl_start < 0:
		hl_start = 0
	if hl_end > raw.length():
		hl_end = raw.length()
	var do_highlight := hl_start < hl_end   # only if the span is non-empty & in-range

	var out := ""
	var cur_col := default_col
	var next_i := 0
	var member_spans := _member_spans(raw, members)
	var hl_open := false

	for i in raw.length():
		while next_i < change_cols.size() and int(change_cols[next_i]) <= i:
			var c = col_map[change_cols[next_i]]
			if c is Dictionary and c.has("color"):
				cur_col = c["color"]
			next_i += 1
		var use_col: Color = cur_col
		for ms in member_spans:
			if i >= ms[0] and i < ms[1]:
				use_col = member_col
				break
		if do_highlight and i == hl_start:
			out += "[bgcolor=#3d5a80]"
			hl_open = true
		var ch := raw[i]
		var esc := ch.replace("[", "[lb]")
		var draw_col := "ffffff" if hl_open else _hex(use_col)
		out += "[color=#%s]%s[/color]" % [draw_col, esc]
		if hl_open and i == hl_end - 1:
			out += "[/bgcolor]"
			hl_open = false
	# Safety: if the highlight opened but never closed (shouldn't happen after
	# clamping), close it so the BBCode stays balanced.
	if hl_open:
		out += "[/bgcolor]"
	return out


func _member_spans(raw: String, members: Dictionary) -> Array:
	var spans: Array = []
	if members.is_empty():
		return spans
	var rx := RegEx.new()
	rx.compile("[A-Za-z_]\\w*")
	for m in rx.search_all(raw):
		if members.has(m.get_string()):
			spans.append([m.get_start(), m.get_end()])
	return spans


func _read_lines(abs_path: String) -> Array:
	var f := FileAccess.open(abs_path, FileAccess.READ)
	if f == null:
		return []
	var src := f.get_as_text()
	f.close()
	return Array(src.split("\n"))


func _make_highlighter_edit() -> CodeEdit:
	var se := EditorInterface.get_script_editor()
	var base := se.get_current_editor()
	if base == null:
		return null
	var src_edit := _find_code_edit_node(base)
	if src_edit == null:
		return null
	var ce := CodeEdit.new()
	if src_edit.syntax_highlighter:
		ce.syntax_highlighter = src_edit.syntax_highlighter.duplicate(true)
	ce.visible = false
	add_child(ce)
	return ce


func _find_code_edit_node(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node as CodeEdit
	for child in node.get_children():
		var r := _find_code_edit_node(child)
		if r:
			return r
	return null


func _theme_color(key: String, fallback: Color) -> Color:
	var ed := EditorInterface.get_editor_settings()
	var c = ed.get_setting("text_editor/theme/highlighting/%s" % key)
	if c is Color:
		return c as Color
	return fallback


func _hex(c: Color) -> String:
	return c.to_html(false)


func _collect_member_variables(lines: Array) -> Dictionary:
	var members: Dictionary = {}
	var decl := RegEx.new()
	decl.compile("^(?:@\\w+\\s*(?:\\([^)]*\\))?\\s*)*(?:static\\s+)?(?:var|const)\\s+([A-Za-z_]\\w*)")
	for raw in lines:
		var line: String = raw
		if line.length() > 0 and (line[0] == " " or line[0] == "\t"):
			continue
		var m := decl.search(line)
		if m:
			members[m.get_string(1)] = true
	return members


func _apply_monospace_font(rtl: RichTextLabel) -> void:
	var ed := EditorInterface.get_editor_settings()
	var fp = ed.get_setting("interface/editor/code_font")
	if fp is String and fp != "" and ResourceLoader.exists(fp):
		var fnt = load(fp)
		if fnt is Font:
			rtl.add_theme_font_override("normal_font", fnt)
			rtl.add_theme_font_override("bold_font", fnt)
	var fs = ed.get_setting("interface/editor/code_font_size")
	if fs is int:
		rtl.add_theme_font_size_override("normal_font_size", fs)
		rtl.add_theme_font_size_override("bold_font_size", fs)
	rtl.add_theme_constant_override("line_separation", 4)
