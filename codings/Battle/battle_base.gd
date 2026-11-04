extends Node2D
class_name Battle

## Is the player currently in a battle?
static var in_battle: bool:
	get(): return is_instance_valid(current)
## The current battle instance
static var current: Battle
## Battle sequence of the current battle
static var sequence: BattleSequence
static var prevent_battles: bool = false
static var remembered_camera_zoom: Vector2
static var battle_advantage := 0
static var attacker: Node2D = null
## Set by the headless battle harness so the standalone preview keeps the live
## battle instead of quitting after the first previewed action.
static var headless_driver := false
## Dialogue that was already open before the battle started. Cutscenes can call
## Battle.start() from inside a textbox, which then stays open (usually hidden)
## for the whole fight. It belongs to the story, not the battle, so it must not
## make the battle UI think a battle dialog is blocking the screen.
static var external_textbox_id := 0
static var external_passive_id := 0
## How many turn-holding battle dialogues are currently blocking the menu.
## Passives that do not hold the turn (e.g. flavor warnings) are not counted.
static var modal_dialogue_count := 0

enum Result {UNFINISHED, VICTORY, ESCAPE, DEFEAT}
static var battle_result: Result = Result.UNFINISHED

## Used for battle messages
@export var BattleText: Dictionary[String, String]
## Array of the enemies of this battle.
## Enemies can be added or removed throughout
var Troop: Array[Actor]
## All actors in this battle, ordered by their speed
var TurnOrder: Array[Actor]
## The current turn
var Turn: int = 0
## Index of the current actor in the turn order
var TurnInd: int = -1
## The character whoose turn it is
var CurrentChar: Actor
## Currently targeted actor
var CurrentTarget: Actor
## The ability currently being used
var CurrentAbility: Ability
## If the player is currently selecting something (false)
## Or they're watching things happen (true)
var Action: bool
## True after the victory screen is shown,
## and is waiting for the player to continue
var AwaitVictory := false
## Used for the SP counting in the victory screen
var count_sp: int
## SP that will be earned after winning
var totalSP: int = 0
## Items to be earned after winning
var ObtainedItems: Array[ItemData] = []
## The position of the CurrentChar at the start of this turn
var initial: Vector2
## Is the callout text on screen
var callout_onscreen := false
## The turn will not end when requested, but will once this is false
var lock_turn := false
## How many flows are holding the turn, lock_turn is true while above 0
var lock_count := 0
## Upcoming turns that should be held as soon as they begin. Scripted dialogue
## uses this to talk over a turn without racing the action's end_turn().
var pending_turn_holds := 0
## Prevent critical hits
var no_crits := false
## Prevent missing
var no_misses := false
## A sprung trap interrupted the current action, so it can't deal more damage.
var interrupted := false
## The next turn a followup will be preformed
var follow_up_next := false
## True while the current actor is taking the extra move from an Aura Break.
## A follow-up is a single action, even for actors with a multi-move turn.
var follow_up_turn := false
## True while a sprung trap is being preformed, so traps can't chain forever
var in_trap := false
## Traps that sprung from the current hit, waiting to counterattack
## (resolved by end_turn, once the attacking sequence is over)
var pending_traps: Array[Dictionary] = []
## Victory animations still clearing states before end_battle() can reset them.
var victory_anim_pending := 0
## Optional story phase used by PhaseCondition.
var battle_phase: StringName = &""
## Runtime owner for data-driven action sequences.
var action_runner: ActionSequenceRunner
## Saved acting context used by use_ability_now.
var acting_stack: Array[Dictionary] = []
## Actors whose next turn should be skipped by skip_next_turn.
var skipped_turns: Array[Actor] = []
## True while the inspector preview is driving a standalone battle.
var previewing := false
## True from the authored opening through the transition into the first turn.
## An entrance sequence's END_TURN step must not start the first turn while
## this is set, or it races the opening and cuts it short.
var entrance_in_progress := false

@onready var ui: Control = %ControllerBattleUI
@onready var canvas: CanvasLayer = $Canvas
@onready var enemy_ui: CanvasLayer = $EnemyUI
@onready var act: Node2D = $Act
@onready var cam: Camera2D = $Act/Cam
@onready var effects: AnimatedSprite2D = $Act/Effects
@onready var background: Sprite2D = $Act/Background

signal battle_start
signal GetControl
signal next_turn
signal check_party
signal anim_done
signal take_dmg
## Emitted once the previewed action's turn is over, so the preview can close.
signal preview_finished


##Starts the specified battle. Advantage: 0 for Neutual, 1 for Player, 2 for enemy
static func start(stg: Variant, advantage := 0) -> void:
	if in_battle:
		return

	if stg is String:
		sequence = await Loader.load_res("res://database/BattleSeq/" + stg + ".tres")
	elif stg is BattleSequence:
		sequence = stg
	else:
		UI.toast("The battle sequence isn't set here, you probably should fix this.")
		await Event.wait(0.3)
		Event.give_control()
		Hud.show_all()
		return

	if prevent_battles:
		return

	# Remember a cutscene textbox/passive that is already open. It stays open
	# (and is often hidden with [hide]) while the battle runs, so it must not be
	# treated as modal battle dialogue.
	external_textbox_id = (
		Textbox.current.get_instance_id() if is_instance_valid(Textbox.current) else 0
	)
	external_passive_id = (
		Passive.current.get_instance_id() if is_instance_valid(Passive.current) else 0
	)
	modal_dialogue_count = 0

	battle_result = Result.UNFINISHED
	battle_advantage = advantage
	Hud.ui_visible = false
	#Engine.time_scale = 0.1
	Hud.hide_all()
	Global.controllable = false
	print_rich("[color=green]Battle start!\nAdvantage: %d"%[advantage])
	Global.get_tree().paused = true

	if is_instance_valid(Global.camera):
		remembered_camera_zoom = Global.camera.zoom

	if sequence.transition:
		if is_instance_valid(attacker):
			if sequence.Music:
				Audio.change_music_from_to(sequence.Music.track, 0, sequence.Music.intro_end)

			Loader.battle_bars(2, 0.8, Tween.EASE_OUT)

			if is_instance_valid(Global.camera):
				tween(Global.camera, "zoom", Vector2(6, 6), 1, Tween.EASE_OUT, Tween.TRANS_CUBIC)

			#if advantage == 1: t.tween_property(Camera, "global_position", Attacker.global_position, 0.4)
			await Event.wait(0.8, false)

		if is_instance_valid(Global.camera):
			tween(Global.camera, "zoom", Vector2(8, 8), 0.5, Tween.EASE_IN, Tween.TRANS_CUBIC)

		await Loader.battle_bars(4, 0.5, Tween.EASE_IN)

	#Engine.time_scale = 1
	var battle: Node = (await Loader.load_res("uid://chjrhe4gw1iu6")).instantiate()

	if is_instance_valid(Global.player):
		Global.player.hide()
		if not sequence.UseBackground:
			Global.player.position = sequence.ScenePosition
		elif sequence.ScenePosition == Vector2.ZERO and is_instance_valid(Global.room):
			sequence.ScenePosition = Global.room.battleback_position

		Global.player.get_node("DirectionMarker/Finder/Shape").set_deferred("disabled", true)
		Global.player.camera_follow(false)

	if not sequence.PartyOverride.is_empty():
		Party.set_to(sequence.PartyOverride)

	if is_instance_valid(Global.camera):
		Global.camera.position_smoothing_enabled = false

	Global.get_tree().root.add_child(battle)
	if is_instance_valid(attacker):
		attacker.hide()

	if is_instance_valid(Global.room):
		for i in Global.room.followers:
			if is_instance_valid(i) and is_instance_valid(Global.player):
				i.hide()
				i.global_position = Global.player.position


func _exit_tree() -> void:
	if is_instance_valid(act):
		act.free()

## The sequence the standalone preview copies. Shared with the headless battle
## harness so previewing and testing run through the same setup.
const PREVIEW_SEQUENCE_PATH := "res://codings/Battle/BattlePreviewSequence.tres"
const PREVIEW_DUMMY_PATH := "res://database/Enemies/Dummy.tres"
const PREVIEW_PARTY := ["Mira", "Alcine", "Asteria", "Daze"]
## Files the inspector preview and the headless harness share.
const PREVIEW_SEQUENCE_FILE := "battle_preview_sequence.tres"
const PREVIEW_REQUEST_FILE := "battle_preview_request.json"


## Prepares the sequence and party when the battle scene is launched on its own
## by the inspector preview, before _ready consumes the sequence.
func setup_standalone_preview() -> void:
	var request := read_preview_request()

	if request.is_empty():
		return

	Party.set_to(PackedStringArray(PREVIEW_PARTY))

	sequence = build_preview_sequence(int(request.get("targets", 1)), str(request.get("enemy", "")))

	battle_advantage = 0
	attacker = null


## Builds the standalone preview sequence with `targets` dummy enemies, or with
## a single enemy caster when `enemy_path` is set.
static func build_preview_sequence(targets: int, enemy_path := "") -> BattleSequence:
	var template := load(PREVIEW_SEQUENCE_PATH) as BattleSequence

	if template == null:
		return null

	var preview := template.duplicate() as BattleSequence
	preview.transition = true
	# The preview is about the action, not the opening, so skip the entrance.
	preview.skip_entrance = true
	preview.Enemies = []

	if not enemy_path.is_empty():
		var enemy := load(enemy_path) as Actor

		if enemy != null:
			preview.Enemies.append(enemy)
			return preview

		push_warning("Could not load the preview enemy: " + enemy_path)

	var dummy := load(PREVIEW_DUMMY_PATH) as Actor

	for i in maxi(1, targets):
		preview.Enemies.append(dummy)

	return preview


func _ready() -> void:
	if sequence == null and not Engine.is_editor_hint():
		setup_standalone_preview()

	modal_dialogue_count = 0

	# Re-parent Act node
	act.reparent(get_node(Loader.area_spawn_path))
	act.global_position = sequence.ScenePosition
	act.z_index = (Global.room.camera_index.z if is_instance_valid(Global.room) and Global.room.camera_index else 3)
	cam.make_current()

	# A battle without a wipe is visible the moment it is added to the tree.
	# Creating the actors takes several frames, and each one starts out at
	# Actor0's editor position before it gets a battle slot, so the party and
	# enemies would be seen piled up and then snapping into place. Keep the
	# scene hidden until they are all positioned.
	var defer_reveal := not sequence.transition

	if defer_reveal:
		act.hide()

	action_runner = ActionSequenceRunner.new()
	action_runner.name = "ActionSequenceRunner"
	action_runner.battle = self
	act.add_child(action_runner)

	battle_start.emit()
	current = self
	get_tree().paused = false
	Global.controllable = false
	cam.make_current()
	Action = true
	TurnInd = -1
	Turn = 0

	if Party.Leader == null:
		end_battle()
		return

	CurrentChar = Party.Leader
	CurrentAbility = Party.Leader.standard_attack

	if sequence == null:
		sequence = load("res://database/BattleSeq/DebugDummy.tres")

	sequence.reset_events(true)

	for i in sequence.Enemies:
		Troop.append(i.duplicate())

	Party.Leader.node = act.get_node("Actor0")
	TurnOrder.push_front(Party.Leader)
	TurnOrder.append_array(Troop)
	background.texture = sequence.BattleBack

	if sequence.BattleBack == null:
		act.get_node("Actor0").light_mask = 1

	if sequence.PositionSameAsPlayer and is_instance_valid(Global.player):
		sequence.ScenePosition = Global.player.global_position + Vector2(45, 0)

	if Global.camera != null:
		cam.global_position = Global.camera.global_position
		cam.zoom = Global.camera.zoom

	$Canvas/Cutin.hide()
	act.get_node("Actor0").sprite_frames = await Party.Leader.get_BT()
	act.get_node("Actor0").animation = &"Entrance"
	act.get_node("Actor0").frame = 0
	act.get_node("Actor0/Shadow").modulate = Color.WHITE
	$Canvas/VictoryText.modulate = Color.TRANSPARENT
	$Canvas/SPGain.hide()
	$Canvas/VictoryItems.hide()
	if Global.room: Global.room.show()
	for i in range(1, 4):
		if Party.has_member_index(i):
			var member := Party.current[i]
			await create_actor_node(member, "Actor" + str(i))
			TurnOrder.push_front(member)

	for i in Party.current:
		if not i: continue
		match Party.current.find(i):
			0: i.speed = 8
			1: i.speed = 6
			2: i.speed = 4
			3: i.speed = 2

	for i in Troop.size():
		var dub := await create_actor_node(Troop[i], "Enemy" + str(i))
		dub.offset = Troop[i].offset
		dub.play("Idle")
		Troop[i].health = Troop[i].max_hp
		Troop[i].aura = Troop[i].max_aura

	if battle_advantage == 1:
		for i in TurnOrder:
			if not i.is_enemy: i.speed_boost += 5
	elif battle_advantage == 2:

		for i in TurnOrder:
			if i.is_enemy: i.speed_boost += 10

	act.get_node("Actor0").add_child(Party.Leader.sound_set.instantiate())
	for i in TurnOrder:
		sprite_init(i)
		i.next_action = Actor.BtAction.UNSET
		i.battle_log = [Actor.log_entry.new()]
		i.turns_taken = 0
		i.load_complimentaries()

	if sequence.Music:
		Audio.change_music_from_to(sequence.Music.track, sequence.Music.battle_start)

	position_sprites()
	if defer_reveal:
		act.show()

	if is_instance_valid(attacker): attacker.hide()
	entrance_in_progress = true

	if not sequence.skip_entrance:
		if sequence.entrance_sequence != null: await run_battle_sequence(sequence.entrance_sequence, null, null, false)

	TurnOrder.sort_custom(speed_sort)
	turn_ui_init()
	for i in TurnOrder:
		print(i.speed + i.speed_boost, " - ", i.first_name)

	# Prepare the standalone battle before the entrance starts the turn loop, so
	# the preview can run its action as a forced move instead of asking for
	# input. The headless harness boots the same battle but drives it itself.
	var standalone := not is_instance_valid(Global.room)

	if standalone:
		previewing = headless_driver or prepare_standalone_preview()

	await entrance()

	if previewing and not headless_driver:
		await preview_finished
		get_tree().quit()


