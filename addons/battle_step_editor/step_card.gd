@tool
extends PanelContainer

const StepCatalog = preload("res://addons/battle_step_editor/step_catalog.gd")
const StepListScenePath := "res://addons/battle_step_editor/step_array_content.tscn"

@onready var _step_icon: TextureRect = %StepIcon
@onready var _index_label: Label = %IndexLabel
@onready var _type_label: Label = %TypeLabel
@onready var _summary_label: Label = %SummaryLabel
@onready var _await_toggle: Button = %AwaitToggle
@onready var _reorder_button: Button = %ReorderButton
@onready var _duplicate_button: Button = %DuplicateButton
@onready var _remove_button: Button = %RemoveButton
@onready var _children: VBoxContainer = %Children
@onready var _body: VBoxContainer = %Body
@onready var _inspector_margin: PanelContainer = %InspectorMargin

var editor
var step: BattleStep
var index := 0
var expanded := false

var _inspector: EditorInspector
var _child_editors: Array = []
var _sequence_properties: Array[StringName] = []
var _has_children := false


func _ready() -> void:
	_apply_button_icons()

	_await_toggle.toggled.connect(_on_await_toggled)
	_reorder_button.gui_input.connect(_on_reorder_input)
	_reorder_button.mouse_default_cursor_shape = Control.CURSOR_MOVE
	_duplicate_button.pressed.connect(_duplicate)
	_remove_button.pressed.connect(_remove)
	gui_input.connect(_on_card_gui_input)


func setup(p_editor, p_step: BattleStep, p_index: int) -> void:
	editor = p_editor
	step = p_step
	index = p_index

	_sequence_properties = []

	if step != null:
		_sequence_properties = StepCatalog.sequence_properties(step)

	_has_children = not _sequence_properties.is_empty()

	_refresh_icon()
	refresh()

	if step != null and not step.changed.is_connected(refresh):
		step.changed.connect(refresh)

	if _has_children:
		_build_children()


func _build_children() -> void:
	if step == null or not _child_editors.is_empty():
		return

	_children.visible = true

	for property in _sequence_properties:
		var list = load(StepListScenePath).instantiate()
		list.set_title(String(property).replace("_", " ").capitalize())
		_children.add_child(list)
		list.steps_changed.connect(_on_child_steps_committed)
		list.setup(step, property)
		_child_editors.append(list)


func _on_child_steps_committed(property: StringName, steps: Array) -> void:
	if step == null:
		return

	step.set(property, steps)
	step.emit_changed()

	if editor != null:
		editor._mark_step_changed()


func refresh() -> void:
	if step == null:
		_index_label.text = str(index + 1)
		_type_label.text = "Missing step"
		_summary_label.text = ""
		_summary_label.visible = false
		_refresh_icon()
		_refresh_await_toggle()
		return

	_index_label.text = str(index + 1)
	_type_label.text = StepCatalog.type_label(step)
	_refresh_icon()
	_refresh_summary()
	_refresh_await_toggle()


func _process(_delta: float) -> void:
	_refresh_summary()


func _refresh_summary() -> void:
	if step == null:
		return

	var text := StepCatalog.summary(step)

	if _summary_label.text != text:
		_summary_label.text = text
		_summary_label.visible = not text.is_empty()

	var tip := (
		"%s\n%s" % [_type_label.text, text]
		if not text.is_empty()
		else _type_label.text
	)
	_type_label.tooltip_text = tip
	_summary_label.tooltip_text = tip


func set_expanded(value: bool) -> void:
	if expanded == value:
		return

	expanded = value
	_body.visible = value
	_apply_expanded_background()
	set_process(value or _has_children)

	if value:
		_ensure_inspector()

	if _inspector != null:
		_watch_inspector_rows(_inspector)


func _ensure_inspector() -> void:
	if step == null or _inspector != null:
		return

	_inspector = EditorInspector.create_default_inspector()
	_inspector.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_inspector.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_inspector.property_edited.connect(_on_property_edited)
	_inspector_margin.add_child(_inspector)
	_inspector.edit(step)
	_watch_inspector_rows(_inspector)


