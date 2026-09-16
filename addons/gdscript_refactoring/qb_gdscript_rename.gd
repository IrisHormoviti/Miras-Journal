@tool
extends EditorPlugin

const RenameDialog    = preload("res://addons/gdscript_refactoring/qb_rename_dialog.gd")
const LspClient       = preload("res://addons/gdscript_refactoring/qb_lsp_client.gd")
const ReferencesPanel = preload("res://addons/gdscript_refactoring/qb_references_panel.gd")

const SHORTCUT_SETTING := "gdscript_refactoring/rename_shortcut"
const SHORTCUT_PATH    := "gdscript_refactoring/rename_symbol"
const FIND_REFS_PATH   := "gdscript_refactoring/find_all_references"

var _dialog: AcceptDialog
var _context_menu_handler: Node
var _references_panel: Control = null


func _enter_tree() -> void:
	_register_shortcut_setting()
	_register_find_refs_shortcut()

	_dialog = RenameDialog.new()
	_dialog.editor_plugin = self
	_dialog.hide()
	get_editor_interface().get_base_control().add_child(_dialog)

	# Dockable "References" view in the bottom panel (hidden until used).
	_references_panel = ReferencesPanel.new()
	_references_panel.editor_plugin = self
	add_control_to_bottom_panel(_references_panel, "References")

	_context_menu_handler = ContextMenuHandler.new()
	_context_menu_handler.plugin = self
	add_child(_context_menu_handler)
	_context_menu_handler.watch_script_editor(
		get_editor_interface().get_script_editor()
	)


## Registers the customizable rename shortcut. On Godot 4.6+ it is added to the
## native Shortcuts tab of Editor Settings via add_shortcut(); on older
## versions it falls back to a regular Shortcut-typed editor setting.
func _register_shortcut_setting() -> void:
	var es := get_editor_interface().get_editor_settings()
	var default_sc := _make_default_shortcut()

	if es.has_method("add_shortcut"):
		# Godot 4.6+: appears in Editor Settings → Shortcuts under the
		# "Gdscript Refactoring" category as "Rename Symbol". Re-install the
		# default when missing OR emptied by the user (an event-less Shortcut
		# can never fire and vanishes from the Shortcuts list).
		if not es.has_shortcut(SHORTCUT_PATH) or _shortcut_is_empty(es.get_shortcut(SHORTCUT_PATH)):
			default_sc.resource_name = "Rename Symbol"
			es.add_shortcut(SHORTCUT_PATH, default_sc)
		return

	# Fallback (Godot < 4.6): a Shortcut-typed setting in the settings list.
	if not es.has_setting(SHORTCUT_SETTING):
		es.set_setting(SHORTCUT_SETTING, default_sc)
	es.set_initial_value(SHORTCUT_SETTING, default_sc, false)
	es.add_property_info({
		"name": SHORTCUT_SETTING,
		"type": TYPE_OBJECT,
		"hint": PROPERTY_HINT_RESOURCE_TYPE,
		"hint_string": "Shortcut",
	})


## Default rename shortcut: Shift+F2.
func _make_default_shortcut() -> Shortcut:
	var ev := InputEventKey.new()
	ev.keycode       = KEY_F2
	ev.shift_pressed = true
	var sc := Shortcut.new()
	sc.events = [ev]
	return sc


## Returns the currently configured rename Shortcut (falls back to default).
func get_rename_shortcut() -> Shortcut:
	var es := get_editor_interface().get_editor_settings()
	if es.has_method("get_shortcut"):
		var sc = es.get_shortcut(SHORTCUT_PATH)
		if sc is Shortcut:
			return sc
	elif es.has_setting(SHORTCUT_SETTING):
		var sc2 = es.get_setting(SHORTCUT_SETTING)
		if sc2 is Shortcut:
			return sc2
	return _make_default_shortcut()


## Default "Find all references" shortcut: Alt+Shift+F2 (thematically paired
## with the Shift+F2 rename shortcut, and free of OS/Godot conflicts).
func _make_default_find_refs_shortcut() -> Shortcut:
	var ev := InputEventKey.new()
	ev.keycode      = KEY_F2
	ev.alt_pressed   = true
	ev.shift_pressed = true
	var sc := Shortcut.new()
	sc.events = [ev]
	return sc


