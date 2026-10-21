@tool
extends PanelContainer

const StepCatalog = preload("res://addons/action_sequence_editor/step_catalog.gd")
const StepListScenePath := "res://addons/action_sequence_editor/action_sequence_content.tscn"

@onready var step_icon: TextureRect = %StepIcon
@onready var index_label: Label = %IndexLabel
@onready var type_label: Label = %TypeLabel
@onready var summary_label: Label = %SummaryLabel
@onready var await_toggle: Button = %AwaitToggle
@onready var reorder_button: Button = %ReorderButton
@onready var duplicate_button: Button = %DuplicateButton
@onready var remove_button: Button = %RemoveButton
@onready var children: VBoxContainer = %Children
@onready var body: PanelContainer = %Body
@onready var inspector_panel: PanelContainer = %InspectorPanel

var editor
var step: BattleStep
var index := 0
var expanded := false

var inspector: EditorInspector
var child_editors: Array = []
var sequence_properties: Array[StringName] = []
var has_children := false


func _ready() -> void:
	apply_button_icons()

	await_toggle.toggled.connect(on_await_toggled)
	reorder_button.gui_input.connect(on_reorder_input)
	reorder_button.mouse_default_cursor_shape = Control.CURSOR_MOVE
	duplicate_button.pressed.connect(on_duplicate_pressed)
	remove_button.pressed.connect(on_remove_pressed)
	gui_input.connect(on_card_gui_input)


func setup(p_editor, p_step: BattleStep, p_index: int) -> void:
	editor = p_editor
	step = p_step
	index = p_index

	sequence_properties = []

	if step != null:
		sequence_properties = StepCatalog.sequence_properties(step)

	has_children = not sequence_properties.is_empty()

	refresh_icon()
	refresh()
	apply_expanded_background()

	if step != null and not step.changed.is_connected(refresh):
		step.changed.connect(refresh)

	if has_children:
		build_children()


func build_children() -> void:
	if step == null or not child_editors.is_empty():
		return

	children.visible = true

	for property in sequence_properties:
		var list = load(StepListScenePath).instantiate()
		list.set_title(String(property).replace("_", " ").capitalize())
		children.add_child(list)
		list.steps_changed.connect(on_child_steps_committed)
		list.setup(step, property)
		child_editors.append(list)


func on_child_steps_committed(property: StringName, steps: Array) -> void:
	if step == null:
		return

	step.set(property, steps)
	step.emit_changed()

	if editor != null:
		editor.mark_step_changed()


func refresh() -> void:
	if step == null:
		index_label.text = str(index + 1)
		type_label.text = "Missing step"
		summary_label.text = ""
		summary_label.visible = false
		refresh_icon()
		refresh_await_toggle()
		return

	index_label.text = str(index + 1)
	type_label.text = StepCatalog.type_label(step)
	refresh_icon()
	refresh_summary()
	refresh_await_toggle()


func _process(delta: float) -> void:
	refresh_summary()


func refresh_summary() -> void:
	if step == null:
		return

	var text := StepCatalog.summary(step)

	if summary_label.text != text:
		summary_label.text = text
		summary_label.visible = not text.is_empty()

	var tip := (
		"%s\n%s" % [type_label.text, text]
		if not text.is_empty()
		else type_label.text
	)
	type_label.tooltip_text = tip
	summary_label.tooltip_text = tip


func set_expanded(value: bool) -> void:
	if expanded == value:
		return

	expanded = value
	body.visible = value
	apply_expanded_background()
	set_process(value or has_children)

	if value:
		ensure_inspector()

	if inspector != null:
		watch_inspector_rows(inspector)


func ensure_inspector() -> void:
	if step == null or inspector != null:
		return

	inspector = EditorInspector.create_default_inspector()
	inspector.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inspector.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inspector.property_edited.connect(on_property_edited)
	inspector_panel.add_child(inspector)
	inspector.edit(step)
	watch_inspector_rows(inspector)