func _watch_inspector_rows(node: Node) -> void:
	if node.get_class() == "EditorInspectorCategory":
		node.visible = false
	elif node is EditorProperty and node.get_edited_property() in [&"script", &"wait"]:
		node.visible = false
	elif node is Button and node.text.contains("Metadata"):
		node.visible = false
	elif node is EditorInspector and node != _inspector:
		if not node.property_edited.is_connected(_on_property_edited):
			node.property_edited.connect(_on_property_edited)

	if node is VBoxContainer and not node.child_entered_tree.is_connected(_on_inspector_row_added):
		node.child_entered_tree.connect(_on_inspector_row_added)

	for child in node.get_children():
		_watch_inspector_rows(child)


func _on_inspector_row_added(node: Node) -> void:
	_watch_inspector_rows(node)


func _on_property_edited(_property: StringName = &"", _value: Variant = null) -> void:
	refresh()


func _toggle() -> void:
	if editor != null:
		editor._toggle_card(self)


func _on_reorder_input(event: InputEvent) -> void:
	if editor != null:
		editor._reorder_step_drag(self, event)


func _duplicate() -> void:
	if editor != null:
		editor._duplicate_step(index)


func _remove() -> void:
	if editor != null:
		editor._remove_step(index)


func _on_card_gui_input(event: InputEvent) -> void:
	if step == null:
		return

	if not event is InputEventMouseButton:
		return

	var click := event as InputEventMouseButton

	if not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return

	_toggle()


func _refresh_await_toggle() -> void:
	var applicable := _wait_visible()
	_await_toggle.visible = applicable

	if not applicable:
		return

	var waiting := bool(step.get("wait"))
	_await_toggle.set_pressed_no_signal(waiting)
	_await_toggle.tooltip_text = (
		"Waits for this step to finish"
		if waiting
		else "Starts the next step immediately"
	)


func _wait_visible() -> bool:
	if step == null:
		return false

	for property in step.get_property_list():
		if str(property.name) != "wait":
			continue

		var info: Dictionary = property.duplicate()
		step._validate_property(info)
		return bool(int(info.usage) & PROPERTY_USAGE_EDITOR)

	return false


func _on_await_toggled(pressed: bool) -> void:
	if step == null or not _wait_visible():
		return

	_set_wait(pressed)


func _set_wait(value: bool) -> void:
	if bool(step.get("wait")) == value:
		return

	step.set("wait", value)
	step.emit_changed()
	_refresh_await_toggle()

	if editor != null:
		editor._mark_step_changed()


func _apply_expanded_background() -> void:
	if not expanded:
		get_theme_stylebox("panel").bg_color = get_theme_color("base_color", "Editor")
		return

	var base := get_theme_stylebox("panel")

	if not base is StyleBoxFlat:
		return

	var style := (base as StyleBoxFlat).duplicate()
	style.bg_color = _expanded_color()
	add_theme_stylebox_override("panel", style)
	_inspector_margin.add_theme_stylebox_override("panel", get_theme_stylebox("sub_inspector_property_bg0", "EditorStyles"))


func _expanded_color() -> Color:
	var current := get_theme_stylebox("panel")
	var fallback := (current as StyleBoxFlat).bg_color if current is StyleBoxFlat else Color()

	if not Engine.is_editor_hint():
		return fallback

	var base := EditorInterface.get_base_control()

	if base == null:
		return fallback

	var box := base.get_theme_stylebox("sub_inspector_property_bg1", "EditorStyles")

	if box is StyleBoxFlat:
		return(box as StyleBoxFlat).bg_color

	return fallback


func _refresh_icon() -> void:
	var icon := _editor_icon(StepCatalog.icon_name(step)) if step != null else null
	_step_icon.texture = icon
	_step_icon.visible = icon != null


func _apply_button_icons() -> void:
	_apply_button_icon(_await_toggle, "Timer")
	_apply_button_icon(_reorder_button, "TripleBar")
	_apply_button_icon(_duplicate_button, "Duplicate")
	_apply_button_icon(_remove_button, "Remove")


func _apply_button_icon(button: Button, icon_name: String) -> void:
	var icon := _editor_icon(icon_name)

	if icon == null:
		return

	button.icon = icon
	button.text = ""


func _editor_icon(icon_name: String) -> Texture2D:
	if icon_name.is_empty() or not Engine.is_editor_hint():
		return null

	var base := EditorInterface.get_base_control()

	if base == null:
		return null

	return base.get_theme_icon(icon_name, "EditorIcons")