## Registers the "Find all references" shortcut (Editor Settings → Shortcuts).
func _register_find_refs_shortcut() -> void:
	var es := get_editor_interface().get_editor_settings()
	if not es.has_method("add_shortcut"):
		return
	var default_sc := _make_default_find_refs_shortcut()
	default_sc.resource_name = "Find all references"
	# Not registered yet, OR registered but emptied (the user cleared every
	# event in Editor Settings, which leaves an event-less Shortcut that can
	# never fire and disappears from the list). In both cases, (re)install the
	# default so the binding is usable again.
	if not es.has_shortcut(FIND_REFS_PATH) or _shortcut_is_empty(es.get_shortcut(FIND_REFS_PATH)):
		es.add_shortcut(FIND_REFS_PATH, default_sc)
		return
	# Migrate: if the stored shortcut still matches a previous default
	# (Ctrl+Alt+F2 or Alt+F2), update it to the current default so testers
	# who tried earlier builds get the new binding. A user-customized value
	# that differs from those is left untouched.
	var cur = es.get_shortcut(FIND_REFS_PATH)
	if cur is Shortcut and _is_legacy_find_refs_shortcut(cur):
		es.add_shortcut(FIND_REFS_PATH, default_sc)


func _shortcut_is_empty(sc) -> bool:
	return not (sc is Shortcut) or (sc as Shortcut).events.is_empty()


func _is_legacy_find_refs_shortcut(sc: Shortcut) -> bool:
	for ev in sc.events:
		if ev is InputEventKey and (ev as InputEventKey).keycode == KEY_F2:
			var k := ev as InputEventKey
			# Ctrl+Alt+F2 (first default) or Alt+F2 (second default)
			if k.alt_pressed and not k.shift_pressed:
				return true
	return false


func get_find_refs_shortcut() -> Shortcut:
	var es := get_editor_interface().get_editor_settings()
	if es.has_method("get_shortcut"):
		var sc = es.get_shortcut(FIND_REFS_PATH)
		if sc is Shortcut:
			return sc
	return _make_default_find_refs_shortcut()


## Opens the References panel and searches for the symbol at [symbol_pos].
func open_references(symbol: String, symbol_pos: Dictionary) -> void:
	if is_instance_valid(_references_panel):
		_references_panel.find_references(symbol, symbol_pos)


func _exit_tree() -> void:
	if is_instance_valid(_context_menu_handler):
		_context_menu_handler.cleanup()
		_context_menu_handler.queue_free()
	_context_menu_handler = null
	if is_instance_valid(_references_panel):
		remove_control_from_bottom_panel(_references_panel)
		_references_panel.queue_free()
	_references_panel = null
	if is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = null


func get_active_code_edit() -> CodeEdit:
	var se := get_editor_interface().get_script_editor()
	var base := se.get_current_editor()
	if base == null:
		return null
	return _find_code_edit(base)