## When a battle runs without a room it was started by the inspector preview.
## It queues a single saved sequence for the caster as a forced move. Returns
## false when there is nothing to preview.
func prepare_standalone_preview() -> bool:
	var request := read_preview_request()

	if request.is_empty():
		return false

	var sequence_path := preview_shared_dir().path_join(PREVIEW_SEQUENCE_FILE)
	var preview: ActionSequence = null

	if FileAccess.file_exists(sequence_path):
		var loaded := ResourceLoader.load(sequence_path)

		if loaded is ActionSequence:
			preview = loaded as ActionSequence

	if preview == null or preview.steps.is_empty():
		push_error("Battle preview found no sequence to run")
		get_tree().quit(1)
		return false

	var caster: Actor = null
	var target: Actor = null

	if not str(request.get("enemy", "")).is_empty():
		# Enemy previews put the chosen enemy in the troop and the party on the
		# receiving end, so side-aware positions and target refs behave like the
		# real fight.
		caster = Troop[0] if not Troop.is_empty() else null
		target = Party.Leader
	else:
		caster = Party.get_member(StringName(request.get("actor", "Mira")))

		if caster == null:
			caster = Party.Leader

		target = Troop[0] if not Troop.is_empty() else null

	if caster == null or target == null:
		push_error("Battle preview is missing a caster or target")
		get_tree().quit(1)
		return false

	var aoe := int(request.get("targets", 1)) >= 3
	var ability := preview_ability(preview, aoe, wheel_color_from_request(request))
	apply_preview_outcome(ability, int(request.get("outcome", 0)))
	previewing = true
	force_next_actor(caster)
	queue_action(caster, ability, target, Actor.BtAction.MAGIC)
	return true


## Reads the preview request the inspector writes next to the game's user dir.
func read_preview_request() -> Dictionary:
	return read_preview_request_at(preview_shared_dir())


## Reads a preview request from `dir`.
static func read_preview_request_at(dir: String) -> Dictionary:
	var path := dir.path_join(Battle.PREVIEW_REQUEST_FILE)

	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)

	if file == null:
		return {}

	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)

	if parsed is Dictionary:
		return parsed

	return {}


## Writes the sequence and request the standalone battle reads back. Shared by
## the inspector preview and the headless battle harness.
static func write_preview(dir: String, steps: Array[BattleStep], request: Dictionary) -> bool:
	var preview_sequence := ActionSequence.new()

	for step in steps:
		preview_sequence.steps.append(step)

	if ResourceSaver.save(preview_sequence, dir.path_join(PREVIEW_SEQUENCE_FILE)) != OK:
		push_error("Could not save the battle preview sequence")
		return false

	var file := FileAccess.open(dir.path_join(PREVIEW_REQUEST_FILE), FileAccess.WRITE)

	if file == null:
		push_error("Could not write the battle preview request")
		return false

	file.store_string(JSON.stringify(request))
	file.close()
	return true


## SteamManager repoints user:// to a per-account subfolder at startup, and the
## editor writes one level above it. Step back while the folder is an id.
func preview_shared_dir() -> String:
	return preview_shared_dir_static()


static func preview_shared_dir_static() -> String:
	var user_dir := ProjectSettings.globalize_path("user://").simplify_path()

	if user_dir.get_file().is_valid_int():
		return user_dir.path_join("..").simplify_path()

	return user_dir


func preview_ability(preview: ActionSequence, aoe: bool, wheel_color := Color.WHITE) -> Ability:
	var ability := Ability.nothing().duplicate() as Ability
	ability.name = "Battle Preview"
	ability.success_chance = 1
	ability.crit_chance = 0
	# The standalone battle has no real ability, so a DamageStep's WHEEL_COLOR
	# ref would fall back to white. Carry the ability being previewed instead,
	# and stop the run from overwriting it with the caster's color: it is
	# copied from Ability.nothing(), which opts into exactly that.
	ability.wheel_color = wheel_color
	ability.color_same_as_actor = false

	if aoe:
		ability.target = Ability.T.AOE_ENEMIES
	else:
		ability.target = Ability.T.ONE_ENEMY

	ability.action_sequence = preview
	return ability


## The wheel color the inspector preview asked for, or white when it did not
## send one (e.g. a sequence with no owning ability). The request travels as
## JSON, so the color arrives as an html string.
func wheel_color_from_request(request: Dictionary) -> Color:
	var value: Variant = request.get("wheel_color")

	if value is Color:
		return value

	if value is String and not value.is_empty():
		return Color.html(value)

	return Color.WHITE


func apply_preview_outcome(ability: Ability, outcome: int) -> void:
	# Hit is 0, crit is 1, miss is 2 (see the inspector preview menu).
	no_misses = true
	no_crits = true

	match outcome:
		1:
			no_crits = false
			ability.crit_chance = 1

		2:
			no_misses = false
			ability.success_chance = 0


static func tween(
	object: Node,
	property: String,
	to: Variant,
	time := 0.3,
	ease_type := Tween.EASE_OUT,
	trans := Tween.TRANS_CUBIC
) -> void:
	var t := Global.create_tween()
	t.set_ease(ease_type)
	t.set_trans(trans)
	t.tween_property(object, NodePath(property), to, time)
	await t.finished


## Duplicates the base battle sprite (Actor0) for an actor, parents it under
## `node_name` in the Act node, and gives it the actor's battle sprites and
## sound set.
func create_actor_node(actor: Actor, node_name: String) -> AnimatedSprite2D:
	var sprite: AnimatedSprite2D = act.get_node("Actor0").duplicate()
	sprite.name = node_name

	# A duplicate also copies Actor0's runtime state visuals and shader outline.
	# Strip them so a joining actor does not inherit another actor's Guarding
	# outline (or any other state overlay).
	for child in sprite.get_children():
		if child is AnimatedSprite2D and child.name != "State":
			child.free()

	var shadow := sprite.get_node_or_null("Shadow")

	if shadow != null:
		shadow.modulate = Color.WHITE

	var particle := sprite.get_node_or_null("Particle")

	if particle != null:
		particle.emitting = false

	var nums := sprite.get_node_or_null("Nums")

	if nums != null:
		nums.visible = false

	act.add_child(sprite)
	actor.node = sprite
	sprite.sprite_frames = await actor.get_BT()
	sprite.material = sprite.material.duplicate()

	if sprite.material is ShaderMaterial:
		sprite.material.set_shader_parameter("outline_enabled", false)
		sprite.material.set_shader_parameter("outline_color", Color.TRANSPARENT)

	# A duplicate made after Actor0 got its own sound set carries a stale "SFX"
	# child. Remove it so the actor's sound set can take its place.
	if sprite.has_node("SFX"):
		sprite.get_node("SFX").queue_free()
		await Event.wait()

	if actor.sound_set:
		sprite.add_child(actor.sound_set.instantiate())

	return sprite


func sprite_init(i: Actor) -> void:
	i.node.sprite_frames = await i.get_BT()
	i.node.flip_h = i.flip_h
	i.node.get_node("State").play("None")
	if not i.shadow:
		i.node.get_child(0).hide()

	if i.is_enemy: i.node.get_node("Glow").energy = i.glow_def
	else:
		var t := create_tween()
		t.tween_property(i.node.get_node("Glow"), "energy", i.glow_def, 1)

	i.node.get_node("Glow").color = i.main_color

	if i.material_override != null:
		i.node.material = i.material_override


func speed_sort(a: Actor, b: Actor) -> bool:
	var a_speed := a.speed + a.speed_boost
	var b_speed := b.speed + b.speed_boost

	if a_speed == b_speed:
		# Ties are broken in favour of party members.
		return not a.is_enemy

	return a_speed > b_speed


func turn_ui_init() -> void:
	var entr: Control = $Canvas/TurnOrderPop/Margin/List.get_child(0).duplicate()

	for i in $Canvas/TurnOrderPop/Margin/List.get_children(): i.queue_free()
	for i in TurnOrder:
		entr = entr.duplicate()
		entr.get_node("Icon").texture = i.party_icon
		entr.get_node("Name").text = i.first_name
		entr.set_meta("Actor", i)
		$Canvas/TurnOrderPop/Margin/List.add_child(entr)

	if $Canvas/TurnOrderPop/Margin/List.get_child(0).name == "Char":
		$Canvas/TurnOrderPop/Margin/List/Char.queue_free()


func turn_ui_check() -> void:
	for i in $Canvas/TurnOrderPop/Margin/List.get_children():
		if i.get_meta("Actor") == CurrentChar: i.get_node("Arrow").show()
		else: i.get_node("Arrow").hide()

## Party sprite positions for each party size (leader first).
const PARTY_POSITIONS := {
	1: [Vector2(-45, 0)],
	2: [Vector2(-45, -15), Vector2(-45, 45)],
	3: [Vector2(-45, -25), Vector2(-45, 15), Vector2(-45, 55)],
	4: [Vector2(-20, -40), Vector2(-45, -15), Vector2(-20, 15), Vector2(-45, 40)],
}
## Enemy sprite positions for each troop size.
const ENEMY_POSITIONS := {
	1: [Vector2(66, 0)],
	2: [Vector2(66, -15), Vector2(46, 30)],
	3: [Vector2(66, -25), Vector2(36, 15), Vector2(66, 55)],
	4: [Vector2(66, -35), Vector2(36, 15), Vector2(90, 15), Vector2(66, 65)],
}


func position_sprites() -> void:
	act.get_node("Actor0").show()

	var party_count := Query.number_of_party_members()

	if PARTY_POSITIONS.has(party_count):
		var party_positions: Array = PARTY_POSITIONS[party_count]

		for i in party_positions.size():
			var member: Actor = Party.current[i]
			member.node.show()
			member.node.position = party_positions[i]

	if ENEMY_POSITIONS.has(Troop.size()):
		var enemy_positions: Array = ENEMY_POSITIONS[Troop.size()]

		for i in enemy_positions.size():
			var enemy := act.get_node_or_null("Enemy" + str(i))

			if enemy:
				enemy.show()
				enemy.position = enemy_positions[i]

	for i in TurnOrder:
		var enemy := i as Enemy

		if enemy != null and enemy.custom_position != Vector2i.ZERO:
			i.node.position = enemy.custom_position

		pixel_perfectize(i)


## Adds a party member while a battle is already running, for story beats where
## someone joins mid-fight. Creates their battle sprite and turn-order slot and
## refreshes the battle UI.
func recruit_party_member(codename: StringName) -> Actor:
	var member := Party.get_member(codename)

	if member == null:
		return null

	if member in TurnOrder:
		return member

	Party.add(str(codename))
	member = Party.get_member(codename)
	var index := Party.member_index(member)

	if index <= 0:
		push_warning("No open party slot for " + str(codename))
		return null

	if not is_instance_valid(member.node):
		await create_actor_node(member, "Actor" + str(index))

	member.speed = 8 - index * 2
	member.next_action = Actor.BtAction.UNSET
	member.next_move = null
	member.next_target = null
	member.battle_log = [Actor.log_entry.new()]
	member.turns_taken = 0
	member.load_complimentaries()
	await sprite_init(member)
	TurnOrder.push_front(member)
	resort_turn_order()
	position_sprites()
	turn_ui_init()
	Hud.battle_state()
	return member


