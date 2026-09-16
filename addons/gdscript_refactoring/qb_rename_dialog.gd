@tool
extends AcceptDialog

## Main dialog for the GDScript Renamer plugin.
## Uses Godot's built-in GDScript LSP (port 6005) for scope-aware rename,
## with a regex fallback for symbols not under the cursor.

const FileScanner = preload("res://addons/gdscript_refactoring/qb_file_scanner.gd")
const LspClient   = preload("res://addons/gdscript_refactoring/qb_lsp_client.gd")
const ScopeFilter = preload("res://addons/gdscript_refactoring/qb_scope_filter.gd")

# --- Widgets ---
var _old_name_edit:     LineEdit
var _new_name_edit:     LineEdit
var _scope_option:      OptionButton
var _preview_label:       RichTextLabel
var _preview_label_after: RichTextLabel
var _indent_guide_color:  String = "5a5a5a"
var _member_var_color:    String = ""
var _status_label:      Label
var _preview_btn:       Button
var _save_btn:          Button = null

# --- State ---
var _preview_results:  Array[Dictionary] = []  # [{uri, edits:[{range,newText}]}]
var _symbol_position:  Dictionary = {}          # {uri, line, character} — from context menu
var _pending_new_name: String = ""
var editor_plugin:     EditorPlugin = null      # set by plugin after instantiation


func _init() -> void:
	title          = "GDScript Refactoring — Rename Symbol"
	min_size       = Vector2i(640, 420)
	dialog_text    = ""
	ok_button_text = "Rename"
	# Don't let the inner content (e.g. a tall preview RichTextLabel with
	# fit_content) resize the window — keep the size we set in popup_centered().
	wrap_controls  = false
	_build_ui()
	confirmed.connect(_on_confirmed)


func _ready() -> void:
	var cancel_btn := add_button("Cancel", true, "cancel")
	cancel_btn.pressed.connect(hide)


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	# Current symbol (read-only — LSP uses cursor position)
	var hb1 := HBoxContainer.new()
	var lbl_old := Label.new()
	lbl_old.text = "Current symbol:"
	lbl_old.custom_minimum_size.x = 160
	_old_name_edit = LineEdit.new()
	_old_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_old_name_edit.editable = false
	_old_name_edit.placeholder_text = "(detected from cursor position)"
	hb1.add_child(lbl_old)
	hb1.add_child(_old_name_edit)
	vbox.add_child(hb1)

	# New name
	var hb2 := HBoxContainer.new()
	var lbl_new := Label.new()
	lbl_new.text = "New name:"
	lbl_new.custom_minimum_size.x = 160
	_new_name_edit = LineEdit.new()
	_new_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_new_name_edit.placeholder_text = "new_name"
	hb2.add_child(lbl_new)
	hb2.add_child(_new_name_edit)
	vbox.add_child(hb2)

	vbox.add_child(HSeparator.new())

	# Preview button
	var hb_btn := HBoxContainer.new()
	_preview_btn = Button.new()
	_preview_btn.text = "Preview"
	_preview_btn.pressed.connect(_on_preview_pressed)
	hb_btn.add_child(_preview_btn)
	# Save button — only shown when there are unsaved changes (see open()).
	_save_btn = Button.new()
	_save_btn.text = "Save modified files"
	_save_btn.pressed.connect(_on_save_modified_pressed)
	_save_btn.visible = false
	hb_btn.add_child(_save_btn)
	vbox.add_child(hb_btn)

	# Status
	_status_label = Label.new()
	_status_label.text = "Click \"Preview\" to see all occurrences."
	_status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_status_label)

	# Side-by-side preview: left = current code, right = renamed code
	var preview_split := HBoxContainer.new()
	preview_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_split.add_theme_constant_override("separation", 8)
	preview_split.custom_minimum_size.y = 220

	# Left column — "Before"
	var left_box := VBoxContainer.new()
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var left_title := Label.new()
	left_title.text = "Before"
	left_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	left_box.add_child(left_title)
	var scroll_left := ScrollContainer.new()
	scroll_left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_left.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_preview_label = RichTextLabel.new()
	_preview_label.bbcode_enabled = true
	_preview_label.fit_content = true
	_preview_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_preview_label.scroll_active = false
	_preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_monospace_font(_preview_label)
	scroll_left.add_child(_preview_label)
	left_box.add_child(scroll_left)
	preview_split.add_child(left_box)

	# Right column — "After"
	var right_box := VBoxContainer.new()
	right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right_title := Label.new()
	right_title.text = "After"
	right_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	right_box.add_child(right_title)
	var scroll_right := ScrollContainer.new()
	scroll_right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_right.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_preview_label_after = RichTextLabel.new()
	_preview_label_after.bbcode_enabled = true
	_preview_label_after.fit_content = true
	_preview_label_after.autowrap_mode = TextServer.AUTOWRAP_OFF
	_preview_label_after.scroll_active = false
	_preview_label_after.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_label_after.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_monospace_font(_preview_label_after)
	scroll_right.add_child(_preview_label_after)
	right_box.add_child(scroll_right)
	preview_split.add_child(right_box)

	vbox.add_child(preview_split)


