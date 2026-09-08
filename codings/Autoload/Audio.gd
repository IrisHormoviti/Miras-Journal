extends AudioStreamPlayer

var bgm_player: AudioStreamPlayer = AudioStreamPlayer.new()
var music_queue: Array[AudioStream] = []
var music_request_id := 0


func _ready() -> void:
	bus = "UI"
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(bgm_player)
	bgm_player.bus = "Music"
	bgm_player.finished.connect(_music_finished)


func cursor_sound(dont_force := false) -> void:
	if not (dont_force and playing):
		stream = preload("res://sound/SFX/cursor.wav")
		play()


func buzzer_sound() -> void:
	stream = preload("res://sound/SFX/buzzer.ogg")
	play()


func confirm_sound() -> void:
	stream = preload("res://sound/SFX/confirm.ogg")
	play()


func cancel_sound() -> void:
	stream = preload("res://sound/SFX/Quit.ogg")
	play()


func item_sound() -> void:
	stream = preload("res://sound/SFX/item.ogg")
	play()


func ui_sound(string: String) -> void:
	stream = await Loader.load_res("res://sound/SFX/" + string + ".ogg")
	play()


func change_music(track: AudioStream) -> void:
	var request_id := randi()
	music_request_id = request_id

	bgm_player.stream = track
	bgm_player.play()


func change_music_from_to(track: AudioStream, from: float = 0, to: float = 0) -> void:
	bgm_player.stream = track
	bgm_player.play(from)
	var request_id := randi()
	music_request_id = request_id

	if to != 0:
		while bgm_player.stream == track and bgm_player.get_playback_position() <= to:
			await get_tree().process_frame

		if music_request_id == request_id:
			stop_music()


func queue_music(track: AudioStream) -> void:
	if bgm_player.playing:
		music_queue.append(track)
	else: change_music(track)


func _music_finished() -> void:
	if not music_queue.is_empty():
		bgm_player.stream = music_queue.pop_front()
		bgm_player.play()


func get_music_title() -> String:
	if bgm_player.playing:
		var title := bgm_player.stream.resource_path
		title = title.get_file().trim_suffix("."+title.get_extension())
		return title
	else:
		return ""


func stop_music() -> void:
	bgm_player.stream_paused = true
	music_queue.clear()
	bgm_player.volume_linear = 1


func fade_out_music(time := 1) -> void:
	var t := create_tween()
	t.tween_property(bgm_player, "volume_linear", 0, time)
	await t.finished
	stop_music()
