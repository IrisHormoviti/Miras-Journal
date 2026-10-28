@tool
extends Resource
class_name ValueRef

## Base damage scale, used to derive a number without an ability parameter.
enum DamageScale {
	WEAK, ## 12
	MEDIUM, ## 24
	HEAVY, ## 48
	SEVERE, ## 96
	WEAPON, ## The caster's weapon power
	CUSTOM, ## The ability or item parameter
}

## Where the base number comes from.
enum Source {
	FIXED, ## The value below
	DAMAGE, ## A damage scale
	STAT, ## A stat from a subject
	RANDOM, ## A random number between the two bounds
}

## The stat read when the source is STAT.
enum Stat {
	MAX_HP,
	CURRENT_HP,
	MISSING_HP,
	MAX_HP_PERCENT,
	CURRENT_HP_PERCENT,
	MISSING_HP_PERCENT,
	MAX_AURA,
	CURRENT_AURA,
	MAX_AURA_PERCENT,
	CURRENT_AURA_PERCENT,
	STATE_COUNT,
	DAMAGE_TAKEN,
}

@export var source: Source = Source.DAMAGE:
	set(value):
		source = value
		notify_property_list_changed()
		refresh_name()
## Fixed number, or a percentage when the stat is a percent.
@export var value: float = 0.0:
	set(val):
		value = val
		refresh_name()
## Damage scale used when the source is DAMAGE.
@export var damage_scale: DamageScale = DamageScale.WEAPON:
	set(value):
		damage_scale = value
		refresh_name()
## Stat read when the source is STAT.
@export var stat: Stat = Stat.MAX_HP:
	set(value):
		stat = value
		notify_property_list_changed()
		refresh_name()
@export var actor: ActorRef
## Applied to the resolved value, so `0.5` represents half damage.
@export var multiplier: float = 1.0:
	set(val):
		multiplier = val
		refresh_name()
## Added after the multiplier.
@export var add: float = 0.0:
	set(val):
		add = val
		refresh_name()
## Randomise the result between the two multipliers below.
@export var variance := false:
	set(val):
		variance = val
		notify_property_list_changed()
@export var variance_min := 0.8
@export var variance_max := 1.2
@export var random_min: float = 0.0
@export var random_max: float = 1.0


func _init() -> void:
	refresh_name()


func resolve(ctx: ActionSequenceContext) -> float:
	var result := value

	match source:
		Source.FIXED:
			pass

		Source.DAMAGE:
			result = damage_base(ctx)

		Source.STAT:
			result = stat_value(ctx)

		Source.RANDOM:
			result = randf_range(random_min, random_max)

	result = result * multiplier + add

	if variance:
		result *= randf_range(variance_min, variance_max)

	return result


## The raw damage number for this scale, before the multiplier and add.
func damage_base(ctx: ActionSequenceContext) -> float:
	var caster := ctx.caster if ctx != null else null
	return damage_for(damage_scale, caster, parameter_value(ctx))


## Resolves a damage scale without needing a step context. Legacy abilities call
## this through Query.calc_num until their sequences own the scale.
static func damage_for(scale: DamageScale, caster: Actor, parameter: float = 0.0) -> float:
	match scale:
		DamageScale.WEAK:
			return 12.0

		DamageScale.MEDIUM:
			return 24.0

		DamageScale.HEAVY:
			return 48.0

		DamageScale.SEVERE:
			return 96.0

		DamageScale.WEAPON:
			return weapon_power_of(caster)

		DamageScale.CUSTOM:
			return parameter

	return 0.0


static func weapon_power_of(caster: Actor) -> float:
	if caster == null and is_instance_valid(Global.bt) and Global.bt.CurrentChar != null:
		caster = Global.bt.CurrentChar

	if caster != null and caster.weapon != null:
		return float(caster.weapon.power)

	return 0.0


func parameter_value(ctx: ActionSequenceContext) -> float:
	if ctx == null:
		return 0.0

	if ctx.item != null:
		return float(ctx.item.Parameter)

	if ctx.ability != null:
		return float(ctx.ability.Parameter)

	return 0.0


func stat_value(ctx: ActionSequenceContext) -> float:
	var subject := ctx.target if ctx != null else null

	if actor != null:
		subject = actor.resolve(ctx)

	if subject == null:
		return 0.0

	match stat:
		Stat.MAX_HP:
			return float(subject.max_hp)

		Stat.CURRENT_HP:
			return float(subject.health)

		Stat.MISSING_HP:
			return float(subject.max_hp - subject.health)

		Stat.MAX_HP_PERCENT:
			return float(subject.max_hp) * value / 100.0

		Stat.CURRENT_HP_PERCENT:
			return float(subject.health) * value / 100.0

		Stat.MISSING_HP_PERCENT:
			return float(subject.max_hp - subject.health) * value / 100.0

		Stat.MAX_AURA:
			return float(subject.max_aura)

		Stat.CURRENT_AURA:
			return float(subject.aura)

		Stat.MAX_AURA_PERCENT:
			return float(subject.max_aura) * value / 100.0

		Stat.CURRENT_AURA_PERCENT:
			return float(subject.aura) * value / 100.0

		Stat.STATE_COUNT:
			return float(subject.states.size())

		Stat.DAMAGE_TAKEN:
			return float(subject.damage_received_this_turn)

	return 0.0


func refresh_name() -> void:
	resource_name = str(self)


func _to_string() -> String:
	var label := ""

	match source:
		Source.FIXED:
			label = str(value)

		Source.DAMAGE:
			label = str(DamageScale.find_key(damage_scale)).to_lower()

			if damage_scale == DamageScale.CUSTOM:
				label = "ability power"

		Source.STAT:
			label = str(Stat.find_key(stat)).replace("_", " ").to_lower()

			if stat in [Stat.MAX_HP_PERCENT, Stat.CURRENT_HP_PERCENT, Stat.MISSING_HP_PERCENT, Stat.MAX_AURA_PERCENT, Stat.CURRENT_AURA_PERCENT]:
				label += " (%s%%)" % str(value)

		Source.RANDOM:
			label = "%s to %s" % [str(random_min), str(random_max)]

	if not is_equal_approx(multiplier, 1.0):
		label += " x%s" % str(multiplier)

	if not is_zero_approx(add):
		label += " +%s" % str(add)

	if variance:
		label += " (%sx to %sx)" % [str(variance_min), str(variance_max)]

	return label.strip_edges()


func _validate_property(property: Dictionary) -> void:
	var visible: Array[String] = ["source", "multiplier", "add", "variance"]

	if variance:
		visible.append_array(["variance_min", "variance_max"])

	match source:
		Source.FIXED:
			visible.append("value")

		Source.DAMAGE:
			visible.append("damage_scale")

		Source.STAT:
			visible.append_array(["stat", "actor"])

			if stat in [Stat.MAX_HP_PERCENT, Stat.CURRENT_HP_PERCENT, Stat.MISSING_HP_PERCENT, Stat.MAX_AURA_PERCENT, Stat.CURRENT_AURA_PERCENT]:
				visible.append("value")

		Source.RANDOM:
			visible.append_array(["random_min", "random_max"])

	StepEditor.only(property, visible)


func _icon() -> String:
	return "Curve"