## Opens the dialog. symbol_pos = {uri, line, character} from the context menu hook.
func _apply_monospace_font(label: RichTextLabel) -> void:
	# Use the editor's source-code font so the preview matches the editor
	# and all columns (line numbers, guides) line up.
	var ed := EditorInterface.get_editor_settings()
	var font_path: String = ed.get_setting("interface/editor/code_font")
	var font: Font = null
	if font_path != "" and ResourceLoader.exists(font_path):
		font = load(font_path)
	if font == null:
		# Fallback to the editor theme's monospace ("source") font
		var base := EditorInterface.get_base_control()
		if base.has_theme_font("source", "EditorFonts"):
			font = base.get_theme_font("source", "EditorFonts")
	if font:
		label.add_theme_font_override("normal_font", font)
		label.add_theme_font_override("bold_font", font)
		label.add_theme_font_override("mono_font", font)
		label.add_theme_font_override("italics_font", font)

	# Fixed font size and line spacing so highlighted (bgcolor) lines keep the
	# same height as plain ones — otherwise lines overlap.
	var font_size: int = ed.get_setting("interface/editor/code_font_size")
	if font_size <= 0:
		font_size = 14
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_font_size_override("bold_font_size", font_size)
	label.add_theme_font_size_override("mono_font_size", font_size)
	label.add_theme_constant_override("line_separation", 4)


func open(symbol: String, symbol_pos: Dictionary = {}) -> void:
	_old_name_edit.text   = symbol
	_new_name_edit.text   = ""
	_preview_label.text   = ""
	if _preview_label_after:
		_preview_label_after.text = ""
	_symbol_position      = symbol_pos
	_preview_results.clear()
	get_ok_button().disabled = true

	# Warn if any open script has unsaved edits: the rename operates on the
	# on-disk code via the LSP, so unsaved changes are ignored and Godot will
	# later show a "reload from disk" dialog that can discard them.
	var unsaved := _unsaved_open_scripts()
	if unsaved.is_empty():
		_status_label.text = "Click \"Preview\" to see all occurrences."
		_status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		if _save_btn:
			_save_btn.visible = false
	else:
		_status_label.text = _format_unsaved_warning(unsaved)
		_status_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2))
		if _save_btn:
			_save_btn.visible = true

	popup_centered(Vector2i(760, 560))
	_new_name_edit.grab_focus()


## Builds a clear multi-line warning listing each unsaved file on its own line.
func _format_unsaved_warning(unsaved: PackedStringArray) -> String:
	var header := "⚠  %d file%s with unsaved changes:" \
		% [unsaved.size(), "s" if unsaved.size() > 1 else ""]
	var lines := PackedStringArray()
	lines.append(header)
	for name in unsaved:
		lines.append("      •  " + name)
	lines.append("Save them first to avoid losing your edits.")
	return "\n".join(lines)


## Saves every open script that has unsaved edits, then refreshes the warning.
func _on_save_modified_pressed() -> void:
	var se := EditorInterface.get_script_editor()
	# Save all open scripts (Godot effectively writes only the dirty ones).
	if se.has_method("save_all_scripts"):
		se.save_all_scripts()
	else:
		# Fallback: save the currently edited script.
		var cur := se.get_current_script()
		if cur and cur.resource_path != "":
			ResourceSaver.save(cur, cur.resource_path)
	await get_tree().process_frame
	var unsaved := _unsaved_open_scripts()
	if unsaved.is_empty():
		_status_label.text = "All changes saved. Click \"Preview\" to see all occurrences."
		_status_label.add_theme_color_override("font_color", Color(0.5, 0.85, 0.5))
		if _save_btn:
			_save_btn.visible = false
	else:
		_status_label.text = "⚠ Still unsaved: %s." % ", ".join(unsaved)
		_status_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2))


## Returns the file names of open scripts whose buffer has unsaved edits.
func _unsaved_open_scripts() -> PackedStringArray:
	var names := PackedStringArray()
	var se := EditorInterface.get_script_editor()
	var open_scripts := se.get_open_scripts()
	var open_editors := se.get_open_script_editors()
	var current_editor := se.get_current_editor()
	var current_script := se.get_current_script()

	# Check the currently shown editor explicitly (its CodeEdit is the one that
	# actually holds the user's unsaved typing; the indexed instance may not).
	if current_editor and current_script:
		var cce = current_editor.get_base_editor()
		if cce is CodeEdit and (cce as CodeEdit).get_version() != (cce as CodeEdit).get_saved_version():
			names.append(current_script.resource_path.get_file())

	for i in open_scripts.size():
		if i >= open_editors.size() or open_scripts[i] == null:
			continue
		var fname: String = open_scripts[i].resource_path.get_file()
		if fname in names:
			continue
		var ce = open_editors[i].get_base_editor()
		if ce is CodeEdit and (ce as CodeEdit).get_version() != (ce as CodeEdit).get_saved_version():
			names.append(fname)
	return names


# -------------------------------------------------------------------------
# Preview — ask LSP for all rename locations
# -------------------------------------------------------------------------

func _on_preview_pressed() -> void:
	var new_name := _new_name_edit.text.strip_edges()
	if new_name.is_empty():
		_status_label.text = "Warning: new name cannot be empty."
		return
	if not _is_valid_identifier(new_name):
		_status_label.text = "Warning: \"%s\" is not a valid GDScript identifier." % new_name
		return
	if new_name == _old_name_edit.text:
		_status_label.text = "Warning: old and new names are identical."
		return

	_status_label.text = "Searching…"
	_preview_btn.disabled = true
	_preview_results.clear()
	_preview_label.text = ""
	if _preview_label_after:
		_preview_label_after.text = ""
	_preview_coroutine(new_name)