func entrance() -> void:
	Action = true
	Global.controllable = false
	cam.position_smoothing_enabled = false

	if sequence.transition and not sequence.skip_entrance:
		Loader.battle_bars(3)
		if sequence.EntranceBanter != "":
			if sequence.EntranceBanterIsPassive:
				Passive.open("banter_entrance", sequence.EntranceBanter)
			else:
				Textbox.open("banter_entrance", sequence.EntranceBanter)
				cam.position.x = 60

				while Textbox.is_open:
					if cam.position.x > 0: cam.position.x -= 0.01
					await Event.wait()

		if not has_entrance_sequence():
			cam.zoom = Vector2(4, 4)
			cam.position = Vector2(90, 10)
			var t := create_tween()
			t.set_ease(Tween.EASE_IN_OUT)
			t.set_trans(Tween.TRANS_QUART)
			t.tween_property(cam, "zoom", Vector2(5.5, 5.5), 0.5)
			t.parallel().tween_property(cam, "position", Vector2(90, 0), 0.5)
			t.tween_property(cam, "position", Vector2(-50, 0), 0.5).set_delay(0.5)
			await Event.wait(0.3, false)
			enemy_ui.all_enemy_ui(true)
			if battle_advantage == 1:
				for i in Troop: damage(i, 1, false, 24 / Troop.size())

			await Event.wait(0.5, false)
	else:
		screen_shake()

	if not has_entrance_sequence() and not sequence.skip_entrance:
		await play_party_entrances()

	# An authored opening can end while an actor's Entrance animation is still
	# playing; let it finish before moving on to the first turn.
	if has_entrance_sequence() and not sequence.skip_entrance:
		await await_playing_entrance_animations()

	Loader.battle_bars(2)
	await Event.wait(0.5, false)
	if not sequence.transition: enemy_ui.all_enemy_ui(true)
	Hud.battle_state(true)
	Hud.save_box_positions()
	await Event.wait(0.7, false)

	# Always start the first turn here, after the whole opening has played. An
	# entrance sequence may end with an END_TURN step; end_turn() defers it
	# while entrance_in_progress is set so the transition can finish first.
	entrance_in_progress = false
	if not headless_driver: next_turn.emit()


## Plays every present party member's Entrance animation at once and waits for
## all of them, so the next turn can't cut the last frames off.
func play_party_entrances() -> void:
	var pending := {"count": 0}

	for i in Party.current:
		if not i: continue
		pending["count"] += 1
		_finish_party_entrance(i, pending)

	while pending["count"] > 0:
		await Event.wait()


func _finish_party_entrance(i: Actor, pending: Dictionary) -> void:
	await entrance_anim(i)
	pending["count"] -= 1


## Waits for any Entrance animation an authored opening left playing.
func await_playing_entrance_animations() -> void:
	for i in TurnOrder:
		if i == null or i.node == null:
			continue

		if i.node.animation == &"Entrance" and i.node.is_playing():
			await await_anim(i.node, "Entrance")


## True when the battle brings its own inspector-authored opening sequence.
func has_entrance_sequence() -> bool:
	return sequence.entrance_sequence != null and not sequence.entrance_sequence.steps.is_empty()


func entrance_anim(i: Actor) -> void:
	play_sound("Entrance", i)
	await Event.wait(0.3)
	await anim(&"Entrance", i)
	if i.node.animation == &"Entrance" or i.node.animation == &"Idle": anim("", i)


func _on_next_turn() -> void:
	if check_for_victory(): return
	# A trap's interruption only lasts for the action that sprung it
	interrupted = false
	#position_sprites()
	Turn += 1
	follow_up_turn = follow_up_next

	if follow_up_turn:
		follow_up_text()
		follow_up_next = false
		TurnInd = TurnOrder.find(CurrentChar)
	else:
		if TurnOrder.size() - 1 <= TurnInd:
			TurnInd = 0
		else:
			TurnInd += 1

	CurrentChar = TurnOrder[TurnInd]
	CurrentChar.turns_taken += 1

	if CurrentChar.node == null:
		_on_next_turn()
		return

	if CurrentChar in skipped_turns:
		skipped_turns.erase(CurrentChar)
		CurrentChar.next_action = Actor.BtAction.UNSET
		CurrentChar.next_move = null
		CurrentChar.next_target = null
		end_turn()
		return

	# Fodder that is mid-deletion should not get another turn.
	if CurrentChar.queue_delete:
		end_turn()
		return

	# Scripted dialogue can ask for the next turn to be held before it starts,
	# so it cannot race the action itself ending the turn.
	if pending_turn_holds > 0:
		pending_turn_holds -= 1
		hold_turn()

	print("-------------------------------------------------")
	print_rich("[color=cornflower-blue]Turn: ", Turn, " - Index: ", TurnInd, " - Name: ", CurrentChar.first_name)
	initial = CurrentChar.node.position

	# Knocked-out enemies stay in the turn order just like party members, so an
	# ally can heal them and their KnockedOut.on_turn chance can get them up.
	# Fodder that is meant to disappear is handled by queue_delete above.
	if CurrentChar.is_enemy: enemy_ui._on_battle_ui_target_foc(CurrentChar)
	else: enemy_ui.all_enemy_ui()
	await handle_states()
	make_move()


## Ticks the current actor's states, runs their on-turn sequences, then clears
## states that expired this turn. The actor can only act once this finishes.
func handle_states() -> void:
	var chara := CurrentChar

	for state: State in chara.states.duplicate():
		print("Handling ", state.name)

		if state.turns > -1:
			state.turns -= 1

			if state.turns == 0:
				state.queue_remove = true
				anim("", chara)

		if state.queue_remove:
			continue

		await run_state_sequence(state.on_turn, state, chara)

	await remove_queued_states(chara)
	chara.damage_received_this_turn = 0


func check_for_victory() -> bool:
	var knocked_out := filter_actors_by_state(Troop, "Knocked Out").size()

	if knocked_out == Troop.size() or Troop.is_empty():
		victory()
		return true
	else: return false


func make_move() -> void:
	if check_for_victory(): return
	if CurrentChar.next_action == Actor.BtAction.UNSET:
		var enemy := CurrentChar as Enemy

		if (
			not CurrentChar.controllable
			and enemy != null
			and enemy.turn_sequence != null
			and not enemy.turn_sequence.is_empty()
		):
			await run_turn_sequence(CurrentChar)
		elif CurrentChar.controllable:
			print_rich("[color=cornflower-blue]Control")
			GetControl.emit()
		else:
			$AI.ai()
	else:
		print_rich("[color=cornflower-blue]Forced move")
		confirm_next()


## Runs an actor's authored turn. The sequence is responsible for its own
## actions; the battle ends the turn afterwards unless the script ended the
## battle itself (for example by showing a scripted victory).
func run_turn_sequence(actor: Actor) -> void:
	var enemy := actor as Enemy

	if enemy == null or enemy.turn_sequence == null or enemy.turn_sequence.is_empty():
		return

	Action = true
	await run_battle_sequence(enemy.turn_sequence, actor, CurrentTarget, false)

	if not is_instance_valid(self):
		return

	if battle_result != Result.UNFINISHED or AwaitVictory:
		return

	anim("", actor)
	await end_turn()


func _on_ai_chosen() -> void:
	confirm_next()


func confirm_next(action_anim := true) -> void:
	if CurrentChar.next_move == null:
		CurrentChar.next_move = Ability.nothing()

	if CurrentChar.controllable: ui.close()

	if CurrentChar.next_move == CurrentChar.standard_attack:
		CurrentChar.next_action = Actor.BtAction.ACT

	print_rich("[color=cornflower-blue]Action: ", CurrentChar.next_action)

	if action_anim:
		await play_action_animation(CurrentChar, CurrentChar.next_move, CurrentChar.next_action)

	if CurrentChar.next_target == null:
		CurrentChar.next_target = random_target(CurrentChar.next_move)

	_on_battle_ui_ability_returned(CurrentChar.next_move, CurrentChar.next_target)


## Plays the wind-up animation for an action before its ability runs. MAGIC
## casts with the callout and a camera zoom, ITEM uses the item animation.
## ACT and UNSET have no extra wind-up.
func play_action_animation(actor: Actor, ability: Ability, action: int) -> void:
	if actor == null or actor.node == null or ability == null:
		return

	if ability.show_cutin:
		cut_in(actor.codename)

	match action:
		Actor.BtAction.MAGIC:
			focus_cam(actor)
			zoom(5.5)
			callout(ability)
			var timer := get_tree().create_timer(0.5)
			await anim("Ability", actor)
			if timer.time_left != 0: await timer.timeout

		Actor.BtAction.ITEM:
			focus_cam(actor)
			zoom(5.5)
			var pos := actor.node.get_global_transform_with_canvas().origin
			Item.use_animation(ability.icon, ability.name, pos)
			await Event.wait(2)


func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("DebugR"):
		end_battle()

	if Input.is_action_just_pressed("DebugV"):
		for i in Troop:
			death(i)

		ui.close()
		victory()

	if Input.is_action_pressed("Dash") and Action:
		Engine.time_scale = 8
		cam.position_smoothing_enabled = false
	elif Input.is_action_just_released("Dash"):
		Engine.time_scale = 1

	if AwaitVictory:
		if Input.is_action_just_released("ui_accept"):
			end_battle()

	if Input.is_action_just_pressed("DebugF"):
		print(relation_to_dmg_modifier(color_relation(CurrentChar.main_color,
		ui.target.main_color)))


func _on_battle_ui_ability() -> void:
	if CurrentChar.node == null: return
	if ui.PrevStage == "root":
		play_sound("Ability", CurrentChar)
		await anim("Ability")

	if CurrentChar.node.animation == "Ability": anim("AbilityLoop")


func _on_battle_ui_root() -> void:
	Engine.time_scale = 1
	enemy_ui.all_enemy_ui()
	stop_sound("Ability", CurrentChar)
	anim()


func callout(ab: Ability = CurrentAbility) -> void:
	if not ab.callout:
		return

	var tc := create_tween()
	tc.set_ease(Tween.EASE_OUT)
	tc.set_trans(Tween.TRANS_QUINT)
	if callout_onscreen:
		tc.tween_property($Canvas/Callout, "modulate", Color.TRANSPARENT, 0.2)
		await tc.finished
		tc.kill()
		tc = create_tween()
		tc.set_ease(Tween.EASE_OUT)
		tc.set_trans(Tween.TRANS_QUINT)

	callout_onscreen = true

	if ab.color_same_as_actor: ab.wheel_color = CurrentChar.main_color
	$Canvas/Callout.text = ab.name
	$Canvas/Callout.add_theme_color_override("font_color", ab.wheel_color)
	tc.tween_property(
		$Canvas/Callout, "position", Vector2(37, 636), 2).from(Vector2(400, 636))

	tc.parallel().tween_property(
		$Canvas/Callout, "modulate", Color.WHITE, 2).from(Color.TRANSPARENT)

	#await tc.finished
	#print_rich("[color=cornflower-blue]call")
	tc.set_ease(Tween.EASE_IN)
	if CurrentChar.controllable:
		tc.tween_property(
			$Canvas/Callout, "position", Vector2(-200, 636), 0.5).set_delay(1)
	else: tc.tween_property(
		$Canvas/Callout, "position", Vector2(-200, 636), 0.5).set_delay(4)

	tc.parallel().tween_property(
		$Canvas/Callout, "modulate", Color.TRANSPARENT, 0.5)

	await tc.finished
	callout_onscreen = false


func _on_battle_ui_ability_returned(ab: Ability, tar: Actor) -> void:
	if not is_instance_valid(tar): return
	print_rich("[color=cornflower-blue]Using ", ab.name, " on ", tar.first_name)

	for i in CurrentChar.battle_log: if i.turn == Turn:
		print_rich("[color=cornflower-blue]Double turn detected, aborting")
		return

	var log_entry := Actor.log_entry.new()
	log_entry.ability = ab; log_entry.target = tar; log_entry.turn = Turn
	CurrentChar.battle_log.append(log_entry)
	CurrentChar.next_action = Actor.BtAction.UNSET
	CurrentChar.next_move = null
	CurrentChar.next_target = null
	CurrentAbility = ab
	CurrentTarget = tar

	if ab.name == "DeathSequence":
		CurrentChar.death_sequence_queued = false

	if CurrentChar.has_state("Bound") and (CurrentAbility.uses_weapon() or CurrentAbility == CurrentChar.standard_attack):
		CurrentAbility = Ability.nothing()
		battle_msg("struggle")
		await shake_actor(CurrentChar)
		end_turn()
		return

	if ab.remove_item_on_use != null:
		Item.remove_item(ab.remove_item_on_use)

	if ab == null:
		end_turn()
		return

	if ab.color_same_as_actor:
		ab.wheel_color = CurrentChar.main_color

	if ab.target == 1:
		if tar and tar.has_state("Knocked Out"):
			var i := -1
			var oldtar := CurrentTarget.first_name

			while (CurrentTarget.first_name == oldtar or
			CurrentTarget.has_state("Knocked Out") or CurrentTarget.node == null):
				i += 1

				if i > get_ally_faction(CurrentTarget).size():
					if get_ally_faction(CurrentTarget)[0].is_enemy:
						victory()
						return
					else:
						game_over()
						return

				CurrentTarget = get_ally_faction(CurrentTarget)[i - 1]

		if tar.is_enemy:
			ui.emit_signal("targetFoc", tar)
	elif ab.target == 0:

		if CurrentChar.is_enemy:
			ui.emit_signal("targetFoc", CurrentChar)

	if CurrentChar.is_enemy:
		ui.emit_signal("targetFoc", CurrentChar)
	elif ab.target == 2: enemy_ui.all_enemy_ui()

	var has_sequence := ab.action_sequence != null and not ab.action_sequence.is_empty()

	if has_sequence:
		CurrentChar.add_aura(-CurrentAbility.aura_cost)
		if CurrentAbility.callout and CurrentChar.controllable:
			callout()

		action_runner.run_ability(ab, CurrentChar, CurrentTarget)
	else:
		end_turn()
		return


