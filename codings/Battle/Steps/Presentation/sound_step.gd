@tool
extends BattleStep
class_name SoundStep

enum Mode {
	PLAY,
	STOP,
}

## Sound names used across the sound sets and the loose battle SFX files,
## offered as a dropdown in the inspector.
const SOUND_PRESETS: Array[StringName] = [
	&"",
	&"Ability",
	&"Attack1",
	&"Attack2",
	&"Entrance",
	&"Hit",
	&"Bump",
	&"AxeBlock",
	&"Beep",
	&"BurnWoosh",
	&"Crunch",
	&"GetControl",
	&"Jump",
	&"Punch",
	&"Swing",
	&"WindShort",
	&"heal",
	&"item",
	&"powerup",
	&"powerdown",
	&"confirm",
	&"buzzer",
	&"text",
	&"thonk",
	&"page",
]

@export var mode: Mode = Mode.PLAY:
	set(value):
		mode = value
		notify_property_list_changed()
## Who the sound is played on, used for positioning and for their own sound set.
@export var actor: ActorRef
@export var sound_name: StringName = &"Hit"
## Volume in decibels, where `0` is unaltered.
@export_range(-40, 12, 0.5) var volume := 0.0
## When false, the next step starts while the sound finishes.
@export var wait := false


func run(ctx: ActionSequenceContext) -> void:
	var subject := actor.resolve(ctx) if actor != null else ctx.target

	match mode:
		Mode.PLAY:
			if wait:
				await ctx.battle.play_sound(str(sound_name), subject, volume)
			else:
				ctx.battle.play_sound(str(sound_name), subject, volume)

		Mode.STOP:
			if subject != null:
				ctx.battle.stop_sound(str(sound_name), subject)


func _to_string() -> String:
	var who := str(actor) if actor != null else "Target"

	if mode == Mode.STOP:
		return "Stop sound '%s' on %s" % [sound_name, who]

	return "Play sound '%s' on %s" % [sound_name, who]


func _validate_property(property: Dictionary) -> void:
	var visible: Array[String] = ["mode", "sound_name"]

	if property.name == "sound_name":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(SOUND_PRESETS)

	match mode:
		Mode.PLAY:
			visible.append_array(["actor", "volume", "wait"])

		Mode.STOP:
			visible.append("actor")

	StepEditor.only(property, visible)


func _icon() -> String:
	return "AudioStreamPlayer2D"
