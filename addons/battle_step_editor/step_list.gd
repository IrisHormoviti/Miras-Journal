@tool
extends PanelContainer

const StepCardScene = preload("res://addons/battle_step_editor/step_card.tscn")
const StepCatalog = preload("res://addons/battle_step_editor/step_catalog.gd")

signal steps_changed(property: StringName, steps: Array)

@onready var _title_label: Label = %TitleLabel
@onready var _count_label: Label = %CountLabel
@onready var _add_button: MenuButton = %AddButton
@onready var _list: VBoxContainer = %StepList
@onready var _guide: ColorRect = %Guide
@onready var _indent: MarginContainer = %Indent

var _object: Object
var _property: StringName = &""
var _known_property: StringName = &""
var _title := ""
var _cards: Array = []
var _signature: Array[int] = [-1]
var _object_id := 0
var _expanded_id := 0
var _selected_index := -1
var _reorder_card = null
var _reorder_index := -1
var _reorder_accum := 0.0
var _reorder_changed := false


func _ready() -> void:
	_add_button.icon = _editor_icon("Add")
	_add_button.get_popup().id_pressed.connect(_on_add_pressed)
	_add_button.get_popup().about_to_popup.connect(_build_add_menu)
	_apply_title()
	_apply_nesting()

	if _object != null:
		refresh()


func setup(object: Object, property: StringName) -> void:
	_object = object
	_property = property

	if is_node_ready():
		refresh()


func set_title(text: String) -> void:
	_title = text

	if is_node_ready():
		_apply_title()


func refresh() -> void:
	if _object == null:
		_clear_cards()
		_count_label.text = _count_text(0)
		return

	var object_id := _object.get_instance_id()

	if object_id != _object_id or _property != _known_property:
		_object_id = object_id
		_known_property = _property
		_signature = [-1]
		_expanded_id = 0
		_selected_index = -1

	var steps := _typed_steps(_steps())
	var signature: Array[int] = []

	for step in steps:
		signature.append(step.get_instance_id())

	if signature == _signature:
		_refresh_cards(steps)
		return

	_signature = signature
	_rebuild(steps)


func _clear_cards() -> void:
	for card in _cards:
		_list.remove_child(card)
		card.queue_free()

	_cards.clear()


func _steps() -> Array:
	if _object == null:
		return []

	var value = _object.get(_property)

	if value is Array:
		return value

	return []


func _typed_steps(source: Array) -> Array[BattleStep]:
	var result: Array[BattleStep] = []

	for step in source:
		if step is BattleStep:
			result.append(step)

	return result


func _rebuild(steps: Array[BattleStep]) -> void:
	_clear_cards()
	_count_label.text = _count_text(steps.size())

	var expanded_found := false

	for i in steps.size():
		var step := steps[i]
		var card := StepCardScene.instantiate()
		_list.add_child(card)
		card.setup(self, step, i)
		_cards.append(card)

		if step.get_instance_id() == _expanded_id:
			card.set_expanded(true)
			expanded_found = true

	if not expanded_found:
		_expanded_id = 0


func _refresh_cards(steps: Array[BattleStep]) -> void:
	_count_label.text = _count_text(steps.size())

	if _cards.size() != steps.size():
		_rebuild(steps)
		return

	for i in _cards.size():
		_cards[i].index = i
		_cards[i].refresh()


func _count_text(count: int) -> String:
	if count == 0:
		return "No steps"

	return "%d step%s" % [count, "" if count == 1 else "s"]


func _set_steps(steps: Array[BattleStep]) -> void:
	_commit(steps)


func _mark_step_changed() -> void:
	_commit(_steps())


func _commit(steps: Array) -> void:
	steps_changed.emit(_property, steps)
	refresh()


func _add_step(path: String) -> void:
	var script := load(path) as Script

	if script == null or not script.can_instantiate():
		return

	var step = script.new()

	if not step is BattleStep:
		return

	var steps := _typed_steps(_steps())
	var index := steps.size()

	if _selected_index >= 0 and _selected_index < steps.size():
		index = _selected_index + 1

	steps.insert(index, step)
	_selected_index = index
	_expanded_id = step.get_instance_id()
	_set_steps(steps)