func _preview_coroutine(new_name: String) -> void:
	var lsp := LspClient.new()
	lsp.setup(Engine.get_main_loop() as SceneTree)

	# Root URI of the project
	var project_abs := ProjectSettings.globalize_path("res://")
	var root_uri    := LspClient.path_to_uri(project_abs.trim_suffix("/").trim_suffix("\\"))

	var ok := await lsp.connect_to_lsp(root_uri)
	if not ok:
		_status_label.text = "Cannot connect to the GDScript language server. Is a project open in Godot?"
		_preview_btn.disabled = false
		return

	# Open all .gd files so the LSP has full context.
	# We do NOT send didClose first: on a fresh server the documents were
	# never opened, and Godot logs "closing file without opening it" errors.
	# A didOpen with a strictly-increasing version is enough for the server
	# to refresh its copy. We drain the receive buffer between files so the
	# server's publishDiagnostics replies don't fill the socket and deadlock.
	var sync_version := Time.get_ticks_msec()
	var scanner := FileScanner.new()
	var gd_files := scanner.collect_gd_files("res://")
	var sent := 0
	for abs_path in gd_files:
		var uri := LspClient.path_to_uri(abs_path)
		var f := FileAccess.open(abs_path, FileAccess.READ)
		if f:
			var source := f.get_as_text()
			f.close()
			# Async send yields to the engine when the socket buffer is full so
			# the network layer can flush — prevents the freeze/stall that a
			# blocking did_open causes when streaming many files on big projects.
			await lsp.did_open_async(uri, source, sync_version)
			sent += 1
			if sent % 10 == 0:
				await Engine.get_main_loop().process_frame

	# Wait for LSP to parse all files
	await Engine.get_main_loop().create_timer(1.0).timeout

	# Determine cursor position
	var pos := _symbol_position
	if pos.is_empty():
		_status_label.text = "No cursor position available. Right-click on the symbol first."
		lsp.disconnect_from_lsp()
		_preview_btn.disabled = false
		return


	# PARAMETER CASE: if the symbol is a parameter of the enclosing function,
	# bypass the LSP entirely — Godot's LSP either returns nothing or naive
	# text matches across the whole file for parameters. The correct scope
	# is exactly the function signature + body, which we resolve locally.
	var old_name := _old_name_edit.text
	var changes: Dictionary = {}
	if _is_parameter_of_enclosing_function(pos, old_name):
		lsp.disconnect_from_lsp()
		_preview_btn.disabled = false
		changes = _find_parameter_occurrences(pos, old_name, new_name)
		if changes.is_empty():
			_status_label.text = "No occurrences found."
			return
	else:
		# Request rename from the LSP
		var edit = await lsp.rename(pos["uri"], pos["line"], pos["character"], new_name)

		lsp.disconnect_from_lsp()
		_preview_btn.disabled = false

		if edit == null:
			_status_label.text = "No results. Make sure the cursor is placed on the symbol to rename."
			return

		if edit.has("changes"):
			changes = edit["changes"]
		elif edit.has("documentChanges"):
			for dc in edit["documentChanges"]:
				changes[dc["textDocument"]["uri"]] = dc["edits"]

		if changes.is_empty():
			_status_label.text = "No occurrences found."
			return

	# Scope-aware correction (same as Find all references): Godot's LSP matches
	# variables by name only, so a member `var x` and a function-local `var x`
	# get merged. Recompute the start-file edits honoring GDScript scoping so we
	# never rename the wrong variable.
	changes = _apply_rename_scope_filter(changes, pos, old_name, new_name)
	if changes.is_empty():
		_status_label.text = "No occurrences found."
		return

	var total := 0
	var file_sources: Dictionary = {}  # uri → Array of lines
	for uri in changes:
		total += (changes[uri] as Array).size()
		_preview_results.append({"uri": uri, "edits": changes[uri]})
		# Read source lines for preview display
		var abs_path := LspClient.uri_to_path(uri)
		var f := FileAccess.open(abs_path, FileAccess.READ)
		if f:
			file_sources[uri] = Array(f.get_as_text().split("\n"))
			f.close()

	_pending_new_name = new_name
	_render_preview(total, file_sources)
	get_ok_button().disabled = false


## Rewrites the LSP [changes] so that, in the START file, only the occurrences
## belonging to the caret's scope (member vs local variable) are renamed. Edits
## in OTHER files are kept as-is for a member; dropped for a local (a local
## variable never leaks outside its file). Returns the corrected changes dict.
func _apply_rename_scope_filter(changes: Dictionary, pos: Dictionary,
		old_name: String, new_name: String) -> Dictionary:
	if not _is_plain_identifier(old_name):
		return changes
	var start_uri: String = pos.get("uri", "")
	var abs_start := LspClient.uri_to_path(start_uri)
	var f := FileAccess.open(abs_start, FileAccess.READ)
	if f == null:
		return changes
	var lines := Array(f.get_as_text().split("\n"))
	f.close()

	var result: Dictionary = ScopeFilter.analyze(lines, old_name, int(pos.get("line", -1)))
	if result.is_empty():
		return changes   # couldn't analyze — trust the LSP

	# Build the corrected edit list for the start file from our occurrences.
	var new_edits: Array = []
	for occ in result["occurrences"]:
		new_edits.append({
			"range": {
				"start": {"line": occ["line"], "character": occ["sc"]},
				"end":   {"line": occ["line"], "character": occ["ec"]},
			},
			"newText": new_name,
		})

	var out: Dictionary = {}
	# Normalize URIs for comparison.
	var start_norm := _norm_uri(start_uri)
	for uri in changes:
		if _norm_uri(uri) == start_norm:
			continue   # replaced below
		# For a local variable, drop edits in other files entirely.
		if result["kind"] == "local":
			continue
		out[uri] = changes[uri]
	if not new_edits.is_empty():
		out[start_uri] = new_edits
	return out


