extends Node

const TEST_SEQUENCE := preload("res://tests/BattleTestSequence.tres")


func _ready() -> void:
	var room := Room.new()
	room.name = "BattleEntryTestRoom"
	room.camera_index = CameraIndex.new()
	room.camera_index.spawn_player = true
	room.camera_index.z = 3
	var layer := TileMapLayer.new()
	layer.tile_set = TileSet.new()
	room.add_child(layer)
	add_child(room)

	await room.initialized

	if not is_instance_valid(Global.player):
		push_error("Battle entry test did not spawn a player")
		get_tree().quit(1)
		return

	Global.player.set_physics_process(false)
	for follower in room.followers:
		follower.set_physics_process(false)

	Battle.attacker = null
	Battle.battle_advantage = 0
	await Battle.start(TEST_SEQUENCE)
	await get_tree().create_timer(4.0).timeout

	if Battle.current == null:
		push_error("Battle entry test did not create a battle")
		get_tree().quit(1)
		return

	if Battle.current.Troop.size() != TEST_SEQUENCE.Enemies.size():
		push_error("Battle entry test created the wrong troop")
		get_tree().quit(1)
		return

	print("BATTLE_ENTRY_TEST_READY troop=", Battle.current.Troop.size())
	get_tree().quit(0)
