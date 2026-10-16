@tool
extends PopupPanel

signal close_updater

const TEMP_FILE = "user://update.zip"

var download_url: String = ""
var http_request: HTTPRequest = null
var is_actively_downloading: bool = false
var new_version: String = "0.0"

@onready var cancel_button: Button = %CancelButton
@onready var downloading: ProgressBar = %Downloading
@onready var install_button: Button = %InstallButton
@onready var title_label: Label = %Title
@onready var updating: HBoxContainer = %Updating


func _ready() -> void:
	_connect_signals()
	_set_defaults()
	_begin_update()


func _process(delta: float) -> void:
	if is_actively_downloading:
		downloading.value = http_request.get_downloaded_bytes() * 100 / http_request.get_body_size()


#region Signals
func _connect_signals() -> void:
	cancel_button.pressed.connect(_on_cancel_pressed)
	install_button.pressed.connect(_on_install_pressed)


func _on_cancel_pressed() -> void:
	DirAccess.remove_absolute(TEMP_FILE)
	title_label.text = "Canceling GodotSteam update"
	close_updater.emit()


func _on_download_request_completed(result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	http_request.request_completed.disconnect(_on_download_request_completed)
	http_request.queue_free()
	is_actively_downloading = false

	if result != HTTPRequest.RESULT_SUCCESS:
		printerr("Failed to download new GodotSteam version %s" % result)
		close_updater.emit()
		return

	_clear_interface()
	cancel_button.visible = true
	install_button.visible = true
	title_label.text = "Install %s update?" % new_version
	var zip_file: FileAccess = FileAccess.open(TEMP_FILE, FileAccess.WRITE)
	zip_file.store_buffer(body)
	zip_file.close()


func _on_install_pressed() -> void:
	print("Removing older GodotSteam %s plug-in" % Steam.get_godotsteam_version())
	title_label.text = "Unpacking update and installing"
	cancel_button.disabled = true
	install_button.disabled = true
	OS.move_to_trash(ProjectSettings.globalize_path("res://addons/godotsteam"))

	var zip_reader: ZIPReader = ZIPReader.new()
	zip_reader.open(TEMP_FILE)
	var files: PackedStringArray = zip_reader.get_files()

	var base_path := files[1]
	# Remove archive folder
	files.remove_at(0)
	# Remove assets folder
	files.remove_at(0)

	for path in files:
		var new_file_path: String = path.replace(base_path, "")
		if path.ends_with("/"):
			DirAccess.make_dir_recursive_absolute("res://addons/%s" % new_file_path)
		else:
			var file: FileAccess = FileAccess.open("res://addons/%s" % new_file_path, FileAccess.WRITE)
			file.store_buffer(zip_reader.read_file(path))

	zip_reader.close()
	restart_post_update()


func restart_post_update() -> void:
	title_label.text = "Update finished, restarting editor"
	DirAccess.remove_absolute(TEMP_FILE)
	EditorInterface.restart_editor(true)
#endregion


#region Updating
func _begin_update() -> void:
	if download_url.is_empty() or download_url == "":
		close_updater.emit()
		return
	is_actively_downloading = true

	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_download_request_completed)

	if http_request.request(download_url) != OK:
		printerr("Failed to request GodotSteam update")
		is_actively_downloading = false
		close_updater.emit()
		return
#endregion


#region Helpers
func _clear_interface() -> void:
	for this_component in updating.get_children():
		this_component.visible = false


func _set_defaults() -> void:
	title_label.text = "Downloading GodotSteam %s" % new_version
	_clear_interface()
	downloading.visible = true
	downloading.value = 0.0
#endregion