func _reorder_step_drag(card, event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton

		if button.button_index != MOUSE_BUTTON_LEFT:
			return

		if button.pressed:
			_reorder_card = card
			_reorder_index = card.index
			_reorder_accum = 0.0
			_reorder_changed = false
		else:
			_finish_reorder()

		return

	if event is InputEventMouseMotion and _reorder_card != null:
		_reorder_accum += (event as InputEventMouseMotion).relative.y
		_step_reorder()


func _step_reorder() -> void:
	var distance: float = _reorder_card.size.y + float(_list.get_theme_constant("separation"))

	if distance <= 0.0:
		return

	while absf(_reorder_accum) >= distance:
		var direction := 1 if _reorder_accum > 0.0 else -1
		var target := _reorder_index + direction

		if target < 0 or target >= _cards.size():
			_reorder_accum = 0.0
			return

		_reorder_accum -= distance * direction
		_apply_reorder(_reorder_index, target)
		_reorder_index = target
		_reorder_changed = true


func _apply_reorder(from: int, to: int) -> void:
	var card = _cards[from]
	_cards.remove_at(from)
	_cards.insert(to, card)
	_list.move_child(card, to)
	_sync_card_indices()


func _sync_card_indices() -> void:
	for i in _cards.size():
		_cards[i].index = i


func _finish_reorder() -> void:
	if _reorder_card == null:
		return

	if _reorder_changed:
		_selected_index = _reorder_index
		_commit_reorder()

	_reorder_card = null
	_reorder_index = -1
	_reorder_accum = 0.0
	_reorder_changed = false


func _commit_reorder() -> void:
	var steps: Array[BattleStep] = []

	for card in _cards:
		if card.step != null:
			steps.append(card.step)

	var signature: Array[int] = []

	for step in steps:
		signature.append(step.get_instance_id())

	_signature = signature
	_set_steps(steps)


func _duplicate_step(index: int) -> void:
	var steps := _typed_steps(_steps())

	if index < 0 or index >= steps.size():
		return

	var copy = steps[index].duplicate(true)

	if not copy is BattleStep:
		return

	steps.insert(index + 1, copy)

	_selected_index = index + 1
	_expanded_id = copy.get_instance_id()
	_set_steps(steps)


func _remove_step(index: int) -> void:
	var steps := _typed_steps(_steps())

	if index < 0 or index >= steps.size():
		return

	var removed_id := steps[index].get_instance_id()
	steps.remove_at(index)

	_selected_index = mini(index, steps.size() - 1)

	if _expanded_id == removed_id:
		_expanded_id = 0

	_set_steps(steps)


func _toggle_card(card) -> void:
	if card.step == null:
		return

	var step_id: int = card.step.get_instance_id()
	_expanded_id = 0 if _expanded_id == step_id else step_id
	_selected_index = card.index

	for other in _cards:
		other.set_expanded(other.step != null and other.step.get_instance_id() == _expanded_id)


func _build_add_menu() -> void:
	var popup := _add_button.get_popup()
	popup.clear(true)
	popup.search_bar_enabled = true

	for entry in StepCatalog.entries():
		var id := popup.get_item_count()
		popup.add_item("%s / %s" % [
			entry["family"],
			StepCatalog.class_label(entry["class"]),
		])
		popup.set_item_metadata(id, entry["path"])

		var icon := _editor_icon(str(entry["icon"]))

		if icon != null:
			popup.set_item_icon(id, icon)


func _on_add_pressed(id: int) -> void:
	var path := str(_add_button.get_popup().get_item_metadata(id))

	if not path.is_empty():
		_add_step(path)


func _apply_title() -> void:
	_title_label.text = _title
	_title_label.visible = not _title.is_empty()


func _nesting_depth() -> int:
	var depth := 0
	var node := get_parent()

	while node != null:
		if node.has_method("_nesting_depth"):
			depth += 1

		node = node.get_parent()

	return depth


func _apply_nesting() -> void:
	var depth := _nesting_depth()

	if depth <= 0 or _guide == null or _indent == null:
		return

	_guide.visible = true
	_indent.add_theme_constant_override("margin_left", depth * 12)


func _editor_icon(icon_name: String) -> Texture2D:
	if icon_name.is_empty() or not Engine.is_editor_hint():
		return null

	var base := EditorInterface.get_base_control()

	if base == null:
		return null

	return base.get_theme_icon(icon_name, "EditorIcons")