func _is_plain_identifier(s: String) -> bool:
	var rx := RegEx.new()
	rx.compile("^[A-Za-z_]\\w*$")
	return rx.search(s) != null


func _norm_uri(uri: String) -> String:
	return LspClient.uri_to_path(uri).replace("\\", "/").to_lower()


func _render_preview(total: int, file_sources: Dictionary) -> void:
	_status_label.text = "%d occurrence(s) across %d file(s) — click \"Rename\" to apply." \
		% [total, _preview_results.size()]

	# Grab a CodeEdit configured like the active script editor so we can
	# reuse its syntax highlighter and colors for the preview lines.
	var hl_edit := _make_highlighter_edit()

	# Line-number color from the editor theme settings
	var line_num_color := "808080"
	var ed_settings := EditorInterface.get_editor_settings()
	var lnc = ed_settings.get_setting("text_editor/theme/highlighting/line_number_color")
	if lnc is Color:
		line_num_color = (lnc as Color).to_html(false)

	# String-literal color — used to render the file paths
	var string_color := "ce9178"
	var sc_setting = ed_settings.get_setting("text_editor/theme/highlighting/string_color")
	if sc_setting is Color:
		string_color = (sc_setting as Color).to_html(false)

	# Indent-guide / tab glyph color — a dimmed version of the text color
	_indent_guide_color = "5a5a5a"
	var fc = ed_settings.get_setting("text_editor/theme/highlighting/text_color")
	if fc is Color:
		var dim := (fc as Color)
		dim.a = 0.35
		_indent_guide_color = dim.to_html(true)

	# Member-variable color (e.g. _index_pool) — semantic, applied manually
	_member_var_color = ""
	var mvc = ed_settings.get_setting("text_editor/theme/highlighting/member_variable_color")
	if mvc is Color:
		_member_var_color = (mvc as Color).to_html(false)

	var res_abs := ProjectSettings.globalize_path("res://")
	var new_name := _new_name_edit.text.strip_edges()

	var bb := ""        # "Before" column
	var bb_after := ""  # "After" column
	for res in _preview_results:
		var uri: String = res["uri"]

		# Decode URI to a readable res:// path
		var abs_path := LspClient.uri_to_path(uri)
		var display  := abs_path
		var res_global := res_abs.replace("\\", "/").trim_suffix("/")
		var abs_fwd    := abs_path.replace("\\", "/")
		if abs_fwd.begins_with(res_global):
			display = "res://" + abs_fwd.substr(res_global.length())

		var edits: Array = res["edits"]
		var header := "[b][color=#%s]%s[/color][/b]  [color=#888888](%d occurrence(s))[/color]\n" \
			% [string_color, display, edits.size()]
		bb       += header
		bb_after += header

		var lines: Array = file_sources.get(uri, [])
		# Defensive: if the source for this URI couldn't be loaded (e.g. a path
		# resolution issue), skip it instead of crashing on an out-of-range
		# line index below.
		if lines.is_empty():
			bb       += "[color=#888888](could not load file source)[/color]\n\n"
			bb_after += "[color=#888888](could not load file source)[/color]\n\n"
			continue

		# Group all edits by line so a line with several occurrences is shown
		# once, with every occurrence highlighted.
		var spans_by_line: Dictionary = {}  # line → Array of [start, end]
		for edit_item in edits:
			var ln: int = edit_item["range"]["start"]["line"]
			var sc: int = edit_item["range"]["start"]["character"]
			var ec: int = edit_item["range"]["end"]["character"]
			# Skip edits whose line is beyond the loaded source (mismatch
			# between the LSP's view and the file on disk).
			if ln < 0 or ln >= lines.size():
				continue
			if not spans_by_line.has(ln):
				spans_by_line[ln] = []
			spans_by_line[ln].append([sc, ec])

		var sorted_lines: Array = spans_by_line.keys()
		sorted_lines.sort()

		# Build the "after" version of every modified line + the spans that
		# cover the new name in each. We keep a full copy of the source with
		# the renames applied so the highlighter has full context per column.
		var after_lines: Array = lines.duplicate()
		var after_spans_by_line: Dictionary = {}
		for ln in spans_by_line:
			var spans: Array = spans_by_line[ln]
			spans.sort_custom(func(a, b): return a[0] < b[0])
			after_lines[ln] = _apply_spans_to_line(lines[ln], spans, new_name)
			after_spans_by_line[ln] = _shift_spans_for_new_name(spans, new_name)

		# Feed the before highlighter ONCE with the full source so the
		# GDScript highlighter resolves keywords, types, strings, comments.
		if hl_edit:
			hl_edit.text = "\n".join(PackedStringArray(lines))

		# Detect member variables declared in this file so we can color their
		# occurrences (the lexical highlighter alone leaves them default-white).
		var member_vars := _collect_member_variables(lines)

		# Compute the max line-number width for right-alignment in this file
		var max_ln := 0
		for ln in sorted_lines:
			max_ln = maxi(max_ln, ln + 1)
		var num_width := str(max_ln).length()

		for ln in sorted_lines:
			if ln >= lines.size():
				continue
			var spans: Array = spans_by_line[ln]

			# Gutter: right-aligned line number + folding marker
			var num_str := str(ln + 1)
			while num_str.length() < num_width:
				num_str = " " + num_str
			# Folding chevron when this line opens a block (ends with ':')
			var fold := " "
			if (lines[ln] as String).strip_edges().ends_with(":"):
				fold = "\u2304"  # ⌄
			var gutter := "[color=#%s]%s[/color] [color=#%s]%s[/color] " \
				% [line_num_color, num_str, _indent_guide_color, fold]

			# Per-column color map for this line. Prefer the REAL open editor's
			# CodeEdit (it has full semantic coloring: member vars, user types);
			# fall back to the detached highlighter for files not open.
			# Per-column color map from the detached highlighter fed with the
			# full source. (Reading the open editor's highlighter is unreliable:
			# it is tied to the editor's visible/cached state and returns
			# offset colors for off-screen lines.)
			var color_map: Dictionary = {}
			if hl_edit and hl_edit.syntax_highlighter:
				color_map = hl_edit.syntax_highlighter.get_line_syntax_highlighting(ln)

			# BEFORE column — original line, old name highlighted
			var colored_before := _colorize_with_map(lines[ln], spans, color_map, member_vars)
			bb += gutter + colored_before + "\n"

			# AFTER column — reuse the SAME color map (rename does not change a
			# token's role/color), shifting colors past each replacement by the
			# length delta so the new name keeps the surrounding colors.
			var after_spans: Array = after_spans_by_line[ln]
			var after_map := _shift_color_map(color_map, spans, new_name)
			# The renamed symbol may itself be (or stop being) a member var, but
			# for display we keep the same member set; if the OLD name was a
			# member, add the NEW name so it stays colored.
			var after_members := member_vars
			if member_vars.has(_old_name_edit.text):
				after_members = member_vars.duplicate()
				after_members[new_name] = true
			var colored_after := _colorize_with_map(after_lines[ln], after_spans, after_map, after_members)
			bb_after += gutter + colored_after + "\n"
		bb += "\n"
		bb_after += "\n"

	if hl_edit:
		hl_edit.queue_free()

	_preview_label.parse_bbcode(bb)
	if _preview_label_after:
		_preview_label_after.parse_bbcode(bb_after)


