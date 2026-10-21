@tool
extends PanelContainer

const StepCardScene = preload("res://addons/action_sequence_editor/step_card.tscn")
const StepCatalog = preload("res://addons/action_sequence_editor/step_catalog.gd")

const PREVIEW_BATTLE_SCENE := "res://codings/Battle/Battle.tscn"
const PREVIEW_ACTORS := ["Mira", "Alcine", "Asteria", "Daze"]
const PREVIEW_TARGETS := ["Single dummy", "Three dummies"]
const PREVIEW_OUTCOME_BASE := 100

signal steps_changed(property: StringName, steps: Array)

@onready var title_label: Label = %TitleLabel
@onready var count_label: Label = %CountLabel
@onready var add_button: MenuButton = %AddButton
@onready var preview_button: MenuButton = %PreviewButton
@onready var branch_toggle: CheckBox = %BranchToggle
@onready var list: VBoxContainer = %StepList
@onready var guide: ColorRect = %Guide

var object: Object
var property: StringName = &""
var toggle_property: StringName = &""
var known_property: StringName = &""
var title := ""
var cards: Array = []
var signature: Array[int] = [-1]
var object_id := 0
var expanded_id := 0
var selected_index := -1
var reorder_card = null
var reorder_index := -1
var reorder_accum := 0.0
var reorder_changed := false
var preview_actor := "Mira"
var preview_targets := 1


func _ready() -> void:
	add_button.icon = editor_icon("Add")
	add_button.get_popup().id_pressed.connect(on_add_pressed)
	add_button.get_popup().about_to_popup.connect(build_add_menu)
	preview_button.icon = editor_icon("Play")
	preview_button.get_popup().id_pressed.connect(on_preview_pressed)
	preview_button.get_popup().about_to_popup.connect(build_preview_menu)
	branch_toggle.toggled.connect(on_branch_toggled)
	sync_toggle()
	sync_preview()
	apply_title()
	apply_nesting()

	if object != null:
		refresh()


func setup(target: Object, property_name: StringName) -> void:
	object = target
	property = property_name

	if is_node_ready():
		sync_toggle()
		sync_preview()
		refresh()


func set_title(text: String) -> void:
	title = text

	if is_node_ready():
		apply_title()


func refresh() -> void:
	if object == null:
		clear_cards()
		count_label.text = count_text(0)
		return

	var current_id := object.get_instance_id()

	if current_id != object_id or property != known_property:
		object_id = current_id
		known_property = property
		signature = [-1]
		expanded_id = 0
		selected_index = -1

	var steps := typed_steps(get_steps())
	var new_signature: Array[int] = []

	for step in steps:
		new_signature.append(step.get_instance_id())

	if new_signature == signature:
		refresh_cards(steps)
		return

	signature = new_signature
	rebuild(steps)


func clear_cards() -> void:
	for card in cards:
		list.remove_child(card)
		card.queue_free()

	cards.clear()


func get_steps() -> Array:
	if object == null:
		return []

	var value = object.get(property)

	if value is Array:
		return value

	return []


func typed_steps(source: Array) -> Array[BattleStep]:
	var result: Array[BattleStep] = []

	for step in source:
		if step is BattleStep:
			result.append(step)

	return result


func rebuild(steps: Array[BattleStep]) -> void:
	clear_cards()
	count_label.text = count_text(steps.size())

	var expanded_found := false

	for i in steps.size():
		var step := steps[i]
		var card := StepCardScene.instantiate()
		list.add_child(card)
		card.setup(self, step, i)
		cards.append(card)

		if step.get_instance_id() == expanded_id:
			card.set_expanded(true)
			expanded_found = true

	if not expanded_found:
		expanded_id = 0


func refresh_cards(steps: Array[BattleStep]) -> void:
	count_label.text = count_text(steps.size())

	if cards.size() != steps.size():
		rebuild(steps)
		return

	for i in cards.size():
		cards[i].index = i
		cards[i].refresh()


func count_text(count: int) -> String:
	if count == 0:
		return "No steps"

	return "%d step%s" % [count, "" if count == 1 else "s"]


func set_steps(steps: Array[BattleStep]) -> void:
	commit(steps)


func mark_step_changed() -> void:
	commit(get_steps())


func commit(steps: Array) -> void:
	steps_changed.emit(property, steps)
	refresh()