## Used for showing toasts. These can be set in BattleText from the editor.
## Certain strings are replaced, as seen below
func battle_msg(id: String, insert := "MISSING", insert2 := "MISSING2") -> String:
	var target := CurrentTarget if CurrentTarget else Troop[0]
	var text := BattleText[id]
	text = text.replace("[cur]", CurrentChar.first_name)
	text = text.replace("[tar]", target.first_name)
	text = text.replace("[insert]", insert)
	text = text.replace("[insert2]", insert2)

	for pronoun in ["themself", "they", "them", "their"] as PackedStringArray:
		text = text.replace("[cur_" + pronoun + "]", CurrentChar.get_pronoun(pronoun))
		text = text.replace("[tar_" + pronoun + "]", target.get_pronoun(pronoun))

	UI.toast(text)
	return text


func jump_to(
	character: Actor, to_position: Vector2, time: float, height: float = 0.5
) -> void:
	hide_state_effects(character)
	var t := create_tween()
	var start_pos := character.node.position
	var jump_distance: float = start_pos.distance_to(to_position)
	var jump_height: float = jump_distance * height
	var midpoint := start_pos.lerp(to_position, 0.5) + Vector2.UP * jump_height
	var jump_time := jump_distance * (time * 0.001)
	t.tween_method(
		Query.quad_bezier.bind(start_pos, midpoint, to_position, character.node),
		0.0,
		1.0,
		jump_time
	)
	await t.finished
	anim_done.emit()


func jump_to_target(
	character: Actor, tar: Actor, offset: Vector2, time: float, height: float = 0.5
) -> void:
	await jump_to(character, tar.node.position + offset, time, height)


func return_cur(target: Actor = CurrentChar) -> void:
	await jump_to(target, initial, 1, 0.2)


## Make the turn wait until a matching release_turn is called. 
## Counter based, so parallel holders can't unlock each other's hold early.
func hold_turn() -> void:
	lock_count += 1
	lock_turn = true


## Undo one hold_turn
func release_turn() -> void:
	lock_count = maxi(0, lock_count - 1)

	if lock_count == 0: lock_turn = false


## Hold the turn as soon as the next actor's turn begins. Scripted dialogue
## uses this to keep talking over a turn without racing the action's end_turn().
func hold_next_turn() -> void:
	pending_turn_holds += 1


func end_turn() -> void:
	# An entrance sequence often ends with an END_TURN step. Defer it until the
	# opening transition is finished; entrance() starts the first turn itself.
	if entrance_in_progress:
		return

	Global.check.emit()

	# Traps are resolved here, after the action's sequences are done
	if not pending_traps.is_empty():
		await resolve_traps()

	for i in TurnOrder:
		if i.aura == 0 and i.health != 0 and not (
			i.has_state("AuraBreak") or i.has_state("UnbreakingAura") or i.has_state("KnockedOut")
		):
			await i.add_state("AuraBreak")
			if i != CurrentChar:
				follow_up_next = true

	if sequence.check_events() and not follow_up_next:
		await Event.wait(0.5)
		await sequence.call_events()

	sequence.reset_events()
	TurnOrder.sort_custom(speed_sort)

	# Safety timer just in case to avoid softlocks
	var lock_start := Time.get_ticks_msec()

	while lock_turn:
		if Time.get_ticks_msec() - lock_start > 20000:
			push_warning("lock_turn was held for over 20 seconds, releasing early")
			lock_count = 0
			lock_turn = false

		await Event.wait()

	await get_tree().create_timer(0.1).timeout
	show_state_effects()
	await remove_queued_states(CurrentChar)
	if is_instance_valid(CurrentChar.node):
		CurrentChar.node.z_index = 0

	for i in TurnOrder:
		if i.queue_delete:
			delete_actor(i)

	# The preview plays a single action, so close after that action's turn.
	if previewing:
		preview_finished.emit()
		return

	next_turn.emit()


## Starts the first turn when a scripted opening held it before any actor got
## control. Without this, a dialogue that uses [method hold_turn] and then
## [method release_turn] would unlock the turn but never ask for the next one.
func start_turns() -> void:
	if TurnInd != -1 or Turn > 0:
		return

	next_turn.emit()

## Battle events that do not hold the turn are run here, one after another, so
## their dialogues cannot open on top of each other. The queue is deliberately
## not awaited by end_turn: a flavor passive keeps playing while the turn moves
## on, it just cannot be replaced by the next event mid-sentence.
var event_queue: Array[BattleEvent] = []
var event_queue_running := false


func queue_event(event: BattleEvent) -> void:
	if event == null or event_queue.has(event):
		return

	event.queued = true
	event_queue.append(event)
	_run_event_queue()


func _run_event_queue() -> void:
	if event_queue_running:
		return

	event_queue_running = true

	while not event_queue.is_empty():
		var event: BattleEvent = event_queue.pop_front()
		await event.run()

	event_queue_running = false


## Waits for queued non-holding events to finish. Holding events call this first
## so they never play over a passive that is already on screen.
func wait_for_event_queue() -> void:
	while event_queue_running or not event_queue.is_empty():
		await Event.wait()


func damage(
	target: Actor,
	is_magic := not CurrentAbility.uses_weapon(),
	elemental := false,
	x: int = Query.calc_num(),
	effect := true,
	limiter := false,
	ignore_stats := false,
	overwrite_color: Color = Color.WHITE
) -> int:
	# A sprung trap interrupts the ability against the hit target, so it can't
	# deal any more damage in that sequence
	if interrupted:
		print_rich("[color=cornflower-blue]Ability was interrupted by a trap, no damage dealt")
		return 0

	# A target whose node is already gone should be discarded
	if target == null or not is_instance_valid(target) or target.node == null:
		return 0

	take_dmg.emit()
	if CurrentAbility == null: CurrentAbility = Ability.nothing()

	## Elemental modifier
	var el_mod: float = 1
	## Color of the offending ability
	var color := (CurrentAbility.wheel_color if overwrite_color == Color.WHITE else overwrite_color)
	## Relation from the ability to the target
	var relation := color_relation(color, target.main_color)

	if elemental:
		el_mod = relation_to_dmg_modifier(relation)
		print("Relation: %s	Modifier: %d"%[relation, el_mod])

	print_rich("[color=cornflower-blue]Attack power: ", x, " * ", el_mod)

	# Attacker to get offensive stats from (null if stats are ignored)
	var offender: Actor = null if ignore_stats else CurrentChar
	# Initial number of damage
	var dmg: int = target.calc_dmg(x * el_mod, is_magic, offender)

	# State specific modifications. Removing a state (e.g. Frozen) mutates the
	# live array, so walk a snapshot or the next state gets skipped.
	for state: State in target.states.duplicate():
		# Mutiply with each state's modifiers
		if is_magic:
			dmg = int(dmg * state.magic_dmg_mult)
		else:
			dmg = int(dmg * state.weapon_dmg_mult)

		match state.filename:
			"Frozen":
				target.remove_state("Frozen")
				battle_msg("ice_breaks", target.first_name)

			"Guarding":
				# With Guarding, you nothing is weak
				if relation != Wheel.Relation.RESIST:
					relation = Wheel.Relation.N
					el_mod = min(el_mod, 1)

			"AuraBreak":
				# With AuraBreak, everything is weak
				if relation != Wheel.Relation.OP:
					relation = Wheel.Relation.WEAK
					el_mod = max(el_mod, 1)

		if relation == Wheel.Relation.WEAK:
			dmg = int(dmg * state.weak_mult)

	# If damage is 0, don't do anything below
	if dmg == 0:
		pop_num(target, "BLOCKED")
		return 0

	# Clutch damage, health should never go to 0
	if (
		((target.clutch_dmg and target.health > 0.2*target.max_hp)
		or target.cant_die) and target.health - dmg < 0
	):
		print("Damage on ", target.first_name, " was clutched")

		# cant_die actors let Actor.damage roll the 1-5 hp clutch value; actors
		# with only clutch_dmg stop at exactly 1 hp.
		limiter = not target.cant_die
		queue_sequence_for_actor(target, death_sequence_for(target), "DeathSequence")

	# Actual damage happens
	target.damage(dmg, limiter)
	print(CurrentChar.first_name + " deals " + str(dmg) + " damage to " + target.first_name)

	# Effects!
	if not is_magic:
		# Preparations uses turns == -2 as a one-attack charge, so remove one
		# charge per weapon attack instead of assuming AtkUp is a single state.
		for state: State in CurrentChar.states:
			if state.filename == "AtkUp" and state.turns == -2:
				state.queue_remove = true
				print_rich("[color=cornflower-blue]Weapon attack, so AtkUp will be removed")
				break

	if CurrentAbility.recover_aura: CurrentChar.add_aura(dmg / 2)

	damage_feedback(target, dmg, color, relation, elemental)

	check_party.emit()
	if target.health == 0:
		if target.cant_die:
			target.health = 1
		else:
			# Fire and forget, the turn won't end until knockouts finish
			death(target)
			if target != CurrentChar and relation == Wheel.Relation.WEAK: follow_up_next = true
			return dmg

	if target.health == 0 or target.has_state("Knocked Out"): return dmg

	var aura_recovery := 0.0

	for state in target.states:
		aura_recovery = maxf(aura_recovery, state.aura_on_damage)

	if aura_recovery > 0.0:
		var recovered := roundi(dmg * aura_recovery)

		if relation == Wheel.Relation.RESIST: recovered *= 2

		target.add_aura(recovered)

	if target.pose().is_empty() and effect:
		play_sound("Hit", target)
		hit_animation(target)
		if elemental and not target.has_state("AuraBreak"):
			var part: GPUParticles2D = target.node.get_node_or_null("Particle")

			if el_mod > 1 and part:
				part.emitting = true

			outline(target)
			if part:
				part.process_material.gravity = Vector3(offsetize(120), 0, 0)
				part.process_material.color = target.main_color

			outline_remove(target)
			Input.stop_joy_vibration(0)

	# Traps are resolved by end_turn() once the action is over, so damage()
	# stays synchronous and AOE contexts stay untouched
	if dmg > 0 and target != CurrentChar and not in_trap:
		queue_traps(target, is_magic, relation, dmg)

	target.damage_received_this_turn += dmg
	return dmg


## Applies the visual and audio feedback of a landed hit: aura drain, damage
## numbers, HUD shake and controller rumble
func damage_feedback(target: Actor, dmg: int, color: Color, relation: Wheel.Relation, elemental: bool) -> void:
	if elemental:
		var base_dmg := int(dmg * target.defence * 2 * target.defence_multiplier)
		var aur_dmg := relation_to_aura_dmg(relation, base_dmg)
		var aura_before := target.aura
		print(target.first_name, " takes ", aur_dmg, " aura damage")
		target.add_aura(-aur_dmg)

		# Grant the follow-up at the moment the aura breaks. Waiting until
		# end_turn loses it when the same hit also defeats the target.
		if (
			aura_before > 0
			and target.aura == 0
			and target != CurrentChar
			and not target.has_state("AuraBreak")
			and not target.has_state("UnbreakingAura")
		):
			follow_up_next = true

		pop_num(target, dmg, color)

		# Show the popup text
		match relation:
			Wheel.Relation.WEAK: pop_num(target, "WEAK")
			Wheel.Relation.OP: pop_num(target, "WEAK!")
			Wheel.Relation.RESIST: pop_num(target, "RESIST")
	else: pop_num(target, dmg)

	if !target.is_enemy:
		Hud.hit_partybox(Party.current.find(target), int(dmg / 2), int(dmg * 100 / target.max_hp * 100) / 300)
	else:
		Event.node_shake(enemy_ui.get_node("EnemyFocus"), int(dmg), int(dmg * 100 / target.max_hp * 100) / 300)

	if target.controllable:
		Controller.rumble(remap(dmg * 2, 0, target.max_hp, 0, 1), remap(dmg, 0, 100, 0, 1), remap(dmg * 2, 0, target.max_hp, 0, 1))
	elif CurrentChar.controllable:
		Controller.rumble(remap(dmg, 0, target.max_hp, 0, 0.5), remap(dmg, 0, 100, 0, 1), remap(dmg, 0, target.max_hp, 0, 0.5))
	else:
		Controller.rumble(remap(dmg, 0, target.max_hp, 0, 0.3), remap(dmg, 0, 100, 0, 0.5), remap(dmg, 0, 100, 0, 0.5))


## Checks a freshly hit actor for traps whose condition matches the incoming hit
## and queues them to spring. Returns true if anything was queued.
func queue_traps(target: Actor, is_magic: bool, relation: Wheel.Relation, dmg: int) -> bool:
	if in_trap: return false

	var sprung := false

	# Iterate over a copy, since a consumed trap removes itself from the owner.
	for state: State in target.states.duplicate():
		if not state is Trap: continue

		var trap := state as Trap

		if trap.ability == null: continue

		if trap.condition != null and not trap.condition.matches(is_magic, relation, dmg, CurrentAbility):
			continue

		if trap.consume_on_trigger:
			target.remove_state(trap)
		else:
			trap.turns = 0

		pending_traps.append({"trap": trap, "owner": target, "attacker": CurrentChar})
		sprung = true
		print_rich("[color=cornflower-blue]", target.first_name, "'s ", trap.name, " trap springs")

	# Cancel any further damage the interrupting ability would have dealt
	if sprung:
		interrupted = true

	return sprung


