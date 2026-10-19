@tool
extends RefCounted

## Card tint per step family, keyed by the folder name the step lives in.
const FAMILY_COLORS: Dictionary[String, Color] = {
	"Actor": Color(0.36, 0.62, 0.94), ## Blue
	"Camera": Color(0.62, 0.47, 0.90), ## Purple
	"Combat": Color(0.90, 0.38, 0.38), ## Red
	"Flow": Color(0.95, 0.68, 0.28), ## Orange
	"Meta": Color(0.55, 0.60, 0.66), ## Grey
	"Presentation": Color(0.33, 0.78, 0.62), ## Teal
	"Scheduling": Color(0.85, 0.55, 0.80), ## Pink
}
## Used for steps outside a known family, such as one added in a new folder.
const DEFAULT_FAMILY_COLOR := Color("#292929")


## The colour for a step family, or the neutral fallback when unknown.
static func family_color(family: String) -> Color:
	return FAMILY_COLORS.get(family, DEFAULT_FAMILY_COLOR)


## The colour for a step script path, derived from its folder.
static func color_for_path(path: String) -> Color:
	return family_color(path.get_base_dir().get_file())


## The card surface colour, a dark version of the family colour so the white
## icon and label text stay readable.
static func card_color(family: String) -> Color:
	return DEFAULT_FAMILY_COLOR.lerp(family_color(family), 0.1)


## The card surface colour used once the card is selected, a brighter version of
## the same family colour.
static func selected_color(family: String) -> Color:
	return DEFAULT_FAMILY_COLOR.lerp(family_color(family), 0.3)


## The icon colour, brighter than the card surfaces so it reads against them.
static func icon_color(family: String) -> Color:
	return family_color(family)


static func card_color_for_path(path: String) -> Color:
	return card_color(path.get_base_dir().get_file())


static func selected_color_for_path(path: String) -> Color:
	return selected_color(path.get_base_dir().get_file())


static func icon_color_for_path(path: String) -> Color:
	return icon_color(path.get_base_dir().get_file())


static func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for entry in ProjectSettings.get_global_class_list():
		if str(entry.get("base", "")) != "BattleStep":
			continue

		var type_name := str(entry.get("class", ""))

		if type_name.is_empty() or type_name == "BattleStep":
			continue

		var path := str(entry.get("path", ""))
		result.append({
			"class": type_name,
			"path": path,
			"family": path.get_base_dir().get_file(),
			"icon": path_icon(path),
		})

	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["family"] == b["family"]:
			return a["class"] < b["class"]

		return a["family"] < b["family"]
	)

	return result


static func sequence_properties(step: BattleStep) -> Array[StringName]:
	var result: Array[StringName] = []

	if step == null:
		return result

	for property in step.get_property_list():
		if int(property.get("type", TYPE_NIL)) != TYPE_ARRAY:
			continue

		var value = step.get(property["name"])

		if value is Array and value.is_typed() and value.get_typed_script() == BattleStep:
			result.append(StringName(property["name"]))

	return result


static func type_label(step: BattleStep) -> String:
	if step == null:
		return "Missing step"

	var script := step.get_script() as Script

	if script == null:
		return class_label(step.get_class())

	var type_name := str(script.get_global_name())

	if type_name.is_empty():
		type_name = script.resource_path.get_file().get_basename()

	return class_label(type_name)


static func class_label(type_name: String) -> String:
	var text := type_name

	if text.ends_with("Step"):
		text = text.trim_suffix("Step")

	if text.is_empty():
		return type_name

	var result := ""

	for i in text.length():
		var character := text[i]
		var is_upper := (
			character == character.to_upper()
			and character != character.to_lower()
		)

		if i > 0 and is_upper:
			var previous := text[i - 1]
			var previous_is_upper := (
				previous == previous.to_upper()
				and previous != previous.to_lower()
			)
			var next_is_lower := false

			if i + 1 < text.length():
				var next := text[i + 1]
				next_is_lower = (
					next == next.to_lower()
					and next != next.to_upper()
				)

			if (not previous_is_upper or next_is_lower) and not result.ends_with(" "):
				result += " "

		result += character

	return result


static func icon_name(step: BattleStep) -> String:
	if step == null:
		return ""

	return step._icon()


static func path_icon(path: String) -> String:
	var script := load(path) as Script

	if script == null or not script.can_instantiate():
		return "Node"

	var instance = script.new()

	if instance is BattleStep:
		return instance._icon()

	return "Node"


static func summary(step: BattleStep) -> String:
	if step == null:
		return ""

	return str(step)