func add_step(path: String) -> void:
	var script := load(path) as Script

	if script == null or not script.can_instantiate():
		return

	var step = script.new()

	if not step is BattleStep:
		return

	var steps := typed_steps(get_steps())
	var index := steps.size()

	if selected_index >= 0 and selected_index < steps.size():
		index = selected_index + 1

	steps.insert(index, step)
	selected_index = index
	expanded_id = step.get_instance_id()
	set_steps(steps)


func reorder_step_drag(card, event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton

		if button.button_index != MOUSE_BUTTON_LEFT:
			return

		if button.pressed:
			reorder_card = card
			reorder_index = card.index
			reorder_accum = 0.0
			reorder_changed = false
		else:
			finish_reorder()

		return

	if event is InputEventMouseMotion and reorder_card != null:
		reorder_accum += (event as InputEventMouseMotion).relative.y
		step_reorder()


func step_reorder() -> void:
	var distance: float = reorder_card.size.y + float(list.get_theme_constant("separation"))

	if distance <= 0.0:
		return

	while absf(reorder_accum) >= distance:
		var direction := 1 if reorder_accum > 0.0 else -1
		var target := reorder_index + direction

		if target < 0 or target >= cards.size():
			reorder_accum = 0.0
			return

		reorder_accum -= distance * direction
		apply_reorder(reorder_index, target)
		reorder_index = target
		reorder_changed = true


func apply_reorder(from: int, to: int) -> void:
	var card = cards[from]
	cards.remove_at(from)
	cards.insert(to, card)
	list.move_child(card, to)
	sync_card_indices()


func sync_card_indices() -> void:
	for i in cards.size():
		cards[i].index = i


func finish_reorder() -> void:
	if reorder_card == null:
		return

	if reorder_changed:
		selected_index = reorder_index
		commit_reorder()

	reorder_card = null
	reorder_index = -1
	reorder_accum = 0.0
	reorder_changed = false


func commit_reorder() -> void:
	var steps: Array[BattleStep] = []

	for card in cards:
		if card.step != null:
			steps.append(card.step)

	var new_signature: Array[int] = []

	for step in steps:
		new_signature.append(step.get_instance_id())

	signature = new_signature
	set_steps(steps)


func duplicate_step(index: int) -> void:
	var steps := typed_steps(get_steps())

	if index < 0 or index >= steps.size():
		return

	var copy = steps[index].duplicate(true)

	if not copy is BattleStep:
		return

	steps.insert(index + 1, copy)

	selected_index = index + 1
	expanded_id = copy.get_instance_id()
	set_steps(steps)


func remove_step(index: int) -> void:
	var steps := typed_steps(get_steps())

	if index < 0 or index >= steps.size():
		return

	var removed_id := steps[index].get_instance_id()
	steps.remove_at(index)

	selected_index = mini(index, steps.size() - 1)

	if expanded_id == removed_id:
		expanded_id = 0

	set_steps(steps)


func toggle_card(card) -> void:
	if card.step == null:
		return

	var step_id: int = card.step.get_instance_id()
	expanded_id = 0 if expanded_id == step_id else step_id
	selected_index = card.index

	for other in cards:
		other.set_expanded(other.step != null and other.step.get_instance_id() == expanded_id)


func build_add_menu() -> void:
	var popup := add_button.get_popup()
	popup.clear(true)
	popup.search_bar_enabled = true

	for entry in StepCatalog.entries():
		var id := popup.get_item_count()
		popup.add_item("%s / %s" % [
			entry["family"],
			StepCatalog.class_label(entry["class"]),
		])
		popup.set_item_metadata(id, entry["path"])

		var icon := editor_icon(str(entry["icon"]))

		if icon != null:
			popup.set_item_icon(id, icon)
			# The menu is where the family colour belongs, the card keeps its
			# icon white against the tinted background.
			popup.set_item_icon_modulate(id, StepCatalog.color_for_path(str(entry["path"])))


func on_add_pressed(id: int) -> void:
	var path := str(add_button.get_popup().get_item_metadata(id))

	if not path.is_empty():
		add_step(path)


func sync_preview() -> void:
	if preview_button == null:
		return

	preview_button.visible = object is ActionSequence
	update_preview_tooltip()


func update_preview_tooltip() -> void:
	if preview_button == null:
		return

	preview_button.tooltip_text = "Preview as %s on %s" % [
		preview_actor,
		PREVIEW_TARGETS[preview_targets - 1],
	]


func build_preview_menu() -> void:
	var popup := preview_button.get_popup()
	popup.clear(true)

	var actor_menu := PopupMenu.new()
	actor_menu.name = "PreviewActorMenu"
	popup.add_child(actor_menu)

	for i in PREVIEW_ACTORS.size():
		actor_menu.add_radio_check_item(PREVIEW_ACTORS[i], i)
		actor_menu.set_item_checked(i, PREVIEW_ACTORS[i] == preview_actor)

	actor_menu.id_pressed.connect(on_preview_actor)
	popup.add_submenu_node_item("Actor", actor_menu)

	var target_menu := PopupMenu.new()
	target_menu.name = "PreviewTargetMenu"
	popup.add_child(target_menu)

	for i in PREVIEW_TARGETS.size():
		target_menu.add_radio_check_item(PREVIEW_TARGETS[i], i)
		target_menu.set_item_checked(i, i + 1 == preview_targets)

	target_menu.id_pressed.connect(on_preview_target)
	popup.add_submenu_node_item("Target", target_menu)

	popup.add_separator()
	popup.add_item("Hit", PREVIEW_OUTCOME_BASE)
	popup.add_item("Crit", PREVIEW_OUTCOME_BASE + 1)
	popup.add_item("Miss", PREVIEW_OUTCOME_BASE + 2)


func on_preview_actor(id: int) -> void:
	if id < 0 or id >= PREVIEW_ACTORS.size():
		return

	preview_actor = PREVIEW_ACTORS[id]
	update_preview_tooltip()


func on_preview_target(id: int) -> void:
	if id < 0 or id >= PREVIEW_TARGETS.size():
		return

	preview_targets = id + 1
	update_preview_tooltip()


func on_preview_pressed(id: int) -> void:
	preview(id - PREVIEW_OUTCOME_BASE)


func preview(outcome: int) -> void:
	if not Engine.is_editor_hint() or not (object is ActionSequence):
		return

	var sequence := object as ActionSequence
	var request := {
		"outcome": outcome,
		"actor": preview_actor,
		"targets": preview_targets,
		"wheel_color": preview_wheel_color(sequence).to_html(),
	}

	if not Battle.write_preview(Battle.preview_shared_dir_static(), typed_steps(get_steps()), request):
		return

	EditorInterface.play_custom_scene(PREVIEW_BATTLE_SCENE)


## The wheel color of the ability that owns the edited sequence, so the preview
## resolves WHEEL_COLOR damage the same way a real cast would. Sequences saved
## inside an ability resource keep its path in `resource_path`
## (`.../SmallShock.tres::Resource_x`).
func preview_wheel_color(sequence: ActionSequence) -> Color:
	var ability := owning_ability(sequence)

	return ability.wheel_color if ability != null else Color.WHITE


## The ability a sequence was saved under, or null when it stands alone.
func owning_ability(sequence: ActionSequence) -> Ability:
	var path := sequence.resource_path.get_slice("::", 0)

	if path.is_empty() or not ResourceLoader.exists(path):
		return null

	var ability := ResourceLoader.load(path)

	return ability as Ability


func apply_title() -> void:
	title_label.text = title
	title_label.visible = not title.is_empty()


func sync_toggle() -> void:
	if branch_toggle == null:
		return

	toggle_property = &""
	var enabled := true

	if object is BattleStep:
		toggle_property = (object as BattleStep)._sequence_toggle(property)

	branch_toggle.visible = not toggle_property.is_empty()

	if branch_toggle.visible:
		enabled = bool(object.get(toggle_property))
		branch_toggle.set_pressed_no_signal(enabled)

	apply_enabled(enabled)


func apply_enabled(enabled: bool) -> void:
	list.visible = enabled
	add_button.visible = enabled
	count_label.visible = enabled


func on_branch_toggled(pressed: bool) -> void:
	if object == null or toggle_property.is_empty():
		return

	object.set(toggle_property, pressed)
	apply_enabled(pressed)
	steps_changed.emit(property, get_steps())


func nesting_depth() -> int:
	var depth := 0
	var node := get_parent()

	while node != null:
		if node.has_method("nesting_depth"):
			depth += 1

		node = node.get_parent()

	return depth


func apply_nesting() -> void:
	var depth := nesting_depth()

	if depth <= 0 or guide == null:
		return

	guide.visible = true


func editor_icon(icon_name: String) -> Texture2D:
	if icon_name.is_empty() or not Engine.is_editor_hint():
		return null

	var base := EditorInterface.get_base_control()

	if base == null:
		return null

	return base.get_theme_icon(icon_name, "EditorIcons")