## Runs every trap that sprung from the current hit, one after another.
func resolve_traps() -> void:
	# Snapshot and clear first, trigger_trap sets in_trap so nothing new is queued
	# while a counterattack is playing.
	var queued := pending_traps.duplicate()
	pending_traps.clear()

	for entry: Dictionary in queued:
		var trap: Trap = entry.get("trap")
		var victim: Actor = entry.get("owner")
		var hitter: Actor = entry.get("attacker")

		if trap == null or not is_instance_valid(victim) or victim.node == null:
			continue

		# Playback was deferred to end_turn, skip owners that died in the meantime
		if victim.health <= 0 or victim.has_state("KnockedOut"):
			continue

		await trigger_trap(trap, victim, hitter)


## Springs a trap. The trap's owner performs the trap's ability
func trigger_trap(trap: Trap, victim: Actor, hitter: Actor) -> void:
	print_rich("[color=cornflower-blue]", victim.first_name, "'s ", trap.name, " trap springs on ", hitter.first_name if hitter else "?")

	# Feedback
	await Event.wait(0.2)

	# Preserve the surrounding context
	var prev_char := CurrentChar
	var prev_ability := CurrentAbility
	var prev_target := CurrentTarget
	var prev_initial := initial
	var prev_interrupted := interrupted

	in_trap = true
	hold_turn()
	interrupted = false

	# The counter runs during the attacker's turn, so `initial` holds the
	# attacker's home position. Point it at the trap owner instead, so any
	# return_cur() inside the counter returns the owner to where it stood.
	if victim.node != null:
		initial = victim.node.position

	# Aim the trap's ability
	var tgt: Actor = victim

	if trap.aims_at_attacker() and hitter != null:
		tgt = hitter

	## Cutin
	callout(trap.ability)
	#if trap.inflicter:
		#await cut_in(trap.inflicter.codename)

	CurrentChar = victim
	CurrentAbility = trap.ability
	CurrentTarget = tgt

	if trap.ability.action_sequence != null and not trap.ability.action_sequence.is_empty():
		var outcome := action_runner.roll_ability(trap.ability, victim, tgt)
		await action_runner.run_trap(trap.ability, victim, tgt, outcome)

	# Restore the surrounding context
	initial = prev_initial
	CurrentChar = prev_char
	CurrentAbility = prev_ability
	CurrentTarget = prev_target
	interrupted = prev_interrupted
	release_turn()
	in_trap = false


## Places a trap on `target`. Traps are States, so this mirrors add_state but
func apply_trap(trap: Trap, target: Actor, inflicter: Actor = null, await_effect := false) -> State:
	if trap == null: return null

	var place: Trap = trap.duplicate(true)

	if place.name.is_empty(): place.name = "Trap"

	if not place.resource_path.is_empty():
		place.resource_name = place.resource_path.get_file().get_basename()
	elif place.resource_name.is_empty():
		place.resource_name = place.name

	return await target.add_state(place, -1, inflicter if inflicter != null else CurrentChar, true, await_effect)


func queue_sequence_for_actor(
	chara: Actor, action_sequence: ActionSequence, sequence_name := "Sequence"
) -> void:
	if chara == null or action_sequence == null or action_sequence.steps.is_empty():
		return

	var ab := Ability.nothing().duplicate()
	ab.name = sequence_name
	ab.action_sequence = action_sequence
	queue_action(chara, ab, chara, Actor.BtAction.ACT)

	if sequence_name == "DeathSequence":
		chara.death_sequence_queued = true


## Queues an intent without touching actor fields at the call site.
func queue_action(actor: Actor, ability: Ability, target: Actor, action := Actor.BtAction.MAGIC) -> void:
	if actor == null:
		return

	actor.next_action = action
	actor.next_move = ability
	actor.next_target = target


## Runs an ability through the same runner as a normal turn action.
## [param pay_cost] and [param log_action] let scripted turns behave like a
## regular AI action without changing the free story moves that call this with
## their defaults.
func use_ability_now(
	actor: Actor,
	ability: Ability,
	target: Actor,
	consume_turn := false,
	action := Actor.BtAction.ACT,
	pay_cost := false,
	log_action := false,
) -> void:
	if actor == null or ability == null:
		return

	if ability.color_same_as_actor:
		ability.wheel_color = actor.main_color

	push_acting_context(actor, ability, target)

	if pay_cost:
		actor.add_aura(-ability.aura_cost)

	if log_action:
		var entry := Actor.log_entry.new()
		entry.ability = ability
		entry.target = target
		entry.turn = Turn
		actor.battle_log.append(entry)

	# Forced story actions can ask for the same wind-up the battle UI plays,
	# for example Actor.BtAction.MAGIC to cast before the ability starts.
	if action != Actor.BtAction.ACT and action != Actor.BtAction.UNSET:
		await play_action_animation(actor, ability, action)

	await action_runner.run_ability(ability, actor, target, consume_turn)
	pop_acting_context()


## Asks the AI for a move, then runs it as part of a scripted turn. The normal
## AI path confirms through [signal ai_chosen]; [member Ai.manual] suppresses
## that so the authored turn stays in control of the order. [param target_hint]
## can force a single-enemy ability onto a specific actor without taking the
## ability choice away from the AI.
func ai_move(actor: Actor, consume_turn := false, target_hint: Actor = null) -> void:
	if actor == null or not is_instance_valid(actor):
		return

	actor.next_action = Actor.BtAction.UNSET
	actor.next_move = null
	actor.next_target = null

	var ai := $AI
	ai.manual = true
	ai.ai()
	ai.manual = false

	var ability := actor.next_move
	var target := actor.next_target
	var action := actor.next_action
	actor.next_action = Actor.BtAction.UNSET
	actor.next_move = null
	actor.next_target = null

	if ability == null:
		return

	# Authored turns use this to keep the AI's choice of move but focus a
	# single-target enemy ability on the actor that phase is about.
	if (
		target_hint != null
		and is_instance_valid(target_hint)
		and target_hint.health > 0
		and ability.target == Ability.T.ONE_ENEMY
	):
		target = target_hint

	await use_ability_now(actor, ability, target, consume_turn, action, true, true)

	# Damage is applied before the knockout/ death sequence finishes. When the
	# move dropped someone, that sequence holds the turn; wait for it so a
	# scripted turn does not start its next action (or a cutscene) on top of it.
	await wait_for_turn_release()

	if not consume_turn and is_instance_valid(actor.node):
		anim("", actor)


## Waits until every temporary turn hold has been released.
func wait_for_turn_release() -> void:
	var start_time := Time.get_ticks_msec()

	while lock_turn:
		if battle_result != Result.UNFINISHED:
			break

		# A party wipe is handled by game over, do not make the boss keep
		# playing its turn while the defeat transition runs.
		if filter_dead(Party.current).is_empty():
			break

		if Time.get_ticks_msec() - start_time > 20000:
			push_warning("Turn hold was not released within 20 seconds")
			break

		await Event.wait()


func push_acting_context(actor: Actor, ability: Ability, target: Actor) -> void:
	acting_stack.append({
		"char": CurrentChar,
		"ability": CurrentAbility,
		"target": CurrentTarget,
		"initial": initial,
	})
	CurrentChar = actor
	CurrentAbility = ability
	CurrentTarget = target
	initial = actor.node.position if actor.node != null else initial


func pop_acting_context() -> void:
	if acting_stack.is_empty():
		return

	var previous: Dictionary = acting_stack.pop_back()
	CurrentChar = previous["char"]
	CurrentAbility = previous["ability"]
	CurrentTarget = previous["target"]
	initial = previous["initial"]


func force_next_actor(actor: Actor) -> void:
	if actor == null:
		return

	var index := TurnOrder.find(actor)

	if index >= 0:
		TurnInd = index - 1
		follow_up_next = false


func skip_next_turn(actor: Actor) -> void:
	if actor == null:
		return

	if not skipped_turns.has(actor):
		skipped_turns.append(actor)


func resort_turn_order(preserve_current := true) -> void:
	var current_actor := CurrentChar
	TurnOrder.sort_custom(speed_sort)
	if preserve_current and current_actor in TurnOrder:
		TurnInd = TurnOrder.find(current_actor)


func cancel_follow_up() -> void:
	follow_up_next = false


## Runs a named sequence from database/Sequences/Action for dialogue cues and events.
func run_action_sequence(sequence_name: StringName) -> void:
	var path := "res://database/Sequences/Action/" + str(sequence_name) + ".tres"

	if not ResourceLoader.exists(path):
		push_warning("Action sequence not found: " + path)
		return

	var seq: ActionSequence = await Loader.load_res(path)

	if seq == null:
		return

	await run_battle_sequence(seq, CurrentChar, CurrentTarget)


## Runs an inspector authored sequence outside of an ability, using the party
## leader as the caster so steps still have a subject to work from. Entrance and
## victory sequences manage their own turn, so they pass hold as false.
func run_battle_sequence(
	seq: ActionSequence,
	caster: Actor = null,
	target: Actor = null,
	hold := true
) -> void:
	if seq == null or seq.steps.is_empty():
		return

	var ctx := ActionSequenceContext.new()
	ctx.battle = self
	ctx.runner = action_runner
	ctx.sequence = seq
	ctx.caster = caster if caster != null else Party.Leader
	ctx.target = target if target != null else ctx.caster
	ctx.home_position = initial

	if hold:
		hold_turn()

	await action_runner.run_action_sequence(seq, ctx)

	if hold:
		release_turn()


func hit_animation(target: Actor) -> void:
	if target.node.animation != "KnockedOut":
		anim("Hit", target)
		await await_anim(target.node, "Hit")
		anim("Idle", target)


func outline(target: Actor, color: Color = target.main_color) -> void:
	if target.node.material.get_shader_parameter("outline_enabled") != null:
		target.node.material.set_shader_parameter("outline_enabled", true)
		target.node.material.set_shader_parameter("outline_color", color)


func outline_remove(target: Actor, time := 0.5) -> void:
	if target.node.material.get_shader_parameter("outline_enabled") != null:
		var t := create_tween()
		t.tween_property(target.node.material, "shader_parameter/outline_color", Color.TRANSPARENT, time)
		await t.finished
		target.node.material.set_shader_parameter("outline_enabled", false)


func screen_shake(amount: float = 15.0, duration: float = 0.5, frequency := 0.2) -> void:
	if Input.get_joy_vibration_strength(0) == Vector2.ZERO:
		Controller.rumble(amount / 20.0, 0.35, duration)

	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = frequency

	var initial_offset: Vector2 = cam.offset
	var start_time: float = Time.get_ticks_msec() / 1000.0

	var t: Tween = create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUAD)

	t.tween_method(
		func(am: float) -> void:
			var elapsed: float = (Time.get_ticks_msec() / 1000.0) - start_time
			var noise_time: float = elapsed * 100.0
			var shake_offset: Vector2 = Vector2(
				noise.get_noise_2d(noise_time, 0.0) * am,
				noise.get_noise_2d(0.0, noise_time) * am
			)
			cam.offset = initial_offset + shake_offset,

		amount,
		0.0,
		duration
	)

	await t.finished
	cam.offset = initial_offset


func play_effect(animation: String, target: Variant, offset := Vector2.ZERO, flip_on_player_use := false, dont_free := false) -> void:
	var effect := spawn_effect(animation, target, offset, flip_on_player_use)

	if effect == null:
		return

	await await_anim(effect, animation)
	if not dont_free and is_instance_valid(effect): effect.queue_free()


## Creates and starts an effect, returning its sprite so callers can keep a
## direct reference. Looking effects up by node name breaks when two effects
## with the same animation overlap, since Godot renames the second node.
func spawn_effect(
	animation: String, target: Variant, offset := Vector2.ZERO, flip_on_player_use := false
) -> AnimatedSprite2D:
	if not effects.sprite_frames.has_animation(animation):
		return null

	print_rich("[color=cornflower-blue]Playing effect ", animation)

	if target is not Vector2:
		if target is Actor and is_instance_valid(target) and is_instance_valid(target.node):
			target = target.node.position
		else:
			push_error("The target of the effect ", animation, " was invalid")
			return null

	var ef: AnimatedSprite2D = effects.duplicate()

	if flip_on_player_use and !CurrentChar.is_enemy: ef.flip_h = true
	ef.name = animation
	act.add_child(ef)
	ef.position = target + offset
	ef.play(animation)
	return ef


## Frees an effect once its animation finishes, without blocking the caller.
func free_effect_when_done(effect: AnimatedSprite2D, animation := "") -> void:
	if effect == null:
		return

	await await_anim(effect, animation)
	if is_instance_valid(effect): effect.queue_free()