func _find_code_edit(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node as CodeEdit
	for child in node.get_children():
		var result := _find_code_edit(child)
		if result:
			return result
	return null


func open_rename_dialog(symbol: String, symbol_pos: Dictionary) -> void:
	_dialog.open(symbol, symbol_pos)


# -------------------------------------------------------------------------
# Plugin-level undo/redo for multi-file renames.
# Ctrl+Z inside the script editor only triggers the CodeEdit's local undo,
# so the plugin intercepts the shortcut when the local history is empty
# and applies its own multi-file revert.
# -------------------------------------------------------------------------

# -------------------------------------------------------------------------
# Multi-file undo/redo.
# The script editor consumes Ctrl+Z/Ctrl+Y for its own local CodeEdit undo
# and never routes them to EditorUndoRedoManager, and no GDScript API exists
# to drive the manager's undo()/redo() (proposal godotengine/godot-proposals
# #13377). So we keep our own stack and intercept the shortcuts in _input.
# -------------------------------------------------------------------------

var _undo_stack: Array[Dictionary] = []  # [{abs_path: {old, new}}]
var _redo_stack: Array[Dictionary] = []


func push_rename_action(files: Dictionary) -> void:
	# [files] = { abs_path: {"old": <text>, "new": <text>} }
	_undo_stack.append(files)
	_redo_stack.clear()
	_clear_affected_histories_later(files.keys())


func perform_undo() -> bool:
	if _undo_stack.is_empty():
		return false
	var files: Dictionary = _undo_stack.pop_back()
	_redo_stack.append(files)
	_apply_files_deferred(files, "old")
	return true


func perform_redo() -> bool:
	if _redo_stack.is_empty():
		return false
	var files: Dictionary = _redo_stack.pop_back()
	_undo_stack.append(files)
	_apply_files_deferred(files, "new")
	return true


## Rewrites every affected file in one batch (all files written and buffers
## synced before a single filesystem refresh), then re-tags saved versions.
func _apply_files_deferred(files: Dictionary, which: String) -> void:
	await _dialog._write_all_and_refresh(files, which)
	_clear_affected_histories_later(files.keys())


## Re-tags every affected open CodeEdit as saved (version == saved) in a few
## passes, because the silent reload settles asynchronously. We intentionally
## do NOT call clear_undo_history() here: in Godot 4 it can leave the version
## counter below the saved version, which the editor reads as "file on disk is
## newer" and shows the reload dialog.
func _clear_affected_histories_later(paths: Array) -> void:
	for delay in [0.1, 0.4, 0.9, 1.5]:
		await get_tree().create_timer(delay).timeout
		_clear_histories_now(paths)


func _clear_histories_now(paths: Array) -> void:
	var se := get_editor_interface().get_script_editor()
	var open_scripts := se.get_open_scripts()
	var open_editors := se.get_open_script_editors()
	for abs_path in paths:
		var res_path := ProjectSettings.localize_path(abs_path)
		for i in open_scripts.size():
			if open_scripts[i] == null or open_scripts[i].resource_path != res_path:
				continue
			if i >= open_editors.size():
				break
			var ce = open_editors[i].get_base_editor()
			if ce is CodeEdit:
				# Clear native history (so has_undo() is false and the next
				# Ctrl+Z reaches our multi-file undo) then tag as saved. This
				# order keeps version == saved.
				(ce as CodeEdit).clear_undo_history()
				(ce as CodeEdit).tag_saved_version()
			break


func get_word_under_cursor(code_edit: CodeEdit) -> String:
	var line_idx := code_edit.get_caret_line()
	var col_idx  := code_edit.get_caret_column()
	var line     := code_edit.get_line(line_idx)
	if line.is_empty():
		return ""
	var start := col_idx
	while start > 0 and _is_word_char(line[start - 1]):
		start -= 1
	var end := col_idx
	while end < line.length() and _is_word_char(line[end]):
		end += 1
	return line.substr(start, end - start)


## Returns the property-access path under the caret, e.g. "velocity.y" when the
## caret is on "y" in "velocity.y". Walks left across ".identifier" segments.
## Returns just the word if there is no leading "obj." part.
func get_access_path_under_cursor(code_edit: CodeEdit) -> String:
	var line_idx := code_edit.get_caret_line()
	var col_idx  := code_edit.get_caret_column()
	var line     := code_edit.get_line(line_idx)
	if line.is_empty():
		return ""
	# Right edge of the word under the caret, then extend across trailing
	# ".member" segments so "velocity" in "velocity.length" yields the full
	# "velocity.length" path regardless of which segment the caret is on.
	var end := col_idx
	while end < line.length() and _is_word_char(line[end]):
		end += 1
	while end + 1 < line.length() and line[end] == "." and _is_word_char(line[end + 1]):
		end += 1  # step onto the dot
		while end < line.length() and _is_word_char(line[end]):
			end += 1
	# Left edge, then extend across leading "member." segments.
	var start := col_idx
	while start > 0 and _is_word_char(line[start - 1]):
		start -= 1
	while start > 1 and line[start - 1] == "." and _is_word_char(line[start - 2]):
		start -= 1  # step onto the dot
		while start > 0 and _is_word_char(line[start - 1]):
			start -= 1
	return line.substr(start, end - start)


func _is_word_char(c: String) -> bool:
	return c.length() == 1 and (c == "_" or c.to_upper() != c.to_lower() or c.is_valid_int())


# -------------------------------------------------------------------------
# Renameable-symbol detection
# -------------------------------------------------------------------------

## GDScript reserved keywords — cannot be renamed.
const GDSCRIPT_KEYWORDS := [
	# Declarations
	"var", "const", "func", "class", "class_name", "extends", "signal", "enum",
	"static",
	# Control flow
	"if", "elif", "else", "for", "while", "match", "when", "break", "continue",
	"pass", "return",
	# Operators / logic
	"and", "or", "not", "in", "is", "as",
	# Literals / constants
	"true", "false", "null", "self", "super",
	# Misc
	"await", "breakpoint", "tool", "void",
	# Built-in primitive type names
	"bool", "int", "float", "String", "StringName", "NodePath",
	"Vector2", "Vector2i", "Vector3", "Vector3i", "Vector4", "Vector4i",
	"Rect2", "Rect2i", "Transform2D", "Transform3D", "Plane", "Quaternion",
	"AABB", "Basis", "Projection", "Color", "RID", "Callable", "Signal",
	"Dictionary", "Array", "PackedByteArray", "PackedInt32Array",
	"PackedInt64Array", "PackedFloat32Array", "PackedFloat64Array",
	"PackedStringArray", "PackedVector2Array", "PackedVector3Array",
	"PackedColorArray", "Variant",
	# Annotations are caught by '@' check, but the bare words too
	"export", "onready", "tool", "icon", "rpc",
	# Global functions that look like identifiers
	"print", "push_error", "push_warning", "assert", "preload", "load",
	"range", "len", "abs", "min", "max", "clamp", "lerp",
]


## Value-component members: native only when used as a property access
## (obj.x / value.y). A bare "x" may be a legitimate user variable, so those
## stay renameable unless accessed via a dot.
const NATIVE_COMPONENTS := [
	"x", "y", "z", "w", "r", "g", "b", "a",
	"length", "normalized", "end",
]

## Inherited native node properties: these belong to the engine and are always
## the same property even when accessed bare (self.velocity), so they are never
## renameable, whether or not a dot follows.
const NATIVE_PROPERTIES := [
	"position", "global_position", "rotation", "global_rotation", "scale",
	"transform", "global_transform", "basis", "global_basis", "origin",
	"quaternion", "velocity", "up_direction", "motion_mode",
	"name", "owner", "visible", "modulate", "self_modulate", "z_index",
	"size",
]


## Returns true if the symbol under the cursor can be renamed:
## - a valid identifier
## - not a GDScript keyword or built-in type
## - not a native engine class (Node, Sprite2D, …)
## - not a number literal
## - not inside a string literal or comment
func is_renameable_symbol(code_edit: CodeEdit, symbol: String) -> bool:
	if symbol.is_empty():
		return false

	# Must be a valid identifier (starts with letter or _)
	var first := symbol[0]
	if not (first == "_" or first.to_upper() != first.to_lower()):
		return false  # starts with a digit → numeric literal

	# Reserved keyword or built-in type?
	if symbol in GDSCRIPT_KEYWORDS:
		return false

	# Native engine class (Node, Sprite2D, RefCounted, …)?
	if ClassDB.class_exists(symbol):
		return false

	# Inside a string literal or comment? → not code, not renameable
	if _cursor_in_string_or_comment(code_edit):
		return false

	# Native member/property access (e.g. the ".y" of velocity.y, or the
	# native "velocity" itself)? Renaming these is meaningless and unsafe.
	if _is_native_member_access(code_edit, symbol):
		return false

	return true


## True if [symbol] is an inherited native node property (velocity, position…).
func is_native_property(symbol: String) -> bool:
	return symbol in NATIVE_PROPERTIES


## True when [symbol] must not be renamed because it is a native member:
## - a native inherited property (velocity, position, …) is blocked always;
## - a value component (x, y, length, …) is blocked only when used as a
##   property access (preceded by "." or followed by ".<identifier>").
func _is_native_member_access(code_edit: CodeEdit, symbol: String) -> bool:
	# Inherited node properties: always native, even when bare (self access).
	if symbol in NATIVE_PROPERTIES:
		return true
	if symbol not in NATIVE_COMPONENTS:
		return false
	var line := code_edit.get_line(code_edit.get_caret_line())
	var col  := code_edit.get_caret_column()
	# Find the word bounds around the caret.
	var start := col
	while start > 0 and _is_word_char(line[start - 1]):
		start -= 1
	var end := col
	while end < line.length() and _is_word_char(line[end]):
		end += 1
	# Preceded by "." → it's obj.<symbol> (property access).
	if start >= 1 and line[start - 1] == ".":
		return true
	# Followed by ".<identifier>" → it's <symbol>.sub (e.g. velocity.y).
	if end < line.length() and line[end] == "." \
			and end + 1 < line.length() and _is_word_char(line[end + 1]):
		return true
	return false


## Scans the current line up to the caret to check whether the caret sits
## inside a string literal or after a comment marker.
func _cursor_in_string_or_comment(code_edit: CodeEdit) -> bool:
	var line := code_edit.get_line(code_edit.get_caret_line())
	var col  := code_edit.get_caret_column()
	var in_single := false
	var in_double := false
	var i := 0
	while i < col and i < line.length():
		var c := line[i]
		if c == "\\" and (in_single or in_double):
			i += 2
			continue
		if c == "'" and not in_double:
			in_single = not in_single
		elif c == '"' and not in_single:
			in_double = not in_double
		elif c == "#" and not in_single and not in_double:
			return true  # caret is after a comment marker
		i += 1
	return in_single or in_double


# =============================================================================
class ContextMenuHandler extends Node:
	var plugin
	var _hooked_popup: PopupMenu  = null
	var _hooked_code_edits: Array = []
	var _hooked_code_edit: CodeEdit = null
	var _hooked_popups: Array = []


	func watch_script_editor(se: ScriptEditor) -> void:
		if not se.editor_script_changed.is_connected(_on_script_changed):
			se.editor_script_changed.connect(_on_script_changed)
		_hook_current_editor()
		# The script editor's Edit menu is created lazily; re-scan for a while
		# so we catch it once it exists (e.g. after the user opens it once).
		_start_menu_rescan()


	func _start_menu_rescan() -> void:
		# Keep scanning periodically (cheap) so we hook the Edit menu whenever
		# it appears, for the whole lifetime of the plugin.
		while is_inside_tree():
			await get_tree().create_timer(1.5).timeout
			_hook_edit_menus()


	func cleanup() -> void:
		_hooked_popup = null
		_hooked_code_edits.clear()


	func _on_script_changed(_script) -> void:
		_hook_current_editor()
		# Safety net: a file edited by a multi-file undo while it was NOT the
		# current tab can end up with the shown CodeEdit still holding the old
		# text (we updated a different instance). When the user switches to it,
		# reload the visible editor from disk if it diverges.
		_resync_shown_editor_from_disk.call_deferred()


	func _resync_shown_editor_from_disk() -> void:
		await get_tree().process_frame
		var se := EditorInterface.get_script_editor()
		var scr := se.get_current_script()
		var ce: CodeEdit = plugin.get_active_code_edit()
		if scr == null or ce == null:
			return
		# NEVER touch a buffer that has unsaved user edits: version != saved
		# means the user typed something not yet saved, and reloading from disk
		# would silently destroy their work. Only resync clean buffers.
		if ce.get_version() != ce.get_saved_version():
			return
		var f := FileAccess.open(scr.resource_path, FileAccess.READ)
		if f == null:
			return
		var disk := f.get_as_text()
		f.close()
		if ce.text == disk:
			return  # already in sync
		var line := ce.get_caret_line()
		var col := ce.get_caret_column()
		var sv := ce.scroll_vertical
		ce.text = disk
		ce.set_caret_line(mini(line, ce.get_line_count() - 1))
		ce.set_caret_column(mini(col, ce.get_line(ce.get_caret_line()).length()))
		ce.scroll_vertical = sv
		ce.clear_undo_history()
		ce.tag_saved_version()
		ce.queue_redraw()


	func _hook_current_editor() -> void:
		await get_tree().process_frame
		# Hook the Edit menu every time (popups may be created lazily).
		_hook_edit_menus()
		var code_edit: CodeEdit = plugin.get_active_code_edit()
		if code_edit == null or code_edit in _hooked_code_edits:
			return
		_hooked_code_edits.append(code_edit)
		var erase_cb := _hooked_code_edits.erase.bind(code_edit)
		if not code_edit.tree_exited.is_connected(erase_cb):
			code_edit.tree_exited.connect(erase_cb, CONNECT_ONE_SHOT)
		# Right-click menu injection goes through gui_input.
		var input_cb := _on_code_edit_gui_input.bind(code_edit)
		if not code_edit.gui_input.is_connected(input_cb):
			code_edit.gui_input.connect(input_cb)


	func _hook_edit_menus() -> void:
		# The script editor's Edit menu is the popup of a MenuButton in the
		# script editor toolbar. A MenuButton's popup is only a child of the
		# tree while shown, so we must reach it via get_popup() on the button
		# (which persists), not by scanning root for visible PopupMenus.
		var se := EditorInterface.get_script_editor()
		for mb_node in _find_menu_buttons(se):
			var mb := mb_node as MenuButton
			if mb == null:
				continue
			var pop: PopupMenu = mb.get_popup()
			if pop == null or pop in _hooked_popups:
				continue
			# Identify the script editor Edit menu: has Undo + Copy, no "scene".
			var has_undo := false
			var has_copy := false
			var is_scene := false
			for i in pop.item_count:
				var t := pop.get_item_text(i).to_lower()
				if t.begins_with("undo") or t.begins_with("annul"):
					has_undo = true
				if t.begins_with("copy") or t.begins_with("copie"):
					has_copy = true
				if t.contains("scene"):
					is_scene = true
			if not (has_undo and has_copy and not is_scene):
				continue
			_hooked_popups.append(pop)
			if not pop.id_pressed.is_connected(_on_edit_menu_id):
				pop.id_pressed.connect(_on_edit_menu_id.bind(pop))
			if not pop.index_pressed.is_connected(_on_edit_menu_index):
				pop.index_pressed.connect(_on_edit_menu_index.bind(pop))
			# Godot enables/disables the Undo/Redo items in about_to_popup based
			# on the CodeEdit's native history. Since our multi-file undo keeps
			# its own stacks (and clears the native history), we re-enable those
			# items here to reflect OUR stacks. Connecting after Godot's own
			# handler means ours runs last and wins.
			if not pop.about_to_popup.is_connected(_on_edit_menu_about_to_popup):
				pop.about_to_popup.connect(_on_edit_menu_about_to_popup.bind(pop))


	## Re-enables the Edit menu's Undo/Redo items when our custom stacks have
	## actions, so the menu reflects the multi-file undo state (not just the
	## CodeEdit's native history, which we clear).
	func _on_edit_menu_about_to_popup(pop: PopupMenu) -> void:
		for i in pop.item_count:
			var t := pop.get_item_text(i).to_lower()
			if t.begins_with("undo") or t.begins_with("annul"):
				if not plugin._undo_stack.is_empty():
					pop.set_item_disabled(i, false)
			elif t.begins_with("redo") or t.begins_with("rétabl") or t.begins_with("retabl"):
				if not plugin._redo_stack.is_empty():
					pop.set_item_disabled(i, false)


	func _find_menu_buttons(node: Node) -> Array:
		var result: Array = []
		if node is MenuButton:
			result.append(node)
		for child in node.get_children():
			result.append_array(_find_menu_buttons(child))
		return result


	func _on_edit_menu_id(id: int, pop: PopupMenu) -> void:
		var idx := pop.get_item_index(id)
		if idx == -1:
			return
		var label := pop.get_item_text(idx).to_lower()
		if label.begins_with("undo") or label.begins_with("annul"):
			_menu_undo_deferred()
		elif label.begins_with("redo") or label.begins_with("rétabl") or label.begins_with("retabl"):
			_menu_redo_deferred()


	## Runs after the native menu undo has fired (a few frames later), so our
	## multi-file rewrite is the last thing to touch the buffers and the editor
	## sees them as clean (no "files are newer on disk" popup).
	func _menu_undo_deferred() -> void:
		await get_tree().process_frame
		await get_tree().process_frame
		plugin.perform_undo()


	func _menu_redo_deferred() -> void:
		await get_tree().process_frame
		await get_tree().process_frame
		plugin.perform_redo()


	func _on_edit_menu_index(_index: int, _pop: PopupMenu) -> void:
		pass  # handled via id_pressed


	## The rename shortcut is handled here in _input rather than via the
	## CodeEdit's gui_input: the script editor consumes some key combos through
	## its own shortcut system before they reach gui_input. Undo/redo is NOT
	## handled here anymore — it goes through the native EditorUndoRedoManager.
	## Builds the LSP position dict {uri,line,character} for the caret in the
	## given CodeEdit (empty if there is no current script).
	func _symbol_pos_at_caret(focus: CodeEdit) -> Dictionary:
		var se := EditorInterface.get_script_editor()
		var current_script := se.get_current_script()
		if current_script == null:
			return {}
		var abs_path := ProjectSettings.globalize_path(current_script.resource_path)
		var sym: String = plugin.get_word_under_cursor(focus)
		return {
			"uri":       LspClient.path_to_uri(abs_path),
			"line":      focus.get_caret_line(),
			"character": focus.get_caret_column(),
			"access_path": plugin.get_access_path_under_cursor(focus),
			"native_property": plugin.is_native_property(sym),
		}


	func _input(event: InputEvent) -> void:
		if not (event is InputEventKey):
			return
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return

		# Only act when the focus is inside one of our watched CodeEdits.
		var focus := plugin.get_active_code_edit() as CodeEdit
		if focus == null:
			return
		var vp_focus = focus.get_viewport().gui_get_focus_owner() if focus.get_viewport() else null
		if vp_focus != focus:
			return

		# Rename shortcut (configurable, default Shift+F2)
		var rename_sc: Shortcut = plugin.get_rename_shortcut()
		if rename_sc and rename_sc.matches_event(event):
			var symbol: String = plugin.get_word_under_cursor(focus)
			if plugin.is_renameable_symbol(focus, symbol):
				plugin.open_rename_dialog(symbol, _symbol_pos_at_caret(focus))
				get_viewport().set_input_as_handled()
			return

		# Find all references shortcut (configurable, default Alt+Shift+F2)
		var refs_sc: Shortcut = plugin.get_find_refs_shortcut()
		if refs_sc and refs_sc.matches_event(event):
			var symbol2: String = plugin.get_word_under_cursor(focus)
			var access2: String = plugin.get_access_path_under_cursor(focus)
			# Works on renameable identifiers AND on native property accesses
			# (velocity.y), which are not renameable but are searchable.
			var ok2: bool = plugin.is_renameable_symbol(focus, symbol2) \
					or _is_property_access_target(symbol2, access2)
			if ok2:
				plugin.open_references(symbol2, _symbol_pos_at_caret(focus))
				get_viewport().set_input_as_handled()
			return

		# Multi-file undo / redo. We rely on has_undo()/has_redo() (real native
		# history) rather than version==saved: after a silent reload the version
		# can differ from saved even though the user made no local edits, which
		# would wrongly make the first Ctrl+Z do a local undo (requiring a second
		# press). If the CodeEdit has no native history to undo, our multi-file
		# undo takes over immediately.
		# Multi-file undo / redo.
		# Decision rule:
		#  - version != saved  → the user has real unsaved edits in this buffer,
		#    so let the native Ctrl+Z undo those first.
		#  - version == saved  → the buffer is clean; any has_undo() is just
		#    residual native history from the silent reload, NOT user edits, so
		#    our multi-file undo takes over (this is the common case right after
		#    a rename, where has_undo() is true but there's nothing user-made to
		#    undo).
		if not key.ctrl_pressed:
			return
		var clean := focus.get_version() == focus.get_saved_version()
		if key.keycode == KEY_Z and not key.shift_pressed:
			if not clean and focus.has_undo():
				return  # user's own unsaved edits: native undo first
			if plugin.perform_undo():
				get_viewport().set_input_as_handled()
		elif (key.keycode == KEY_Z and key.shift_pressed) or key.keycode == KEY_Y:
			if not clean and focus.has_redo():
				return
			if plugin.perform_redo():
				get_viewport().set_input_as_handled()


	func _on_code_edit_gui_input(event: InputEvent, code_edit: CodeEdit) -> void:
		# Right-click → context menu injection (keyboard is handled in _input)
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
				call_deferred("_inject_menu_items", code_edit)


	func _inject_menu_items(code_edit: CodeEdit) -> void:
		var popup := _find_context_popup(code_edit)
		if popup == null:
			return
		_hooked_popup = popup
		_hooked_code_edit = code_edit
		# Connect once per popup; bound Callables differ each call so we must
		# guard with is_connected on the SAME stored callable.
		if not popup.about_to_popup.is_connected(_on_popup_about_to_show):
			popup.about_to_popup.connect(_on_popup_about_to_show)
		if not popup.id_pressed.is_connected(_on_menu_id_pressed):
			popup.id_pressed.connect(_on_menu_id_pressed)
		_add_rename_item(popup, code_edit)


	func _on_popup_about_to_show() -> void:
		if _hooked_popup and _hooked_code_edit:
			call_deferred("_add_rename_item", _hooked_popup, _hooked_code_edit)


	func _add_rename_item(popup: PopupMenu, code_edit: CodeEdit) -> void:
		# Guard: bail if our items are already present.
		for i in range(popup.item_count):
			if popup.get_item_id(i) == 9900 or popup.get_item_id(i) == 9901:
				return
		var symbol: String = plugin.get_word_under_cursor(code_edit)
		# The access path ("velocity.y") decides whether Find all references is
		# offered even when Rename is not.
		var access_path: String = plugin.get_access_path_under_cursor(code_edit)
		var can_rename: bool = plugin.is_renameable_symbol(code_edit, symbol)
		print("[MENU] symbol='%s' access='%s' can_rename=%s caret_col=%d" % [
			symbol, access_path, can_rename, code_edit.get_caret_column()])
		# Find all references also works on native property accesses (velocity.y),
		# which are NOT renameable. Offer it whenever we have a usable target.
		var can_find_refs: bool = can_rename or _is_property_access_target(symbol, access_path)

		if not can_rename and not can_find_refs:
			return
		popup.add_separator("GDScript Refactoring")

		if can_rename:
			var idx := popup.item_count
			popup.add_item("Rename...", 9900)
			popup.set_item_metadata(idx, symbol)
			# Godot renders and handles the attached Shortcut natively.
			popup.set_item_shortcut(idx, plugin.get_rename_shortcut(), false)

		if can_find_refs:
			var idx2 := popup.item_count
			popup.add_item("Find all references", 9901)
			popup.set_item_metadata(idx2, symbol)
			popup.set_item_shortcut(idx2, plugin.get_find_refs_shortcut(), false)


	## True when the target is a property access we can search references for
	## even if it isn't renameable (e.g. "velocity.y"): a non-empty access path
	## containing a dot, whose trailing member is a valid identifier.
	func _is_property_access_target(symbol: String, access_path: String) -> bool:
		# A dotted path (velocity.y, velocity.length) is always a valid target.
		if access_path.find(".") != -1 and not symbol.is_empty():
			var f0 := symbol[0]
			return f0 == "_" or f0.to_upper() != f0.to_lower()
		# A bare native inherited property (velocity, position, …) is also a
		# valid self-access target even without a trailing member.
		return plugin.is_native_property(symbol)


	func _on_menu_id_pressed(id: int) -> void:
		if _hooked_popup == null:
			return
		if id != 9900 and id != 9901:
			return
		var code_edit := _hooked_code_edit
		if code_edit == null:
			return
		var item_idx := _hooked_popup.get_item_index(id)
		if item_idx == -1:
			return
		var symbol: String = _hooked_popup.get_item_metadata(item_idx)

		# Build the LSP position from the current caret.
		var se := EditorInterface.get_script_editor()
		var current_script := se.get_current_script()
		var symbol_pos := {}
		if current_script:
			var abs_path := ProjectSettings.globalize_path(current_script.resource_path)
			symbol_pos = {
				"uri":       LspClient.path_to_uri(abs_path),
				"line":      code_edit.get_caret_line(),
				"character": code_edit.get_caret_column(),
				# Full property-access path under the caret ("velocity.y") so the
				# references panel can handle property accesses distinctly.
				"access_path": plugin.get_access_path_under_cursor(code_edit),
				"native_property": plugin.is_native_property(symbol),
			}

		if id == 9900:
			plugin.open_rename_dialog(symbol, symbol_pos)
		else:
			plugin.open_references(symbol, symbol_pos)


	func _find_context_popup(code_edit: CodeEdit) -> PopupMenu:
		for child in code_edit.get_children():
			if child is PopupMenu:
				return child as PopupMenu
		return _find_visible_popup(plugin.get_tree().root)


	func _find_visible_popup(node: Node) -> PopupMenu:
		if node is PopupMenu and (node as PopupMenu).visible:
			return node as PopupMenu
		for child in node.get_children():
			var result := _find_visible_popup(child)
			if result:
				return result
		return null