## Builds a detached CodeEdit that uses a COPY of the active editor's syntax
## highlighter, so get_line_syntax_highlighting() analyses OUR text (not the
## source editor's) while keeping the same colors. Returns null on failure.
func _make_highlighter_edit() -> CodeEdit:
	var se := EditorInterface.get_script_editor()
	var base := se.get_current_editor()
	if base == null:
		return null
	var src_edit := _find_code_edit_node(base)
	if src_edit == null:
		return null

	var ce := CodeEdit.new()
	# Duplicate so the highlighter binds to THIS CodeEdit's text buffer.
	# Sharing the instance would keep it analysing the source editor's text.
	if src_edit.syntax_highlighter:
		ce.syntax_highlighter = src_edit.syntax_highlighter.duplicate(true)
	# Copy theme colors used by get_theme_color("font_color", "TextEdit")
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


## Applies all [spans] on [raw], replacing each occurrence with [new_name].
## Returns the resulting line. Spans must be sorted ascending by start.
func _apply_spans_to_line(raw: String, spans: Array, new_name: String) -> String:
	var result := raw
	# Apply right-to-left so earlier offsets remain valid
	for idx in range(spans.size() - 1, -1, -1):
		var sc: int = spans[idx][0]
		var ec: int = spans[idx][1]
		result = result.substr(0, sc) + new_name + result.substr(ec)
	return result


## Given the original [spans] and the [new_name], returns the spans covering
## the new name occurrences in the rewritten line (accounting for the length
## delta of each replacement).
func _shift_spans_for_new_name(spans: Array, new_name: String) -> Array:
	var result: Array = []
	var offset := 0
	for span in spans:
		var sc: int = span[0]
		var ec: int = span[1]
		var new_start := sc + offset
		var new_end   := new_start + new_name.length()
		result.append([new_start, new_end])
		offset += new_name.length() - (ec - sc)
	return result



## Default text color of the editor (cached helper).
func _default_text_color() -> Color:
	var ed := EditorInterface.get_editor_settings()
	var c = ed.get_setting("text_editor/theme/highlighting/text_color")
	if c is Color:
		return c as Color
	return Color(0.86, 0.86, 0.86)


## If [abs_path] is open in the script editor, returns the per-column color
## map for [line_index] from the REAL CodeEdit (full semantic coloring).
## Returns {} if the file is not open.
func _line_colors_from_open_editor(abs_path: String, line_index: int) -> Dictionary:
	var res_path := ProjectSettings.localize_path(abs_path)
	var se := EditorInterface.get_script_editor()
	var open_scripts := se.get_open_scripts()
	var open_editors := se.get_open_script_editors()
	for i in open_scripts.size():
		if open_scripts[i] == null or open_scripts[i].resource_path != res_path:
			continue
		if i >= open_editors.size():
			return {}
		var ce = open_editors[i].get_base_editor()
		if ce is CodeEdit and line_index < (ce as CodeEdit).get_line_count():
			var sh = (ce as CodeEdit).syntax_highlighter
			if sh:
				return sh.get_line_syntax_highlighting(line_index)
		return {}
	return {}


## Collects names of member variables/consts declared at class scope, so
## their occurrences can be colored like the editor does.
func _collect_member_variables(lines: Array) -> Dictionary:
	var members: Dictionary = {}
	var decl := RegEx.new()
	decl.compile("^(?:@\\w+\\s*(?:\\([^)]*\\))?\\s*)*(?:static\\s+)?(?:var|const)\\s+([A-Za-z_]\\w*)")
	for raw in lines:
		var line: String = raw
		# Only class-scope declarations: no leading indentation
		if line.length() > 0 and (line[0] == " " or line[0] == "\t"):
			continue
		var m := decl.search(line)
		if m:
			members[m.get_string(1)] = true
	return members


