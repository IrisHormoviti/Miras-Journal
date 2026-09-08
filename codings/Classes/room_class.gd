extends Node2D
class_name Room

@export var title: String = "???"
@export var battleback_position: Vector2
@export var is_dungeon := true

var is_ready: bool = false
var index: int = 0
var camera_index: CameraIndex
var cam := Camera2D.new()
var followers: Array[CharacterBody2D] = []
var stairs: Array[Stair]
var markers: Array[Marker2D]
var layers: Array[TileMapLayer]
var current_subroom: SubRoom = null

var overwrite_zoom: float = 0:
	set(x):
		overwrite_zoom = x

		if x > 0:
			setup_zoom()

signal initialized


func _init() -> void:
	Global.room = self


func _ready() -> void:
	if position != Vector2.ZERO: push_warning(name, " is not at position 0,0")

	# Setup material
	material = preload("res://codings/Shaders/Pixelart.tres")
	texture_filter = CanvasItem.TEXTURE_FILTER_PARENT_NODE

	# Fetch special nodes
	for i in get_children():
		if i is TileMapLayer:
			layers.append(i)

		if i is Stair:
			stairs.append(i)

		if i is Marker2D:
			markers.append(i)

		if i is CameraIndex:
			if i.index == index:
				camera_index = i

	# Setup camera
	cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	cam.process_callback = Camera2D.CAMERA2D_PROCESS_IDLE
	cam.limit_smoothed = false
	cam.position_smoothing_enabled = false
	cam.position_smoothing_speed = 10
	cam.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(cam)
	setup_zoom()
	setup_camera_limits()

	# Setup subrooms
	if get_node_or_null("SubRoomBg"): $SubRoomBg.modulate = Color.TRANSPARENT

	# Spawn player
	var spawn_player := camera_index == null or camera_index.spawn_player

	if spawn_player:
		var Player := (preload("uid://sql6r7jv7fjq")).instantiate() as Mira
		add_child(Player)

		var dist := 30

		for i in range(1, 4):
			var follower := (preload("uid://da22xhcxygcjl")).instantiate() as Follower
			follower.name = "Follower" + str(i)
			follower.member = i
			follower.distance = dist
			followers.append(follower)
			add_child(follower)
			#match i:
				#1: follower.offset = 6
				#2: follower.offset = -6
				#3: follower.offset = 0

			dist += round(30 + dist / 4)

		move_child(Player, 0)

		# Wait for player to be ready
		await Player.initialized

		Global.player.global_position = camera_index.spawn_position as Vector2 if camera_index != null else Vector2.ZERO
		setup_z()
		setup_other_index_params()

		Global.player.collision(true)

		## Make controllable
		if Global.controllable:
			Hud.ui_visible = true

			for i in followers:
				i.dont_follow = false

	## Used for extending this script
	default()

	## Set this node's name to the codename
	name = codename()

	initialized.emit.call_deferred()

	await Event.wait(0.4, false)
	is_ready = true

	if Global.camera: Global.camera.position_smoothing_enabled = true

var t_zoom: Tween


func setup_camera_limits() -> void:
	if camera_index != null:
		cam.limit_left = camera_index.left
		cam.limit_right = camera_index.right
		cam.limit_top = camera_index.up
		cam.limit_bottom = camera_index.down


func setup_other_index_params() -> void:
	if camera_index != null:
		if camera_index.flame == 1:
			if not Event.f("FlameActive"): Global.player.activate_flame()
		elif camera_index.flame == -1:
			Event.remove_flag("FlameActive")

		Global.player.collision_layer = camera_index.layers
		Global.player.collision_mask = camera_index.layers


func setup_zoom(tween_zoom := false) -> void:
	var zoom := Vector2(4, 4)

	if is_instance_valid(t_zoom): t_zoom.kill()

	if overwrite_zoom > 0:
		zoom = Vector2(overwrite_zoom, overwrite_zoom)
	else:
		if camera_index != null and current_subroom == null:
			zoom = Vector2(camera_index.zoom, camera_index.zoom)
		elif current_subroom is SubRoom:
			zoom = Vector2(current_subroom.cam_zoom, current_subroom.cam_zoom)

	if tween_zoom:
		t_zoom = create_tween()
		t_zoom.set_ease(Tween.EASE_OUT)
		t_zoom.set_trans(Tween.TRANS_QUART)
		t_zoom.tween_property(cam, "zoom", zoom, 0.3)
	else:
		cam.zoom = zoom


func setup_z(z := -1) -> void:
	if not is_instance_valid(Global.player): return
	if z == -1: z = camera_index.z if camera_index != null else 1

	Global.player.z_index = z

	for i in followers:
		i.z_index = z


func default() -> void:
	pass


func get_z() -> int:
	if is_instance_valid(Global.player): return Global.player.z_index
	else: return camera_index.z if camera_index != null else 0


func map_to_local(vec: Vector2i) -> Vector2:
	return layers[0].map_to_local(vec)


func local_to_map(vec: Vector2) -> Vector2i:
	return layers[0].local_to_map(vec)

var t: Tween


func fade() -> void:
	if is_instance_valid(t): t.kill()
	t = create_tween()
	t.tween_property($SubRoomBg, "modulate", Color.WHITE, 0.3)
	for i in layers:
		i.collision_enabled = false

	await t.finished
	for i in layers:
		i.hide()


func unfade() -> void:
	if is_instance_valid(t): t.kill()
	t = create_tween()

	for i in layers:
		i.collision_enabled = true
		i.show()

	t.tween_property($SubRoomBg, "modulate", Color.TRANSPARENT, 0.3)


func _physics_process(delta: float) -> void:
	if has_node("SubRoomBg") and current_subroom != null:
		$SubRoomBg.position = cam.position


func go_to_subroom(subroom: String, fast := false) -> Vector2:
	var search_nodes := get_children()

	if has_node(^"Transfers"):
		search_nodes.append_array(get_node(^"Transfers").get_children())

	for i in search_nodes:
		if not is_instance_valid(i): continue
		if i is SubRoom and i.name == subroom:
			await i.transition(0)
			return i.cam_pos
		elif i is TransferZone and i.name == "Transfer" + subroom:
			return i.come_from()

	return Event.get_marker_pos(subroom)


func get_layers() -> Array[TileMapLayer]:
	return layers if current_subroom == null else current_subroom.Layers


func get_tile(pos: Vector2, layer: int = 1) -> TileData:
	var tilemap := get_layers()[layer]
	return tilemap.get_cell_tile_data(pos)


func get_terrain(coords: Vector2i) -> String:
	var tilemap_layers: Array[TileMapLayer] = get_layers().duplicate()
	tilemap_layers.reverse()
	for i in tilemap_layers:
		var data := i.get_cell_tile_data(coords)

		if is_instance_valid(data) and data.has_custom_data("TerrainType"):
			var terrain: String = data.get_custom_data("TerrainType")
			#print(i, terrain, terrain)
			if not terrain.is_empty():
				return terrain

	return "Generic"


func codename() -> String:
	return title.to_pascal_case()


func change_index(new_index: CameraIndex) -> void:
	index = new_index.index

	cam.limit_smoothed = true

	for i in get_children():
		if i is CameraIndex and i.index == index:
			camera_index = i

	setup_zoom(true)
	setup_camera_limits()
	setup_z()
	setup_other_index_params()
