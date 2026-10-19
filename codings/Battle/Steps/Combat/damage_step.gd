@tool
extends BattleStep
class_name DamageStep

enum MagicMode {
	AUTO,
	PHYSICAL,
	MAGIC,
}

@export var target := ActorRef.new(ActorRef.Mode.TARGET)
@export var power: ValueRef = ValueRef.new()
@export var magic_mode: MagicMode = MagicMode.AUTO
## Whether this hit counts as the caster physically touching the target.
@export var contact := false
@export_group("Extra flags")
@export var effect := true
@export var limiter := false
@export var ignore_stats := false
@export var reroll := false

@export_group("Elemental")
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var elemental := false
@export var color: ColorRef
@export var hit_branch := true
@export var miss_branch := true
@export var crit_branch := false
@export var hit_steps: Array[BattleStep] = []
@export var miss_steps: Array[BattleStep] = []
@export var crit_steps: Array[BattleStep] = []


func _init() -> void:
	hit_steps = [CameraShakeStep.new(), SoundStep.new()]
	miss_steps = [MissStep.new()]


func run(ctx: ActionSequenceContext) -> void:
	var subject := target.resolve(ctx) if target != null else ctx.target

	if subject == null:
		return

	if reroll:
		ctx.runner.roll(ctx, subject)

	if ctx.roll == HitOutcome.MISS:
		if miss_branch:
			await ctx.runner.run_steps(miss_steps, ctx)

		return

	var amount := int(round(power.resolve(ctx))) if power != null else 0
	var is_magic := magic_mode == MagicMode.MAGIC

	if magic_mode == MagicMode.AUTO and power != null:
		is_magic = power.source != ValueRef.Source.DAMAGE or power.damage_scale != ValueRef.DamageScale.WEAPON

	var overwrite_color := color.resolve(ctx) if color != null else Color.WHITE
	ctx.battle.damage(subject, is_magic, elemental, amount, effect, limiter, ignore_stats, overwrite_color)

	if ctx.roll == HitOutcome.CRIT:
		if crit_branch:
			await ctx.runner.run_steps(crit_steps, ctx)
	elif hit_branch:
		await ctx.runner.run_steps(hit_steps, ctx)


func walk() -> Array[BattleStep]:
	var result: Array[BattleStep] = [self]

	for step in hit_steps:
		if step != null:
			result.append_array(step.walk())

	for step in crit_steps:
		if step != null:
			result.append_array(step.walk())

	for step in miss_steps:
		if step != null:
			result.append_array(step.walk())

	return result


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


func _validate_property(property: Dictionary) -> void:
	var visible: Array[String] = [
		"target",
		"power",
		"magic_mode",
		"contact",
		"elemental",
		"effect",
		"limiter",
		"ignore_stats",
		"color",
		"reroll",
	]

	StepEditor.only(property, visible)


func _sequence_toggle(property: StringName) -> StringName:
	match property:
		&"hit_steps":
			return &"hit_branch"

		&"crit_steps":
			return &"crit_branch"

		&"miss_steps":
			return &"miss_branch"

	return &""


func _icon() -> String:
	return "DebugSkipBreakpointsOff"
