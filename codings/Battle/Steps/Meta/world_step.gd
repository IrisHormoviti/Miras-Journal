@tool
extends BattleStep
class_name WorldStep

const TIME_LABELS := ["dark hour", "morning", "daytime", "afternoon", "evening", "night"]

enum Mode {
	PARTY_SET,
	PARTY_HEAL,
	PLAYER_POSITION,
	PLAYER_VISIBLE,
	CAMERA_ENABLED,
	DAY,
	TIME,
	TIME_TRANSITION,
}

@export var mode: Mode = Mode.PARTY_HEAL:
	set(value):
		mode = value
		notify_property_list_changed()
@export var party: PackedStringArray = []
@export var position := Vector2.ZERO
@export var visible := true
@export var enabled := true
@export var day := 1
@export var time: Event.TOD = Event.TOD.MORNING


func run(_ctx: ActionSequenceContext) -> void:
	match mode:
		Mode.PARTY_SET:
			Party.set_to(party)
		Mode.PARTY_HEAL:
			Party.heal_party()
		Mode.PLAYER_POSITION:
			Global.player.position = position
		Mode.PLAYER_VISIBLE:
			Global.player.visible = visible
		Mode.CAMERA_ENABLED:
			Global.camera.enabled = enabled
		Mode.DAY:
			Event.to_day = day
		Mode.TIME:
			Event.to_time = time
		Mode.TIME_TRANSITION:
			await Event.time_transition()


func _to_string() -> String:
	match mode:
		Mode.PARTY_SET:
			return "Set the party to %s" % ", ".join(party)

		Mode.PARTY_HEAL:
			return "Heal the party"

		Mode.PLAYER_POSITION:
			return "Move the player"

		Mode.PLAYER_VISIBLE:
			return "Player %s" % ("visible" if visible else "hidden")

		Mode.CAMERA_ENABLED:
			return "Camera %s" % ("enabled" if enabled else "disabled")

		Mode.DAY:
			return "Set the day to %d" % day

		Mode.TIME:
			return "Set the time to %s" % _time_label(time)

		Mode.TIME_TRANSITION:
			return "Transition the time of day"

	return ""


func _time_label(value: int) -> String:
	if value < 0 or value >= TIME_LABELS.size():
		return str(value)

	return TIME_LABELS[value]


func _validate_property(property: Dictionary) -> void:
	var fields: Array[String] = ["mode"]
	match mode:
		Mode.PARTY_SET:
			fields.append("party")
		Mode.PARTY_HEAL, Mode.TIME_TRANSITION:
			pass
		Mode.PLAYER_POSITION:
			fields.append("position")
		Mode.PLAYER_VISIBLE:
			fields.append("visible")
		Mode.CAMERA_ENABLED:
			fields.append("enabled")
		Mode.DAY:
			fields.append("day")
		Mode.TIME:
			fields.append("time")
	StepEditor.only(property, fields)


func _icon() -> String:
	return "WorldEnvironment"