func cut_in(image: String = CurrentChar.codename) -> void:
	if not ResourceLoader.exists("res://art/Pictures/Cutin_" + image + ".png"):
		return

	#Engine.time_scale = 0.1
	var img: Texture = await Loader.load_res("res://art/Pictures/Cutin_" + image + ".png")
	$Canvas/Cutin/Texture.texture = img
	$Canvas/Cutin.show()
	var t := create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property($Canvas/Cutin, "size:y", 380, 0.3).from(0)
	t.tween_property($Canvas/Cutin, "position:y", 185, 0.3).from(400)
	t.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property($Canvas/Cutin/Texture, "position", Vector2(0, -145), 1).from(Vector2(-1000, 0))
	#t = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	#t.tween_property($Canvas/Cutin/Texture, "position", Vector2(0, -148), 1).from(Vector2(-121, 0))
	await t.finished
	#await Event.wait(1.5)
	t = create_tween().set_parallel().set_trans(Tween.TRANS_QUAD)
	t.tween_property($Canvas/Cutin, "size:y", 0, 0.2)
	t.tween_property($Canvas/Cutin, "position:y", 400, 0.2)
	t.tween_property($Canvas/Cutin/Texture, "position", Vector2(1000, -300), 0.2)
	await t.finished
	$Canvas/Cutin.hide()


func offsetize(num: float, target := CurrentChar) -> float:
	if target == null: return num
	#if CurrentAbility and CurrentAbility.target == 0:
		#return 0

	if target.is_enemy:
		return -num
	else:
		return num


func is_valid_target(target: Actor, ability: Ability = CurrentChar.next_move) -> bool:
	if ability == null: return true
	if ability.target == Ability.T.ONE_ENEMY or ability.target == Ability.T.AOE_ENEMIES:
		if target in get_ally_faction(): return false

	if ability.target == Ability.T.ONE_ALLY or ability.target == Ability.T.AOE_ALLIES:
		if target in get_opposing_faction(): return false

	if target.has_state("KnockedOut"):
		if !ability.can_target_dead: return false

	return true


func pop_num(target: Actor, text: Variant, color: Color = Color.WHITE) -> void:
	if is_instance_valid(target) and target.node != null:
		var number: Label = target.node.get_node("Nums").duplicate()
		target.node.add_child(number)
		number.modulate = Color.TRANSPARENT
		number.show()
		number.add_theme_color_override("font_color", color)
		var tn := create_tween()
		tn.set_ease(Tween.EASE_IN)
		tn.set_trans(Tween.TRANS_QUART)
		number.text = str(text)
		var off: int = 1

		if text is String: off = 0
		tn.tween_property(number, "position", Vector2(offsetize(20 * off) *
			randf_range(0.8, 1.2), -10 * randf_range(0.8, 1.2)),
			0.3).as_relative().from(Vector2(-217, -36))

		tn.parallel().tween_property(number, "modulate",
			Color.WHITE, 0.3).from(Color.TRANSPARENT)

		tn.set_ease(Tween.EASE_OUT)
		tn.tween_property(number, "modulate",
			Color.TRANSPARENT, 2).from(Color.WHITE)

		tn.parallel().tween_property(number, "position",
			Vector2(offsetize(14 * off) *
			randf_range(0.8, 1.2), -6 * randf_range(0.8, 1.2)), 2).as_relative()

		await tn.finished
		if is_instance_valid(number):
			number.queue_free()


func play_sound(sound_name: String, actor: Actor = null, volume: float = 1) -> void:
	$AudioListener2D.make_current()
	var player: AudioStreamPlayer2D
	if actor and actor.node.get_node("SFX").has_node(sound_name):
		player = actor.node.get_node("SFX").get_node(sound_name)
	else:
		player = $Audio/Stream0.duplicate()
		$Audio.add_child(player)
		if not ResourceLoader.exists("res://sound/SFX/Battle/" + sound_name + ".ogg"): return
		player.stream = await Loader.load_res("res://sound/SFX/Battle/" + sound_name + ".ogg")

		if actor: player.global_position = actor.node.global_position

	player.play()
	player.volume_db = volume
	await player.finished
	if player.get_parent() == $Audio: player.queue_free()


func stop_sound(sound_name: String, actor: Actor) -> void:
	if actor.node.get_node("SFX").has_node(sound_name):
		actor.node.get_node("SFX").get_node(sound_name).stop()


## Plays the actor's <codename>_death banter if the cue exists. Death dialogue
## is data-driven by codename so actors don't need a per-resource field.
func play_death_banter(target: Actor) -> void:
	if target == null or target.codename.is_empty():
		return

	var cue := str(target.codename).to_lower() + "_death"
	var banter := await Loader.load_res("res://database/Text/banter_battle.dialogue") as DialogueResource

	if banter == null or not banter.cues.has(cue):
		return

	await Passive.open("banter_battle", cue)


## Finds an actor's death action sequence. An explicit actor override wins;
## otherwise database/Sequences/Action/<codename>_death.tres is used if it
## exists, so most actors never need a death_sequence property.
func death_sequence_for(target: Actor) -> ActionSequence:
	if target == null:
		return null

	if target.death_action_sequence != null and not target.death_action_sequence.is_empty():
		return target.death_action_sequence

	var base: String = "res://database/Sequences/Action/"
	var candidates: Array[String] = [
		str(target.codename) + "_death.tres",
		str(target.codename).to_lower() + "_death.tres",
	]

	for file in candidates:
		var path: String = base + file

		if ResourceLoader.exists(path):
			return load(path) as ActionSequence

	return null


## Runs when an actor is defeated, usually when HP reaches 0
func death(target: Actor) -> void:
	# Skip if already dead
	if not is_instance_valid(target): return
	if target == null or target.node == null: return
	if target.has_state("KnockedOut"): return

	# Turn must not end until everything here has finished
	hold_turn()

	await clear_states(target)

	# TODO: Determine if this is balanced enough or not
	if CurrentChar != null and CurrentChar != target:
		CurrentChar.add_aura(target.aura)

	target.set_aura(0)
	target.set_health(0)
	# Rewards
	var enemy := target as Enemy

	if enemy != null:
		totalSP += enemy.received_sp

		if enemy.dropped_item:
			ObtainedItems.append(enemy.dropped_item)

	anim("KnockOut", target)

	var last_member := not target.is_enemy and filter_dead(Party.current).is_empty()

	if last_member:
		game_over(target)

	# Effects
	var particle: GPUParticles2D = target.node.get_node_or_null("Particle")
	outline(target)
	if particle:
		particle.emitting = true
		particle.process_material.gravity = Vector3(offsetize(120), 0, 0)
		particle.process_material.color = target.main_color

	var td := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)

	if target.node.get_node_or_null("Shadow"):
		td.tween_property(target.node.get_node("Shadow"), "modulate", Color.TRANSPARENT, 0.5)

	if target.disappear and target.node.get_node_or_null("Glow"):
		td.parallel().tween_property(target.node.get_node("Glow"), "energy", 0, 0.5)

	outline_remove(target)

	print(target.first_name, " was defeated")
	target.death_sequence_queued = false
	target.add_state("KnockedOut")

	await Event.wait(1)
	if not last_member:
		await play_death_banter(target)

	var death_sequence := death_sequence_for(target)

	if death_sequence != null and not target.cant_die:
		await run_battle_sequence(death_sequence, target, target, false)

	release_turn()

	# Wait for animations to finish, then delete character if applicable
	if is_instance_valid(target) and is_instance_valid(target.node):
		if target.disappear and not target.cant_die:
			queue_death_delete(target)


func queue_death_delete(target: Actor) -> void:
	while (
		is_instance_valid(target.node)
		and target.node.is_playing()
		and target.node.animation == "KnockOut"
	):
		await Event.wait()

	if is_instance_valid(target) and is_instance_valid(target.node):
		target.queue_delete = true
		target.node.hide()


## Pass a target to show a dramatic last hit animation
func game_over(target: Actor = null) -> void:
	hold_turn()
	Audio.fade_out_music(2)
	if target != null:
		await Event.wait(0.2)
		get_tree().paused = true
		CurrentChar.node.pause()
		target.node.pause()
		await screen_shake(20, 0.2)
		await Event.wait(0.7, false)
		CurrentChar.node.play()
		target.node.play()
		get_tree().paused = false
		await Event.wait(1, false)

	Loader.battle_bars(0)
	Transition.fade_in_out(Color.WHITE, 1, 0, 2)
	await Event.wait(3, false)

	print_rich("[color=cornflower-blue]Game over")

	if sequence.defeat_sequence != null and not sequence.defeat_sequence.steps.is_empty():
		await run_battle_sequence(sequence.defeat_sequence, Party.Leader, null, false)
	else:
		UI.game_over()


func delete_actor(target: Actor) -> void:
	if is_instance_valid(target) and is_instance_valid(target.node):
		target.node.queue_free()
		target.node = null

		if target.is_enemy:
			Troop.erase(target)
			TurnOrder.erase(target)


func slowmo(timescale := 0.5, time := 1.0) -> void:
	Engine.time_scale = timescale
	await Event.wait(time * timescale)
	Engine.time_scale = 1


## Returns the enemy faction or the party, depending on `enemies`.
## Optionally filters out defeated actors.
func get_faction(enemies: bool, filter_out_dead := true) -> Array[Actor]:
	var rtn: Array[Actor] = Troop if enemies else Party.current

	if filter_out_dead: rtn = filter_dead(rtn)
	return rtn


## The faction the given actor fights alongside.
func get_ally_faction(actor: Actor = CurrentChar, filter_out_dead := true) -> Array[Actor]:
	return get_faction(actor.is_enemy, filter_out_dead)


## The faction the given actor fights against.
func get_opposing_faction(actor: Actor = CurrentChar, filter_out_dead := true) -> Array[Actor]:
	return get_faction(not actor.is_enemy, filter_out_dead)


func get_target_faction(ab := CurrentAbility) -> Array[Actor]:
	match ab.target:
		Ability.T.AOE_ALLIES: return get_ally_faction(CurrentChar, !ab.can_target_dead)
		Ability.T.AOE_ENEMIES: return get_opposing_faction()
		_: return [CurrentTarget]


func get_any_faction(filter_out_dead := true) -> Array[Actor]:
	var rtn: Array[Actor]
	rtn.append_array(Party.current)
	rtn.append_array(Troop)
	if filter_out_dead: rtn = filter_dead(rtn)
	return rtn


func hp_sort(a: Actor, b: Actor) -> bool:
	return a.health < b.health

var t_glow: Tween


func anim(animation: String = "", chara: Actor = CurrentChar) -> void:
	if chara.node == null: return
	if chara.flip_h:
		chara.node.flip_h = true

	if not is_instance_valid(chara):
		battle_msg("seq_error")
		return

	if animation == "" or chara.has_state("KnockedOut"):
		if chara.dont_idle: return

		animation = chara.pose()

		if animation.is_empty() or animation not in chara.node.sprite_frames.get_animation_names():
			animation = "Idle"

		# Do not repeat playing pose animations
		if animation == chara.node.animation: return

	if animation not in chara.node.sprite_frames.get_animation_names():
		return

	if animation in chara.glow_anims and chara.glow_special != 0:
		t_glow = create_tween()
		chara.node.get_node("Glow").color = chara.main_color
		t_glow.tween_property(chara.node.get_node("Glow"), "energy", chara.glow_special, 0.3)
	elif chara.node.animation in chara.glow_anims and chara.glow_special != 0:

		if is_instance_valid(t_glow):
			t_glow.kill()

		t_glow = create_tween()
		chara.node.get_node("Glow").color = chara.main_color
		t_glow.tween_property(chara.node.get_node("Glow"), "energy", chara.glow_def, 0.3)

	chara.node.play(animation)

	pixel_perfectize(chara)
	print_rich("[color=cornflower-blue]Animation: ", animation)

	while chara.node and chara.node.is_playing() and chara.node.animation == animation:
		await Event.wait()


## Waits until a battle [AnimatedSprite2D] stops playing.
func await_anim(sprite: AnimatedSprite2D, animation := "", timeout := 10.0) -> void:
	if not is_instance_valid(sprite) or not sprite.is_playing(): return
	if not animation.is_empty() and sprite.animation != animation: return

	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)

	while (
		is_instance_valid(sprite)
		and sprite.is_playing()
		and(animation.is_empty() or sprite.animation == animation)
		and Time.get_ticks_msec() < deadline
	):
		await Event.wait()


func glow(amount: float = 1, time: float = 1, chara: Actor = CurrentChar) -> void:
	if is_instance_valid(t_glow):
		t_glow.kill()

	t_glow = create_tween()
	t_glow.tween_property(chara.node.get_node("Glow"), "energy", amount, time)


func pixel_perfectize(chara: Actor, xy: int = 0) -> void:
	if not is_instance_valid(chara.node.sprite_frames): return
	var frame := chara.node.sprite_frames.get_frame_texture(chara.node.animation, chara.node.frame)

	if frame == null: return
	if int(frame.get_size()[xy]) % 2 == 0:
		chara.node.offset[xy] = chara.offset[xy]
	else: chara.node.offset[xy] = chara.offset[xy] + 0.5

	if xy == 0: pixel_perfectize(chara, 1)


func focus_cam(chara: Actor, time: float = 0.5, offset: Variant = 30) -> void:
	if chara.node == null: return
	if offset is int:
		await move_cam(Vector2(chara.node.position.x + offsetize(offset, chara), chara.node.position.y / 2), time)
	elif offset is Vector2:
		move_cam(Vector2(chara.node.position.x, chara.node.position.y / 2) + Vector2(offsetize(offset.x, chara), offset.y), time)

