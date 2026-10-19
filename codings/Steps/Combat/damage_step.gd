@tool
extends BattleStep
class_name DamageStep

enum MagicMode {
	AUTO,
	PHYSICAL,
	MAGIC,
}

@export var target: ActorRef
@export var power: ValueRef
@export var magic_mode: MagicMode = MagicMode.AUTO
@export var elemental := false
@export var effect := true
@export var limiter := false
@export var ignore_stats := false
@export var color: ColorRef
@export var reroll := false
@export var show_miss := true


func run(ctx: ActionSequenceContext) -> void:
	var subject := target.resolve(ctx) if target != null else ctx.target

	if subject == null:
		return

	if reroll:
		ctx.runner.roll(ctx, subject)

	if ctx.roll == HitOutcome.MISS:
		if show_miss:
			await ctx.battle.miss()

		return

	var amount := int(round(power.resolve(ctx))) if power != null else Query.calc_num(ctx.ability, ctx.caster)
	var is_magic := magic_mode == MagicMode.MAGIC

	if magic_mode == MagicMode.AUTO and ctx.ability != null:
		is_magic = ctx.ability.Damage != Ability.D.WEAPON

	var overwrite_color := color.resolve(ctx) if color != null else Color.WHITE
	ctx.battle.damage(subject, is_magic, elemental, amount, effect, limiter, ignore_stats, overwrite_color)


func _to_string() -> String:
	var amount := str(power) if power != null else ""
	var who := str(target) if target != null else "Target"
	var magic := ""

	if magic_mode == MagicMode.PHYSICAL:
		magic = "physical "
	elif magic_mode == MagicMode.MAGIC:
		magic = "magic "

	if amount.is_empty():
		return "Deal %sdamage to %s" % [magic, who]

	return "Deal %s %sdamage to %s" % [amount, magic, who]


func _icon() -> String:
	return "DebugSkipBreakpointsOff"
