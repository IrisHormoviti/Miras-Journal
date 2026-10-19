@tool
extends BattleStep
class_name StatStep

enum Mode {
	SET,
	ADD,
	MULTIPLY,
	MIN,
	MAX,
}

enum Stat {
	HEALTH,
	AURA,
	ATTACK,
	MAGIC,
	DEFENCE,
	SPEED,
	ATTACK_MULTIPLIER,
	MAGIC_MULTIPLIER,
	DEFENCE_MULTIPLIER,
	SPEED_BOOST,
}

@export var mode: Mode = Mode.ADD:
	set(value):
		mode = value
		notify_property_list_changed()
@export var stat: Stat = Stat.HEALTH:
	set(value):
		stat = value
		notify_property_list_changed()
@export var actor: ActorRef
@export var value: ValueRef
@export var turns := 3


func run(ctx: ActionSequenceContext) -> void:
	var subject := actor.resolve(ctx) if actor != null else ctx.target
	if subject == null:
		return

	var amount := value.resolve(ctx) if value != null else 0.0

	match stat:
		Stat.HEALTH:
			_apply_number(subject, amount, true)
		Stat.AURA:
			_apply_number(subject, amount, false)
		Stat.ATTACK, Stat.MAGIC, Stat.DEFENCE, Stat.SPEED:
			if mode == Mode.ADD and stat != Stat.SPEED:
				var key := &"Atk"
				if stat == Stat.MAGIC:
					key = &"Mag"
				elif stat == Stat.DEFENCE:
					key = &"Def"
				await ctx.battle.stat_change(key, amount, subject, turns)
			elif stat == Stat.SPEED:
				subject.SpeedBoost = int(round(_number(float(subject.SpeedBoost), amount)))
			else:
				_set_base_stat(subject, amount)
		Stat.ATTACK_MULTIPLIER:
			subject.AttackMultiplier = _number(subject.AttackMultiplier, amount)
		Stat.MAGIC_MULTIPLIER:
			subject.MagicMultiplier = _number(subject.MagicMultiplier, amount)
		Stat.DEFENCE_MULTIPLIER:
			subject.DefenceMultiplier = _number(subject.DefenceMultiplier, amount)
		Stat.SPEED_BOOST:
			subject.SpeedBoost = int(round(_number(float(subject.SpeedBoost), amount)))


func _apply_number(subject: Actor, amount: float, health: bool) -> void:
	var current := float(subject.Health) if health else float(subject.Aura)
	var result := int(round(_number(current, amount)))

	if health:
		subject.set_health(result)
	else:
		subject.set_aura(result)


func _number(current: float, amount: float) -> float:
	match mode:
		Mode.SET:
			return amount
		Mode.ADD:
			return current + amount
		Mode.MULTIPLY:
			return current * amount
		Mode.MIN:
			return minf(current, amount)
		Mode.MAX:
			return maxf(current, amount)

	return current


func _set_base_stat(subject: Actor, amount: float) -> void:
	match stat:
		Stat.ATTACK:
			subject.Attack = int(round(_number(float(subject.Attack), amount)))
		Stat.MAGIC:
			subject.Magic = int(round(_number(float(subject.Magic), amount)))
		Stat.DEFENCE:
			subject.Defence = int(round(_number(float(subject.Defence), amount)))


func _to_string() -> String:
	var value_text := str(value) if value != null else ""
	var who := str(actor) if actor != null else "Target"

	return "%s %s %s to %s" % [
		str(Mode.find_key(mode)).capitalize(),
		value_text,
		str(Stat.find_key(stat)).to_lower().replace("_", " "),
		who,
	]


func _validate_property(property: Dictionary) -> void:
	var visible: Array[String] = ["mode", "stat", "actor", "value"]
	if mode == Mode.ADD and stat in [Stat.ATTACK, Stat.MAGIC, Stat.DEFENCE]:
		visible.append("turns")
	StepEditor.only(property, visible)


func _icon() -> String:
	return "HSlider"