## Converts a line into BBCode using a precomputed [color_map] (column →
## {color}), highlighting every [spans] occurrence. [member_vars] names get
## the member-variable color. Indentation is preserved (tabs as guide glyph).
func _colorize_with_map(
		raw: String,
		spans: Array,
		color_map: Dictionary,
		member_vars: Dictionary = {}
) -> String:
	var default_color := _default_text_color()

	# Pre-sort the color-change columns so we can find the active color at any
	# position (the highlighter only emits an entry where the color CHANGES).
	var change_cols: Array = color_map.keys()
	change_cols.sort()

	# Ranges of member-variable identifiers (whole-word) to recolor.
	var member_ranges: Array = []
	if not member_vars.is_empty() and _member_var_color != "":
		var word := RegEx.new()
		word.compile("[A-Za-z_]\\w*")
		for m in word.search_all(raw):
			if member_vars.has(m.get_string()):
				member_ranges.append([m.get_start(), m.get_end()])

	var out := ""
	var i := 0
	var cur_color := default_color
	var next_idx := 0
	while i < raw.length():
		# Advance through every color-change column at or before i
		while next_idx < change_cols.size() and change_cols[next_idx] <= i:
			var entry = color_map[change_cols[next_idx]]
			if entry is Dictionary and entry.has("color"):
				cur_color = entry["color"]
			next_idx += 1

		var ch := raw[i]
		# Tab → indent guide glyph + spaces, in the guide color
		if ch == "\t":
			out += "[color=#%s]%s[/color]" % [_indent_guide_color, _tab_glyph()]
			i += 1
			continue
		var ch_bb := _escape_bbcode(ch)

		var in_symbol := false
		for span in spans:
			if i >= span[0] and i < span[1]:
				in_symbol = true
				break

		if in_symbol:
			out += "[bgcolor=#3d5a80][color=#ffffff]%s[/color][/bgcolor]" % ch_bb
		else:
			var color_hex := cur_color.to_html(false)
			for mr in member_ranges:
				if i >= mr[0] and i < mr[1]:
					color_hex = _member_var_color
					break
			out += "[color=#%s]%s[/color]" % [color_hex, ch_bb]
		i += 1

	return out


## Shifts a [color_map] (column → {color}) to account for replacing each
## original span by [new_name] (length delta), so the After line reuses the
## exact same token colors as the Before line.
func _shift_color_map(color_map: Dictionary, spans: Array, new_name: String) -> Dictionary:
	if spans.is_empty():
		return color_map.duplicate()

	# Build cumulative offset map: for a column c in the ORIGINAL line, how
	# much it shifts in the new line.
	var sorted_spans := spans.duplicate()
	sorted_spans.sort_custom(func(a, b): return a[0] < b[0])

	var shifted: Dictionary = {}
	for col in color_map.keys():
		var offset := 0
		for span in sorted_spans:
			var sc: int = span[0]
			var ec: int = span[1]
			if col >= ec:
				offset += new_name.length() - (ec - sc)
			# columns inside a span keep their start color via the span start
		shifted[col + offset] = color_map[col]
	return shifted


func _escape_bbcode(s: String) -> String:
	return s.replace("[", "[lb]")


## Returns the indent-guide glyph followed by spaces, matching the editor's
## tab visualization. Reproduced with U+203A (›) + U+2759 (❙), then spaces
## to fill the 4-wide tab stop.
func _tab_glyph() -> String:
	return "\u203a\u2759  "  # ›❙ + 2 spaces


# -------------------------------------------------------------------------
# Confirm — apply WorkspaceEdit
# -------------------------------------------------------------------------

func _on_confirmed() -> void:
	if _preview_results.is_empty():
		push_warning("GDScript Refactoring: nothing to apply.")
		return

	var new_name := _new_name_edit.text.strip_edges()
	if not _is_valid_identifier(new_name):
		return

	# Enable silent auto-reload BEFORE writing so Godot reloads without popup
	var settings    := EditorInterface.get_editor_settings()
	var setting_key := "text_editor/behavior/files/auto_reload_scripts_on_external_change"
	var prev_reload : bool = settings.get_setting(setting_key)
	settings.set_setting(setting_key, true)

	# Read original content of every file BEFORE modifying (needed for undo)
	var originals: Dictionary = {}  # uri → original String content
	for res in _preview_results:
		var abs_path := LspClient.uri_to_path(res["uri"])
		var f := FileAccess.open(abs_path, FileAccess.READ)
		if f:
			originals[res["uri"]] = f.get_as_text()
			f.close()

	# Build and apply the WorkspaceEdit
	var workspace_edit := {"changes": {}}
	for res in _preview_results:
		workspace_edit["changes"][res["uri"]] = res["edits"]

	var written := LspClient.apply_workspace_edit(workspace_edit)

	_status_label.text = "Done: %d file(s) updated." % written.size()

	# Register the action on the plugin's own undo stack.
	# (Ctrl+Z in the script editor only triggers the CodeEdit's local undo,
	# never EditorUndoRedoManager — so the plugin intercepts Ctrl+Z itself.)
	if editor_plugin != null and not written.is_empty():
		var files: Dictionary = {}  # abs_path → {old, new}
		for uri in written:
			var abs_path := LspClient.uri_to_path(uri)
			files[abs_path] = {
				"old": originals.get(uri, ""),
				"new": written[uri]
			}
		editor_plugin.push_rename_action(files)

	# Notify the editor filesystem for each modified file
	var fs := EditorInterface.get_resource_filesystem()
	for uri in written:
		var abs_path := LspClient.uri_to_path(uri)
		var res_path := ProjectSettings.localize_path(abs_path)
		fs.update_file(res_path)

	fs.scan_sources()

	_trigger_focus_check.call_deferred()
	_restore_auto_reload_deferred.call_deferred(settings, setting_key, prev_reload)