func watch_inspector_rows(node: Node) -> void:
	if node.get_class() == "EditorInspectorCategory":
		node.visible = false
	elif node is EditorProperty and node.get_edited_property() in [&"script", &"wait"]:
		node.visible = false
	elif node is Button and node.text.contains("Metadata"):
		node.visible = false
	elif node is EditorInspector and node != inspector:

		if not node.property_edited.is_connected(on_property_edited):
			node.property_edited.connect(on_property_edited)

	if node is VBoxContainer and not node.child_entered_tree.is_connected(on_inspector_row_added):
		node.child_entered_tree.connect(on_inspector_row_added)

	for child in node.get_children():
		watch_inspector_rows(child)


func on_inspector_row_added(node: Node) -> void:
	watch_inspector_rows(node)


func on_property_edited(property: StringName = &"", value: Variant = null) -> void:
	refresh()


func toggle() -> void:
	if editor != null:
		editor.toggle_card(self)


func on_reorder_input(event: InputEvent) -> void:
	if editor != null:
		editor.reorder_step_drag(self, event)


func on_duplicate_pressed() -> void:
	if editor != null:
		editor.duplicate_step(index)


func on_remove_pressed() -> void:
	if editor != null:
		editor.remove_step(index)


func on_card_gui_input(event: InputEvent) -> void:
	if step == null:
		return

	if not event is InputEventMouseButton:
		return

	var click := event as InputEventMouseButton

	if not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return

	toggle()


func refresh_await_toggle() -> void:
	var applicable := wait_visible()
	await_toggle.visible = applicable

	if not applicable:
		return

	var waiting := bool(step.get("wait"))
	await_toggle.set_pressed_no_signal(waiting)
	await_toggle.tooltip_text = (
		"Waits for this step to finish"
		if waiting
		else "Starts the next step immediately"
	)


func wait_visible() -> bool:
	if step == null:
		return false

	for property in step.get_property_list():
		if str(property.name) != "wait":
			continue

		var info: Dictionary = property.duplicate()
		step._validate_property(info)
		return bool(int(info.usage) & PROPERTY_USAGE_EDITOR)

	return false


func on_await_toggled(pressed: bool) -> void:
	if step == null or not wait_visible():
		return

	set_wait(pressed)


func set_wait(value: bool) -> void:
	if bool(step.get("wait")) == value:
		return

	step.set("wait", value)
	step.emit_changed()
	refresh_await_toggle()

	if editor != null:
		editor.mark_step_changed()


func apply_expanded_background() -> void:
	var base := get_theme_stylebox("panel")

	if not base is StyleBoxFlat:
		return

	var style := (base as StyleBoxFlat).duplicate()
	style.bg_color = card_background()
	add_theme_stylebox_override("panel", style)

	# The body keeps the darker family colour so the expanded content stays
	# readable against the brighter header.
	var body_style := body.get_theme_stylebox("panel")

	if body_style is StyleBoxFlat:
		var body_copy := (body_style as StyleBoxFlat).duplicate()
		body_copy.bg_color = body_background()
		body.add_theme_stylebox_override("panel", body_copy)


## The card surface, brighter while the card is selected.
func card_background() -> Color:
	if expanded:
		return StepCatalog.selected_color_for_path(script_path())

	return StepCatalog.card_color_for_path(script_path())


## The body surface, always the darker family colour.
func body_background() -> Color:
	return StepCatalog.card_color_for_path(script_path())


func script_path() -> String:
	if step == null:
		return ""

	var script := step.get_script() as Script

	if script == null:
		return ""

	return script.resource_path


func refresh_icon() -> void:
	var icon := editor_icon(StepCatalog.icon_name(step)) if step != null else null
	step_icon.texture = icon
	step_icon.visible = icon != null
	step_icon.modulate = StepCatalog.icon_color_for_path(script_path())


func apply_button_icons() -> void:
	apply_button_icon(await_toggle, "Timer")
	apply_button_icon(reorder_button, "TripleBar")
	apply_button_icon(duplicate_button, "Duplicate")
	apply_button_icon(remove_button, "Remove")


func apply_button_icon(button: Button, icon_name: String) -> void:
	var icon := editor_icon(icon_name)

	if icon == null:
		return

	button.icon = icon
	button.text = ""


func editor_icon(icon_name: String) -> Texture2D:
	if icon_name.is_empty() or not Engine.is_editor_hint():
		return null

	var base := EditorInterface.get_base_control()

	if base == null:
		return null

	return base.get_theme_icon(icon_name, "EditorIcons")