var t_move_cam: Tween


func move_cam(pos: Vector2, time: float = -1) -> void:
	if Input.is_action_pressed("Dash") or time == 0:
		cam.position_smoothing_enabled = false
	else:
		cam.position_smoothing_enabled = true

	if time > 0:
		if is_instance_valid(t_move_cam):
			t_move_cam.kill()

		t_move_cam = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t_move_cam.tween_property(cam, "position", pos, time)
	else:
		cam.position = pos

	await Event.wait(time)

var t_zoom: Tween


func zoom(am: float = 5, time: float = 0.5, easing := Tween.EASE_IN_OUT) -> void:
	if is_instance_valid(t_zoom):
		t_zoom.kill()

	t_zoom = create_tween()
	t_zoom.set_ease(easing)
	t_zoom.set_trans(Tween.TRANS_CUBIC)
	t_zoom.tween_property(cam, "zoom", Vector2(am, am), time)
	await t_zoom.finished


func move(
	chara: Actor,
	pos: Vector2,
	time: float,
	mode: Tween.EaseType = Tween.EASE_IN_OUT,
	offset: Vector2 = Vector2.ZERO
) -> void:
	if is_instance_valid(chara) and chara.node != null:
		hide_state_effects(chara)
		var tm := create_tween()
		tm.set_ease(mode)
		tm.set_trans(Tween.TRANS_QUART)
		tm.tween_property(chara.node, "position", pos + offset, time)
		await tm.finished

	anim_done.emit()


func hide_state_effects(chara: Actor) -> void:
	if not is_instance_valid(chara) or chara.node == null: return
	for i in chara.node.get_children():
		if i is AnimatedSprite2D and i.name != "State":
			i.hide()


func show_state_effects(chara: Actor = null) -> void:
	var actors := TurnOrder if chara == null else [chara]

	for actor in actors:
		if not is_instance_valid(actor) or actor.node == null: continue
		for i in actor.node.get_children():
			if i is AnimatedSprite2D and i.name != "State":
				i.show()


#int(max(Query.calc_num(), target.max_hp*((Query.calc_num()*CurrentChar.magic)*0.02)))
func heal(
	target: Actor,
	amount: int = Query.calc_num() * int(CurrentChar.magic * CurrentChar.magic_multiplier)
) -> void:
	amount = min(amount, target.max_hp - target.health)
	target.add_health(amount)
	ui.targetFoc.emit(target)
	check_party.emit()
	Hud._check_party()
	pop_aura(target)
	pop_num(target, "+" + str(amount))


func remove_queued_states(chara: Actor) -> void:
	if not is_instance_valid(chara): return
	for state: State in chara.states.duplicate():
		if state.queue_remove:
			await chara.remove_state(state, null, true)

	if chara.states.is_empty() and chara.node != null: chara.node.get_node("State").play("None")


func pop_aura(target: Actor, time: float = 0.5) -> void:
	outline(target, Color.WHITE)
	await get_tree().create_timer(time).timeout
	await outline_remove(target)


func escape() -> void:
	print_rich("[color=cornflower-blue]Escaped")
	battle_result = Result.ESCAPE
	end_battle()


func end_battle() -> void:
	AwaitVictory = false
	var anim_start := Time.get_ticks_msec()

	while victory_anim_pending > 0 and Time.get_ticks_msec() - anim_start < 10000:
		await Event.wait()

	if victory_anim_pending > 0:
		push_warning("Victory animations did not finish before the battle reset")

	reset_all()
	canvas.get_node("Continue").hide()
	await Hud.preform_levelups()

	if not is_instance_valid(Global.room):
		finish_without_room()
		return

	Audio.fade_out_music()

	Hud.shrink()
	if sequence.Detransition or battle_result != Result.VICTORY:
		hide_victory_stuff()
		zoom(4)
		Loader.battle_bars(4)
		await get_tree().create_timer(0.5).timeout
		queue_free()
	else:
		var t := create_tween()
		t.set_ease(Tween.EASE_OUT)
		t.set_trans(Tween.TRANS_QUART)
		t.set_parallel()
		#Engine.time_scale = 0.1
		Global.room.setup_zoom(true)
		for i in TurnOrder:
			t.tween_property(i.node.get_node("Glow"), "energy", 0, 0.3)

		background.material = null
		t.tween_property(background, "modulate", Color.TRANSPARENT, 0.5)
		hide_victory_stuff()

	in_battle = false

	if is_instance_valid(Global.camera):
		Global.camera.position_smoothing_enabled = true

	if not is_instance_valid(Global.player):
		return

	for i in Global.room.followers:
		if i and Party.has_member_index(i.member):
			i.show()

	Global.player.set_anim("IdleRight")
	Global.player.dashing = false

	post_battle()

	Global.camera.make_current()
	act.free()
	queue_free()
	Global.battle_end.emit()


## Tears the battle down when it was run without an active room, such as the
## inspector preview. It skips the overworld handoff and frees the battle.
func finish_without_room() -> void:
	print_rich("[color=cornflower-blue]Battle ended without a room")
	in_battle = false
	Hud.battle_state(false)
	Hud.show_all(false, false)
	Loader.battle_bars(0)
	Global.controllable = true
	act.free()
	queue_free()
	Global.battle_end.emit()


## True while a dialogue opened by the battle (event, banter or sequence) is
## still on screen. The cutscene textbox that may have started the battle is
## ignored so it cannot keep the battle UI hidden or swallow its input.
static func battle_dialogue_open() -> bool:
	if Passive.is_open:
		var passive := Passive.current

		if is_instance_valid(passive) and passive.get_instance_id() != external_passive_id:
			return true

	if Textbox.is_open:
		var textbox := Textbox.current

		if is_instance_valid(textbox) and textbox.get_instance_id() != external_textbox_id:
			return true

	return false


## Marks the start of a battle dialogue or sequence that is holding the turn.
static func push_modal_dialogue() -> void:
	modal_dialogue_count += 1


## Marks the end of a turn-holding battle dialogue or sequence.
static func pop_modal_dialogue() -> void:
	modal_dialogue_count = maxi(0, modal_dialogue_count - 1)


## True while dialogue should take the battle menu away from the player. Only
## turn-holding battle dialogue counts, plus a cutscene textbox while it is
## actually showing a line and waiting for the player. A parked textbox (such as
## the one behind AlcineFollow) or a non-holding flavor passive must not hide
## the menu.
static func dialogue_blocks_battle() -> bool:
	if modal_dialogue_count > 0:
		return true

	if Textbox.is_open:
		var textbox := Textbox.current

		if is_instance_valid(textbox) and textbox.is_waiting_for_input:
			return true

	return false


static func post_battle() -> void:
	if battle_result == Result.ESCAPE:
		Global.player.position = Query.globalize(sequence.EscPosition)

	if is_instance_valid(attacker):
		if battle_result != Result.VICTORY:
			attacker.show()

		if sequence.DeleteAttacker and battle_result == 1:
			if Global.player.is_on_wall():
				Global.player.position = attacker.position

			if attacker is NPC: attacker.defeat()

	Global.controllable = false
	Loader.battle_bars(0)
	if is_instance_valid(Global.player):
		Global.player.show()
		Global.player.get_node("DirectionMarker/Finder/Shape").set_deferred("disabled", false)
		if Event.check_flag("Player/Flame"):
			Global.player.activate_flame()

	if sequence.return_control:
		# The victory banter (and any battle dialogue) can still be on screen
		# after the battle scene is freed. Do not hand the overworld back
		# while a battle dialogue is up. A cutscene textbox that started the
		# battle is not battle dialogue and must not block this.
		while battle_dialogue_open():
			await Event.wait()

		Hud.ui_visible = true
		Event.give_control(true)

	Hud.shrink()


func hide_victory_stuff() -> void:
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUART)
	t.set_parallel()
	for i in canvas.get_children():
		if i.name != "DottedBack":
			t.tween_property(i, "position:x", i.position.x + 500, 0.3)
			t.tween_property(i, "modulate", Color.TRANSPARENT, 0.3)

	t.tween_property(canvas.get_node("DottedBack"), "modulate", Color(0.188, 0.188, 0.188, 0), 0.5)


func reset_all() -> void:
	pending_traps.clear()
	for i in TurnOrder:
		for j: State in i.states.duplicate():
			if j.removed_on_battle_end: i.states.erase(j)

		i.attack_multiplier = 1
		i.defence_multiplier = 1
		i.magic_multiplier = 1
		i.speed_boost = 0

	for i in Party.members:
		if i.aura_default != Color.WHITE:
			i.main_color = i.aura_default
			i.aura_default = Color.WHITE

		i.health = max(i.health, 10)
		i.aura = max(i.aura, 5)


func victory_anim(chara: Actor) -> void:
	act.process_mode = Node.PROCESS_MODE_ALWAYS
	await clear_states(chara)
	await anim("Victory", chara)
	anim("VictoryLoop", chara)
	victory_anim_pending = maxi(0, victory_anim_pending - 1)


func victory_count_sp() -> void:
	await Event.wait(0.7, false)
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUINT)
	t.set_parallel()
	$Canvas/SPGain.show()
	t.tween_property($Canvas/SPGain, "position:x", 918, 0.5).from(1000)
	t.tween_property($Canvas/SPGain, "modulate",
		Color.WHITE, 0.5).from(Color.TRANSPARENT)

	t.tween_property($Canvas/SPGain, "size:x", 260, 0.5).from(1)
	t.tween_property($Canvas/SPGain/VBoxContainer/Text,
		"custom_minimum_size:x", 140, 0.5).from(1)

	for i in Party.current:
		var member := i as PartyMember

		if member != null:
			member.add_SP(totalSP)

	Hud._check_party()
	await Event.wait(0.5, false)
	var sp := totalSP
	t = create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUINT)
	t.tween_property(self, "count_sp", sp, 2).from(0)
	while $Canvas/SPGain/VBoxContainer/Number.text != str(sp):
		$Canvas/SPGain/VBoxContainer/Number.text = str(count_sp)
		await Event.wait()

	var dub: PanelContainer = $Canvas/SPGain.duplicate()
	$Canvas.add_child(dub)
	t = create_tween()
	t.set_parallel()
	t.tween_property(dub, "scale", Vector2(1.5, 1.5), 0.3)
	t.tween_property(dub, "modulate", Color.TRANSPARENT, 0.3)
	await Event.wait(0.3, false)
	dub.queue_free()


func victory(ignore_seq := false, canvas_layer := 1) -> void:
	if AwaitVictory: return
	print_rich("[color=cornflower-blue]Victory!")
	Action = true

	if sequence.victory_sequence != null and not ignore_seq:
		await run_battle_sequence(sequence.victory_sequence, Party.Leader, null, false)
		return

	if sequence.VictoryBanter != "":
		Passive.open("banter_victory", sequence.VictoryBanter)

	$Canvas.layer = canvas_layer
	battle_result = Result.VICTORY
	victory_music()

	victory_anim_pending = 0

	for i in Party.current:
		if i == null:
			continue

		victory_anim_pending += 1
		victory_anim(i)

	check_party.emit()
	enemy_ui.colapse_root()
	# end_battle() owns the reset. Doing it here races victory_anim()'s state
	# removal coroutines, which are still running.
	var t := create_tween()
	$Canvas/VictoryText.text = sequence.VictoryText
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUINT)
	t.set_parallel()
	enemy_ui.get_node("EnemyFocus").hide()
	$Canvas/TurnOrder.hide()
	$Canvas/VictoryText.add_theme_color_override("font_color", Color.WHITE)
	$Canvas/VictoryText.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT
	$Canvas/VictoryText.scale = Vector2(1.5, 1.5)
	Hud.expand(2)
	Loader.battle_bars(0)
	$Canvas/DottedBack.show()
	t.tween_property($Canvas/DottedBack, "modulate",
	Color(0.188, 0.188, 0.188, 0.8), 1).from(Color(0.188, 0.188, 0.188, 0))
	t.tween_property($Canvas/VictoryText, "position",
	Vector2(260, 50), 2).from(Vector2(1000, 50))
	t.tween_property($Canvas/VictoryText, "modulate",
	Color.WHITE, 2).from(Color.TRANSPARENT)
	t.tween_property(cam, "position", Vector2(-20, 0), 1)
	t.tween_property(cam, "zoom", Vector2(5, 5), 1)
	ObtainedItems.append_array(sequence.AdditionalItems)
	if totalSP != 0: await victory_count_sp()
	if not ObtainedItems.is_empty(): victory_show_items()
	$Canvas/TurnOrder.hide()
	$Canvas/Continue.show()
	$Canvas/Continue.icon = Controller.get_scheme().ConfirmIcon

	t = create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUINT)
	t.tween_property($Canvas/Continue, "position:x", 1060, 0.5).from(1500).set_delay(1)
	enemy_ui.colapse_root()
	AwaitVictory = true

	if is_instance_valid(Global.player) and not sequence.UseBackground:
		align_player_to_battle()