## Writes EVERY affected file to disk and syncs EVERY open buffer BEFORE doing
## a single filesystem refresh. Refreshing per-file would make Godot re-parse
## after the first file while the others still hold the old symbol, producing
## transient parse errors and re-triggering the reload dialog. Used by undo/redo.
## [files] = { abs_path: {"old": ..., "new": ...} }, [which] = "old"/"new".
func _write_all_and_refresh(files: Dictionary, which: String) -> void:
	var settings    := EditorInterface.get_editor_settings()
	var setting_key := "text_editor/behavior/files/auto_reload_scripts_on_external_change"
	var prev_reload : bool = settings.get_setting(setting_key)
	settings.set_setting(setting_key, true)

	# 1) Write every file to disk first.
	for abs_path in files:
		var content: String = files[abs_path][which]
		var f := FileAccess.open(abs_path, FileAccess.WRITE)
		if f:
			f.store_string(content)
			f.close()

	# 2) Let any native undo settle, then sync every open buffer.
	var tree := EditorInterface.get_base_control().get_tree()
	await tree.process_frame
	await tree.process_frame
	for abs_path in files:
		_sync_open_buffer(abs_path, files[abs_path][which])

	# Keep each in-memory Script resource's source_code aligned with the new
	# disk content (WITHOUT reload(), which would re-parse mid-batch while the
	# other files still hold the old symbol). This prevents a later manual save
	# from writing stale source and re-triggering the "newer on disk" dialog.
	for abs_path in files:
		var res_path := ProjectSettings.localize_path(abs_path)
		if ResourceLoader.has_cached(res_path):
			var res := ResourceLoader.load(res_path)
			if res is Script:
				(res as Script).source_code = files[abs_path][which]

	# 3) A single filesystem refresh once ALL files are coherent. We do NOT
	# trigger a focus check here: the open buffers already hold the new content
	# (synced above), so there is nothing to reload. Forcing the external-change
	# notification would only make Godot compare disk mtime vs its in-memory
	# timestamp and pop the "files are newer on disk" dialog for no reason.
	var fs := EditorInterface.get_resource_filesystem()
	for abs_path in files:
		fs.update_file(ProjectSettings.localize_path(abs_path))
	fs.scan_sources()

	# The CodeEdit of a NON-visible tab keeps stale rendering after a
	# programmatic .text change (it re-reads from the Script resource when shown,
	# and only Ctrl+S forces that). Re-selecting each affected script via
	# edit_script() forces the ScriptEditor to refresh that tab's view; we then
	# restore the tab the user was on so the active tab doesn't change.
	var se := EditorInterface.get_script_editor()
	var original := se.get_current_script()
	for abs_path in files:
		var res_path := ProjectSettings.localize_path(abs_path)
		var scr := load(res_path)
		if scr is Script:
			EditorInterface.edit_script(scr)
			await EditorInterface.get_base_control().get_tree().process_frame
	if original:
		EditorInterface.edit_script(original)

	_restore_auto_reload_deferred.call_deferred(settings, setting_key, prev_reload)


## If [abs_path] is open in the script editor, overwrite its CodeEdit text
## with [content] and clear the undo history divergence, so the buffer
## matches the disk exactly.
func _sync_open_buffer(abs_path: String, content: String) -> void:
	var res_path := ProjectSettings.localize_path(abs_path)
	var se := EditorInterface.get_script_editor()
	var open_scripts := se.get_open_scripts()
	var open_editors := se.get_open_script_editors()
	var current_editor := se.get_current_editor()
	var current_script := se.get_current_script()

	# Collect EVERY ScriptTextEditor instance that edits this file. Godot keeps
	# more than one instance per script, and any of them may be the one shown
	# when the user switches to that tab — so we must update all of them, not
	# just the first indexed match, otherwise a non-visible instance keeps the
	# stale text until Ctrl+S.
	var editors_for_file: Array = []
	# The currently shown editor is authoritative for the visible file; add it
	# first so what the user sees is updated immediately.
	if current_script and current_script.resource_path == res_path and current_editor:
		editors_for_file.append(current_editor)
	# open_scripts[i] is aligned with open_editors[i]; collect ALL matches.
	for i in open_scripts.size():
		if open_scripts[i] == null or open_scripts[i].resource_path != res_path:
			continue
		if i < open_editors.size() and not (open_editors[i] in editors_for_file):
			editors_for_file.append(open_editors[i])

	if editors_for_file.is_empty():
		return

	for ed in editors_for_file:
		var code_edit = ed.get_base_editor()
		if code_edit == null or not (code_edit is CodeEdit):
			continue
		var ce := code_edit as CodeEdit
		if ce.text != content:
			var caret_line := ce.get_caret_line()
			var caret_col  := ce.get_caret_column()
			var scroll_v   := ce.scroll_vertical
			ce.text = content
			caret_line = mini(caret_line, ce.get_line_count() - 1)
			caret_col  = mini(caret_col,  ce.get_line(caret_line).length())
			ce.set_caret_line(caret_line)
			ce.set_caret_column(caret_col)
			ce.scroll_vertical = scroll_v
			ce.queue_redraw()
			_force_code_edit_refresh.call_deferred(ce)
		ce.clear_undo_history()
		ce.tag_saved_version()


