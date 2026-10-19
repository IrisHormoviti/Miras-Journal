@tool
extends BattleStep
class_name EventStep

enum Mode {
	FLAG_SET,
	FLAG_REMOVE,
	FLAG_PROGRESS,
	TUTORIAL,
	RUN_CUE,
}

@export var mode: Mode = Mode.FLAG_SET:
	set(value):
		mode = value
		notify_property_list_changed()
@export var flag: StringName = &""
@export var value := 1
@export var tutorial: StringName = &""
@export var file: StringName = &""
@export var cue: StringName = &""
@export var wait := true


func run(_ctx: ActionSequenceContext) -> void:
	match mode:
		Mode.FLAG_SET:
			Event.add_flag(flag, value)

		Mode.FLAG_REMOVE:
			Event.remove_flag(flag)

		Mode.FLAG_PROGRESS:
			Event.flag_progress(str(flag), value)

		Mode.TUTORIAL:
			if wait:
				await Event.pop_tutorial(str(tutorial))
			else:
				Event.pop_tutorial(str(tutorial))

		Mode.RUN_CUE:
			if wait:
				await Event.run_cue(str(file), str(cue))
			else:
				Event.run_cue(str(file), str(cue))


func _to_string() -> String:
	match mode:
		Mode.FLAG_SET:
			if str(flag).is_empty():
				return "Set a flag"

			return "Set flag '%s' to %d" % [flag, value]

		Mode.FLAG_REMOVE:
			if str(flag).is_empty():
				return "Remove a flag"

			return "Remove flag '%s'" % flag

		Mode.FLAG_PROGRESS:
			if str(flag).is_empty():
				return "Progress a flag"

			return "Progress flag '%s' to %d" % [flag, value]

		Mode.TUTORIAL:
			return "Show tutorial '%s'" % tutorial

		Mode.RUN_CUE:
			return "Run cue '%s' '%s'" % [file, cue]

	return ""


func _validate_property(property: Dictionary) -> void:
	var visible: Array[String] = ["mode"]

	match mode:
		Mode.FLAG_SET:
			visible.append_array(["flag", "value"])

		Mode.FLAG_REMOVE:
			visible.append("flag")

		Mode.FLAG_PROGRESS:
			visible.append_array(["flag", "value"])

		Mode.TUTORIAL:
			visible.append_array(["tutorial", "wait"])

		Mode.RUN_CUE:
			visible.append_array(["file", "cue", "wait"])

	StepEditor.only(property, visible)


func _icon() -> String:
	return "Script"
