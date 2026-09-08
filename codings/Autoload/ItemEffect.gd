extends Node
var item: ItemData


func use(item_data: ItemData, battle_target: Actor = null) -> void:
	item = item_data
	if not Battle.in_battle:
		if get_node_or_null("/root/MainMenu") == null: return
		$/root/MainMenu.stage = "using_item"
		var prevfoc := get_viewport().gui_get_focus_owner()
		get_viewport().gui_release_focus()
		match item.Use:
			ItemData.U.CUSTOM:
				await call(item.filename)
			ItemData.U.HEALING:
				await Hud.choose_member(item_data)
				return
			ItemData.U.INSPECT:
				await Textbox.open("inspect_item", item.Parameter)
		if prevfoc != null: prevfoc.grab_focus()
		Engine.time_scale = 1
		$/root/MainMenu.stage = "item"
	elif item.UsedInBattle:
		if battle_target == null: battle_target = Global.bt.CurrentChar
		battle_target.NextMove = item.BattleEffect


func _on_item_manager_return_member(mem: Actor) -> void:
	if item.Use == ItemData.U.HEALING:
		mem.add_health(int(item.Parameter))
	#Hud._on_shrink()
	Hud._check_party()
	Item.remove_item(item, "Con")
