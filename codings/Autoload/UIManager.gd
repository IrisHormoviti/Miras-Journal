extends Node


## Returns true if a UI with the given node name is currently open
func is_open(ui_name: String) -> bool:
	return has_node(ui_name) or get_tree().root.has_node(ui_name)


func get_open(ui_name: String) -> Node:
	if has_node(ui_name): return get_node(ui_name)
	elif get_tree().root.has_node(ui_name): return get_tree().root.get_node(ui_name)
	else: return null


func options(submenu := 0) -> void:
	if is_open("Options"): return
	var control := Global.controllable
	var opt: OptionsUI = (await Loader.load_res("uid://bh82q5qur5ppl")).instantiate()
	Global.controllable = control

	match submenu:
		1:
			opt.set_no_main()
			opt.save_managment()

		3:
			opt.set_no_main()
			opt.manual()

	add_child(opt)


func title_screen() -> void:
	if Global.room != null: Global.room.queue_free()
	if not is_open("Initializer"):
		var init: Node = (await Loader.load_res("uid://ds1hwdmholrjy")).instantiate()
		add_child(init)
	else: get_open("Initializer").focus()


func member_details(chara: Actor, menu := 0) -> void:
	if chara == null: return
	var dub: Node = (await Loader.load_res("uid://b7kxxkiuyhc4n")).instantiate()
	add_child(dub)
	dub.draw_character(chara, menu)


func complimentary_ui(chara: Actor) -> void:
	if chara == null: return
	var dub: Node = (await Loader.load_res("res://UI/Complimentary/ComplimentaryUI.tscn")).instantiate()
	add_child(dub)
	await Event.wait()
	dub.draw_character(chara)


func next_day_ui() -> void:
	add_child((await Loader.load_res("res://UI/Misc/DayChangeUi.tscn")).instantiate())


func alcine_naming() -> void:
	var scene: Node = (await Loader.load_res("uid://c0dgn2l164lj0")).instantiate()
	add_child(scene)
	await scene.start()


func veinet_map(cur: String) -> void:
	var Map: Node = (await Loader.load_res("uid://b31w3e1tiwp0y")).instantiate()
	add_child(Map)
	Map.focus_place(cur)


func intro_effect(ref: Node) -> void:
	var node: Node = (await Loader.load_res("uid://jrg5p2oev3io")).instantiate()
	Global.room.add_child(node)
	node.ref = ref
	node.animate()


func toast(string: String) -> void:
	if get_node_or_null("Toast"):
		get_node("Toast").free()

	print_rich("[color=orange]Toast: " + string)
	var tost: Node = (preload("res://UI/Misc/Toast.tscn")).instantiate()
	add_child.call_deferred(tost)
	tost.get_node("BoxContainer/Toast/Label").set_deferred("text", string)


func warning(text: String, label: String = "WARNING", awnser: Array[String] = ["No", "Yes"], color: Color = Color.hex(0xdc000eff)) -> int:
	print_rich("[color=orange]Warn: " + text)
	var tost: Node = (await Loader.load_res("res://UI/Misc/Warning.tscn")).instantiate()
	add_child(tost)
	await Event.wait()
	if is_instance_valid(tost):
		return await tost.ask_for_confirm(text, label, awnser, color)
	else: return false


func error(text: String, label: String = "ERROR") -> void:
	await warning(text, label, ["OK"])


func location_name(string: String) -> void:
	if get_node_or_null("LocationName"):
		get_node("LocationName").free()

	var tost: Node = (await Loader.load_res("res://UI/Misc/LocationName.tscn")).instantiate()
	add_child(tost)
	tost.get_node("Label").set_deferred("text", string)


func game_over() -> void:
	add_child((await Loader.load_res("res://UI/GameOver/GameOver.tscn")).instantiate())