## Forces a focused CodeEdit to actually repaint its text. Setting .text does
## not always refresh the view until the user interacts. A real (if tiny)
## scroll change forces the CodeEdit to redraw its visible lines. We do NOT
## touch the text or history here (that would re-dirty version/undo state).
func _force_code_edit_refresh(ce: CodeEdit) -> void:
	if not is_instance_valid(ce):
		return
	var sv := ce.scroll_vertical
	# Bump the scroll by one then restore it: forces a visible-line redraw.
	if sv > 0:
		ce.scroll_vertical = sv - 1
	else:
		ce.scroll_vertical = sv + 1
	await get_tree().process_frame
	if is_instance_valid(ce):
		ce.scroll_vertical = sv
		ce.queue_redraw()


## Propagates APPLICATION_FOCUS_IN through the editor tree — this is what
## triggers Godot's "files changed on disk" check, normally fired when the
## user alt-tabs back to the editor.
func _trigger_focus_check() -> void:
	var root := EditorInterface.get_base_control().get_tree().root
	root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_IN)


func _restore_auto_reload_deferred(
		settings: EditorSettings,
		key: String,
		value: bool) -> void:
	settings.set_setting(key, value)


## Returns true if [changes] only contains the declaration line itself
## (i.e. the LSP found only where the parameter is declared, not its uses).
## Returns true if [symbol] appears as a parameter in the signature of the
## function that contains [pos] (the cursor line).
func _is_parameter_of_enclosing_function(pos: Dictionary, symbol: String) -> bool:
	var abs_path := LspClient.uri_to_path(pos["uri"])
	var f := FileAccess.open(abs_path, FileAccess.READ)
	if f == null:
		return false
	var lines: Array = Array(f.get_as_text().split("\n"))
	f.close()

	var cursor_line: int = pos["line"]

	# Walk upward to find the func declaration
	for i in range(cursor_line, -1, -1):
		var stripped: String = (lines[i] as String).strip_edges()
		if not (stripped.begins_with("func ") or stripped.begins_with("static func ")):
			continue
		# Collect the full signature (may span multiple lines)
		var sig := stripped
		var j := i + 1
		while not sig.contains("):") and j < lines.size():
			sig += " " + (lines[j] as String).strip_edges()
			j += 1
		# Extract the params string between ( and )
		var paren_start := sig.find("(")
		var paren_end   := sig.rfind(")")
		if paren_start == -1 or paren_end == -1:
			return false
		var params_str := sig.substr(paren_start + 1, paren_end - paren_start - 1)
		# Each param token may be "name: Type = default" or just "name"
		for param in params_str.split(","):
			var token := param.strip_edges()
			var name_part := token.split(":")[0].split("=")[0].strip_edges()
			if name_part == symbol:
				return true
		return false
	return false


## Finds all occurrences of [old_name] as a whole word within the function
## (signature + body) that contains [pos].
## Returns a WorkspaceEdit-style changes dict {uri: [edits]}.
func _find_parameter_occurrences(
		pos: Dictionary,
		old_name: String,
		new_name: String
) -> Dictionary:
	var uri      : String = pos["uri"]
	var abs_path := LspClient.uri_to_path(uri)

	var f := FileAccess.open(abs_path, FileAccess.READ)
	if f == null:
		return {}
	var lines: Array = Array(f.get_as_text().split("\n"))
	f.close()

	var cursor_line: int = pos["line"]

	# Walk upward to find the func declaration line
	var func_line   := -1
	var func_indent := 0
	for i in range(cursor_line, -1, -1):
		var stripped: String = (lines[i] as String).strip_edges()
		if stripped.begins_with("func ") or stripped.begins_with("static func "):
			func_line   = i
			func_indent = _indent_level(lines[i])
			break
	if func_line == -1:
		return {}

	# Walk forward to find the end of the function body
	var body_end := lines.size() - 1
	for i in range(func_line + 1, lines.size()):
		var raw: String = lines[i]
		if raw.strip_edges().is_empty() or raw.strip_edges().begins_with("#"):
			continue
		if _indent_level(raw) <= func_indent:
			body_end = i - 1
			break

	# Find all whole-word occurrences in [func_line .. body_end]
	var regex := RegEx.new()
	if regex.compile("(?<![\\w])%s(?![\\w])" % old_name) != OK:
		return {}

	var edits: Array = []
	for i in range(func_line, body_end + 1):
		var line: String = lines[i]
		for m in regex.search_all(line):
			edits.append({
				"range": {
					"start": {"line": i, "character": m.get_start()},
					"end":   {"line": i, "character": m.get_end()}
				},
				"newText": new_name
			})

	if edits.is_empty():
		return {}
	return {uri: edits}


func _indent_level(line: String) -> int:
	var count := 0
	for c in line:
		if c == "\t":
			count += 4
		elif c == " ":
			count += 1
		else:
			break
	return count


# -------------------------------------------------------------------------
# Validation
# -------------------------------------------------------------------------

func _is_valid_identifier(s: String) -> bool:
	if s.is_empty():
		return false
	if not (s[0] == "_" or s[0].to_upper() != s[0].to_lower()):
		return false
	for c in s:
		if not (c == "_" or c.to_upper() != c.to_lower() or c.is_valid_int()):
			return false
	return true
