@tool
extends BattleStep
class_name BattleMessageStep

## Shows a battle message from the BattleText table.

@export var message: String = ""
@export var insert: ActorRef
@export var insert2: ActorRef
## Use the last state touched by a previous step as the message's first insert.
@export var insert_state := false


func run(ctx: ActionSequenceContext) -> void:
	var first := ""
	var second := ""

	if insert_state and ctx.last_state != null:
		first = ctx.last_state.name

	if insert != null:
		var first_actor := insert.resolve(ctx)

		if first_actor != null:
			first = first_actor.first_name

	if insert2 != null:
		var second_actor := insert2.resolve(ctx)

		if second_actor != null:
			second = second_actor.first_name

	ctx.battle.battle_msg(message, first, second)


func _to_string() -> String:
	return "Message \"%s\"" % message


func _validate_property(property: Dictionary) -> void:
	StepEditor.only(property, ["message", "insert", "insert2", "insert_state"])


func _icon() -> String:
	return "GPUParticles2D"
