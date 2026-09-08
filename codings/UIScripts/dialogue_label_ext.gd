@tool
extends DialogueLabel
var soundfreq: int
var varience: float
@export var AudioPlayer: AudioStreamPlayer
var count: int = 0


func type_out_with_sound(sound: AudioStream, freq: int, vari: float) -> void:
	AudioPlayer.stream = sound
	soundfreq = freq
	varience = vari
	count = soundfreq - 1
	if get_parent().get_parent().get_parent().name != "Passive":
		match Global.settings.TextSpeed:
			1: soundfreq *= 2
			2:
				soundfreq *= 10
				play_sound(randf_range(0, 12))
	type_out()


func _on_spoke(letter: String, letter_index: int, speed: float) -> void:
	count += 1
	if count >= soundfreq:
		var letter_pitch := find_pitch(letter)
		play_sound(letter_pitch)


func play_sound(letter_pitch: float) -> void:
	if letter_pitch != 0:
		AudioPlayer.pitch_scale = remap(letter_pitch, 0, 12, -varience, varience) / 10 + 1
		AudioPlayer.play()
		count = 0
	else: count -= 1


func find_pitch(letter: String, repeat := true) -> float:
	match letter:
		"e": return 12.02
		"t": return 9.1
		"a": return 8.12
		"o": return 7.68
		"i": return 7.31
		"n": return 6.95
		"s": return 6.28
		"r": return 6.02
		"h": return 5.92
		"d": return 4.32
		"l": return 3.98
		"u": return 2.88
		"c": return 2.71
		"m": return 2.61
		"f": return 2.30
		"y": return 2.11
		"w": return 2.09
		"g": return 2.03
		"p": return 1.82
		"b": return 1.49
		"v": return 1.11
		"k": return 0.69
		"x": return 0.17
		"q": return 0.11
		"j": return 0.10
		"z": return 0.07
	if repeat and find_pitch(letter.to_lower(), false) != 0:
		return find_pitch(letter.to_lower(), false)
	else: return 0