## Lines the overworld player and followers up with their battle sprites so the
## camera can be handed back seamlessly when the battle ends.
func align_player_to_battle() -> void:
	Global.player.global_position = act.get_node("Actor0").global_position

	for i in range(1, 4):
		if Party.has_member_index(i):
			Global.room.followers[i - 1].global_position = act.get_node("Actor" + str(i)).global_position

	Global.camera.position_smoothing_enabled = false
	Global.camera.global_position = cam.global_position
	Global.camera.enabled = true
	cam.enabled = false
	Global.camera.zoom = cam.zoom


func victory_music() -> void:
	if not Audio.bgm_player.playing: return
	if sequence.Music.victory_track != null:
		Audio.crossfade_music(sequence.Music.victory_track)
	elif sequence.Music.victory > 0:
		Audio.change_music_from_to(sequence.Music.track, sequence.Music.victory)
	else:
		Audio.fade_out_music(3)


func victory_show_items() -> void:
	for i in $Canvas/VictoryItems.get_children():
		i.modulate = Color.TRANSPARENT

	await Event.wait()
	$Canvas/VictoryItems/ItemTemp.hide()
	for i in ObtainedItems:
		if i:
			var dub: PanelContainer = $Canvas/VictoryItems/ItemTemp.duplicate()
			dub.get_node("Hbox/ItemName").text = i.name
			dub.get_node("Hbox/Icon").texture = i.icon
			Item.find_filename(i)
			Item.add_item(i, &"", false)
			dub.show()
			$Canvas/VictoryItems.add_child(dub)

	$Canvas/VictoryItems.show()
	for i in $Canvas/VictoryItems.get_children():
		var count := 1

		if !(i == $Canvas/VictoryItems/ItemTemp or i is Label or not i.visible):
			for j in $Canvas/VictoryItems.get_children():
				if !(j == $Canvas/VictoryItems/ItemTemp or j is Label or j == i):
					if i.get_node("Hbox/ItemName").text == j.get_node("Hbox/ItemName").text:
						count += 1
						i.get_node("Hbox/Count").text = "x" + str(count)
						j.hide()

		if count > 1: i.get_node("Hbox/Count").show()

	for i in $Canvas/VictoryItems.get_children():
		if !(i == $Canvas/VictoryItems/ItemTemp or i == null):
			var t := create_tween()
			t.set_ease(Tween.EASE_OUT)
			t.set_trans(Tween.TRANS_QUINT)
			t.set_parallel()
			t.tween_property(i, "modulate", Color.WHITE, 0.5).from(Color.TRANSPARENT)
			t.tween_property(i, "position:x", i.position.x, 0.5).from(i.position.x + 500)
			await Event.wait(0.5, false)


func miss(target: Actor = CurrentTarget) -> void:
	if target == null or not is_instance_valid(target) or target.node == null: return
	hold_turn()
	play_effect("Miss", target)
	var prev := target.node.position
	move(target, Vector2(target.node.position.x + offsetize(30), target.node.position.y), 0.3, Tween.EASE_OUT)
	pop_num(target, "Miss")
	if target.controllable or CurrentChar.controllable:
		Controller.rumble(0.3, 0, 0.3, 0.1)

	await Event.wait(0.5)

	if is_instance_valid(target) and target.node != null:
		await move(target, prev, 0.3)

	release_turn()


func _on_battle_ui_command() -> void:
	anim("Command")


func add_to_troop(en: Actor) -> Actor:
	en = en.duplicate()
	hold_turn()
	Troop.append(en)
	var dub := await create_actor_node(en, "Enemy" + str(Troop.size() - 1))
	TurnOrder.push_front(en)
	dub.offset = en.offset
	anim(&"Idle", en)
	en.health = en.max_hp
	en.aura = en.max_aura
	outline_remove(en)
	TurnOrder.sort_custom(speed_sort)
	TurnInd = TurnOrder.find(CurrentChar)
	position_sprites()
	sprite_init(en)
	focus_cam(en, 0.3)
	await Event.wait(1)
	fix_enemy_node_issues()
	position_sprites()
	turn_ui_init()
	release_turn()
	return en


## Returns the relation between the colors when an attacker is attacking a defender
func color_relation(offender: Color, defender: Color) -> Wheel.Relation:
	var affinity := Query.get_affinity(offender)
	var def := Query.get_affinity(defender)

	if def.hue in affinity.oposing_range: return Wheel.Relation.OP
	elif def.hue in affinity.weak_range: return Wheel.Relation.WEAK
	elif def.hue in affinity.resist_range or def.hue in affinity.near_range: return Wheel.Relation.RESIST
	else: return Wheel.Relation.N


func relation_to_dmg_modifier(relation: Wheel.Relation) -> float:
	var base: float
	var value_mod: float = remap(CurrentChar.main_color.v, 0, 1, 2, 1)

	if relation == Wheel.Relation.OP: base = 1.5 * value_mod
	elif relation == Wheel.Relation.WEAK: base = 1.25 * value_mod
	elif relation == Wheel.Relation.RESIST: base = 0.75
	else: return 1
	return round(base * 10) / 10


func relation_to_aura_dmg(relation: Wheel.Relation, dmg: int) -> int:
	print_rich("[color=cornflower-blue]Color value: ", CurrentChar.main_color.v)

	if relation == Wheel.Relation.OP: return int(dmg * CurrentChar.main_color.v)
	elif relation == Wheel.Relation.WEAK: return int(dmg * (CurrentChar.main_color.v / 2))
	else: return 0


func _on_battle_ui_item() -> void:
	await anim("Bag")
	if CurrentChar.node.animation == "Bag": anim("BagLoop")


func shake_actor(chara := CurrentTarget, amount: float = 2.0, repeat: int = 5, time: float = 0.03) -> void:
	if not is_instance_valid(chara.node): return
	for i in repeat:
		var t := create_tween()
		t.tween_property(chara.node, "position:x", amount, time).as_relative()
		t.tween_property(chara.node, "position:x", -amount * 2, time * 2).as_relative()
		t.tween_property(chara.node, "position:x", amount, time).as_relative()
		await t.finished


func stat_change(
	stat: StringName,
	amount: float,
	chara := CurrentChar,
	turns: int = 3
) -> void:
	var updown: String
	if amount > 0: updown = "Up"
	else: updown = "Down"

	match stat:
		&"Atk": chara.attack_multiplier += amount
		&"Mag": chara.magic_multiplier += amount
		&"Def": chara.defence_multiplier += amount

	var state := await chara.add_state(stat + updown, turns, CurrentChar)
	await Event.wait(1)
	state.parameter = amount
	pop_num(chara, stat_name(stat) +" x" + str(amount + 1), state.color)

	if updown == "Up":
		Audio.ui_sound("powerup")
	else: Audio.ui_sound("powerdown")

	print(chara.first_name, "'  ", stat, " was multiplied by ", str(amount + 1))


func stat_name(stat: StringName) -> String:
	match stat:
		&"Atk": return "Attack"
		&"Def": return "Defence"
		&"Mag": return "Magic"
		_: return "Stat"


func on_state_add(state: State, chara: Actor, effect := true, ctx: ActionSequenceContext = null) -> void:
	if chara.health != 0:
		add_state_effect(state, chara)
		await run_state_sequence(state.on_add, state, chara, state.inflicter, ctx)
		await Event.wait()
		if not state.is_stat_change and effect: pop_num(chara, state.name, state.color)


## Runs one of a State's hook sequences with the state owner as the target.
## [param caster] defaults to the owner; on-add sequences pass the inflicter so
## `Caster` still means the actor that applied the state.
func run_state_sequence(
	action_sequence: ActionSequence,
	state: State,
	chara: Actor,
	caster: Actor = null,
	base: ActionSequenceContext = null
) -> void:
	if action_sequence == null or action_sequence.steps.is_empty():
		return

	if chara == null or not is_instance_valid(chara) or action_runner == null:
		return

	await action_runner.run_sequence(action_sequence, _state_context(state, chara, caster, base))


func _state_context(
	state: State,
	chara: Actor,
	caster: Actor,
	base: ActionSequenceContext
) -> ActionSequenceContext:
	var ctx: ActionSequenceContext

	if base != null:
		ctx = base.duplicate_for_target(chara)
	else:
		ctx = ActionSequenceContext.new()
		ctx.battle = self
		ctx.runner = action_runner
		ctx.target = chara
		ctx.home_position = initial

	ctx.caster = caster if caster != null else chara
	ctx.target = chara
	ctx.last_state = state
	ctx.state_sequence = true
	return ctx


func add_state_effect(state: State, chara: Actor) -> void:
	if (
		chara.node.get_node_or_null(state.name) == null and
		chara.node.get_node("State").sprite_frames.has_animation(state.name)
	):
		var dub: AnimatedSprite2D = chara.node.get_node("State").duplicate()
		dub.name = state.name
		chara.node.add_child(dub)
		dub.show()
		dub.play(state.name)


func remove_state_effect(state: State, chara: Actor, ctx: ActionSequenceContext = null) -> void:
	if chara == null or chara.node == null:
		Global.check.emit()
		return

	# Inline states (defined directly inside an Ability, e.g. traps) have no .tres
	# file in database/States, so their visual uses the live state's display name.
	var visual := chara.node.get_node_or_null(state.name)

	if visual == null and state.filename != state.name:
		visual = chara.node.get_node_or_null(state.filename)

	if visual != null:
		visual.queue_free()

	await run_state_sequence(state.on_remove, state, chara, chara, ctx)
	# Refresh the HUD only after the removal effect has applied its changes.
	Global.check.emit()


func get_actor(codename: StringName, unsafe := false) -> Actor:
	if codename.is_empty(): return null
	for i in TurnOrder:
		if i.codename == codename: return i

	for i in Troop:
		if i.codename == codename: return i

	push_warning(codename + " actor not found")
	return null if unsafe else Party.Leader.duplicate()


func has_actor(codename: StringName) -> bool:
	return get_actor(codename, true) != null


func random_target(ab: Ability) -> Actor:
	if ab.target != Ability.T.SELF: print_rich("[color=cornflower-blue]Target decided randomly")
	match ab.target:
		Ability.T.SELF, Ability.T.AOE_ENEMIES, Ability.T.AOE_ALLIES:
			return CurrentChar

		Ability.T.ONE_ENEMY:
			var faction := get_opposing_faction(CurrentChar, !ab.can_target_dead)

			if faction.is_empty(): return null
			else: return faction.pick_random()

		Ability.T.ONE_ALLY:
			var faction := get_ally_faction(CurrentChar, !ab.can_target_dead)

			if faction.is_empty(): return null
			else: return faction.pick_random()

	return null


func fix_enemy_node_issues() -> void:
	var i := 0

	for j in Troop:
		if j == null: continue
		if act.get_node_or_null("Enemy" + str(i)):
			j.node = act.get_node_or_null("Enemy" + str(i))

		i += 1


func filter_actors_by_state(input: Array[Actor], state: String) -> Array[Actor]:
	var rtn: Array[Actor] = []

	for i in input:
		if i.has_state(state):
			rtn.append(i)

	return rtn


func filter_dead(arr: Array[Actor]) -> Array[Actor]:
	var warr: Array[Actor] = []

	for i in arr:
		if not i.has_state("KnockedOut") and i.health != 0: warr.append(i)

	return warr


func clear_states(target: Actor) -> void:
	for state: State in target.states.duplicate():
		await target.remove_state(state, null, true)


func aura_overwrite(tar: Actor, color: Color, turns: int = 1) -> void:
	# Keep the original aura when an overwrite is refreshed; otherwise the next
	# hue shift would remember the previous shifted color as the default.
	if not tar.has_state("AuraOverwrite"):
		tar.aura_default = tar.main_color

	tar.main_color = color
	Global.check.emit()
	var state := await tar.add_state("AuraOverwrite", turns)

	if state != null: state.color = color

	# The hue shift should be visible while the ability plays, not only when
	# the animation returns to Idle and the glow is refreshed.
	var glow_node := tar.node.get_node_or_null("Glow")

	if glow_node is PointLight2D:
		glow_node.color = color

	if tar.node.material.get_shader_parameter("new_color") != null:
		tar.node.material.set_shader_parameter("new_color", color)


func confusion_msg() -> void:
	var tar: Actor = CurrentChar.next_target

	if CurrentChar == tar:
		battle_msg("confusion_hit_self")
	elif tar in get_ally_faction(CurrentChar) and CurrentChar.next_move.target == Ability.T.ONE_ENEMY:
		battle_msg("confusion_hit_ally")
	elif CurrentChar.controllable:
		battle_msg("confusion_miss")


func follow_up_text() -> void:
	$Canvas/FollowUp.show()
	$Canvas/FollowUp/Text.position = Vector2(-1000, 600)
	var t := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)

	if CurrentChar.is_enemy:
		$Canvas/FollowUp.rotation_degrees = 15
		t.tween_property($Canvas/FollowUp/Text, "position:x", 100, 0.5)
		t.set_ease(Tween.EASE_IN)
		t.tween_property($Canvas/FollowUp/Text, "position:x", 1400, 0.5)
	else:
		$Canvas/FollowUp.rotation_degrees = -15
		t.tween_property($Canvas/FollowUp/Text, "position:x", 450, 0.5)
		t.set_ease(Tween.EASE_IN)
		t.tween_property($Canvas/FollowUp/Text, "position:x", 1400, 0.5)
