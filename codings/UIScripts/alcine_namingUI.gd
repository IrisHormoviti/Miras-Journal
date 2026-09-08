extends CanvasLayer
signal enter
var txt: String = ''
var word_list: Dictionary = load("res://database/Text/Misc/BannedNamingWords.json").data

@onready var textbox: LineEdit = $TextEdit
@onready var response: Label = $Error


func _ready() -> void:
	hide()


func start() -> void:
	get_tree().paused = false
	Hud.expanded = false
	show()
	$TextureRect.texture = await Loader.load_res(Party.get_member("Alcine").RenderArtwork)
	response.hide()
	textbox.grab_focus()
	textbox.set_caret_column(10)
	await enter
	queue_free()


func _on_text_edit_text_changed(text: String) -> void:
	if "\n" in text:
		textbox.text = text.replace("\n", "")
		return
	if text.length() > 10:
		response.text = "Bit too long, isn't it?"
		response.show()
		if text.length() > 10 and text.length() > txt.length():
			textbox.text = txt
			textbox.set_caret_column(20)
	else:
		response.hide()
	txt = textbox.text


func on_confirm(text: String) -> void:
	var textedit: LineEdit = textbox
	textedit.text = textedit.text.dedent()
	if textedit.text != "":
		textedit.text[0].to_upper()
	await Event.wait(0.03)
	textedit.set_caret_column(20)
	txt = textedit.text
	txt = txt.to_lower()
	if txt.length() > 10: return  #shouldn't this give a response?
	elif txt.length() == 1:
		response.text = "Let's try to be a little more creative."
		response.show()
	elif txt.length() == 0:
		textedit.text = "Alcine"
		on_confirm("Alcine")
	elif check_for_symbols():
		response.text = "Let's just keep it to letters."
		response.show()
	elif (  #check for banned words. The dictionary includes two top-level arrays
		word_list["unallowed_in"].any(func(word: String) -> bool: return word in txt)
		or
		word_list["unallowed_equal"].any(func(word: String) -> bool: return word == txt)
	):
		response.text = "No."
		response.show()
	elif (  #check if input matches a key in the responses_equal KVP
		txt in word_list["responses_equal"]
	):
		response.text = word_list["responses_equal"][txt]
		response.show()
	elif (  #checks if the keys contain the word in the input
		word_list["responses_in"].keys().any(func(k: String) -> bool: return k in txt)
		):
			#necessary evil to find WHICH key we hit that contains our word
		for key: String in word_list["responses_in"]:
			if key in txt:
				response.text = word_list["responses_in"][key]
				response.show()
	else:
		textedit.release_focus()
		Party.get_member("Alcine").FirstName = txt.capitalize()
		Textbox.open("naming", "what_about")
	await get_tree().process_frame
	textedit.set_caret_column(14)


func check_for_symbols() -> bool:
	var res := false
	for i in txt:
		if !(i.is_valid_identifier() or i == " ") or i == "_":
			res = true
	return res
