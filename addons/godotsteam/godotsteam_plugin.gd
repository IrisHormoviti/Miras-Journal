@tool
class_name GodotSteamPlugin
extends EditorPlugin

const CHECK_UPDATES_SETTING: StringName = "steam/updates/godotsteam/check_for_updates"
const UPDATING = preload("uid://cbaxxe7y72c71")

var download_url: String = ""
var http_request: HTTPRequest = null
var link_changelog: String = "[url=https://godotsteam.com/changelog/gdextension/]changelog[/url]"
var link_website: String = "[url=https://godotsteam.com]website[/url]"
var new_version: String = ""
var update_panel: PopupPanel = null


func _enable_plugin() -> void:
	print("GodotSteam GDExtension updater functionality enabled")


func _disable_plugin() -> void:
	print("GodotSteam GDEXtension updater functionality disabled")
	remove_update_menu()


func _enter_tree() -> void:
	print_rich("GodotSteam v%s | %s | %s" % [Steam.get_godotsteam_version(), link_website, link_changelog])
	add_project_settings()
	check_for_updates()


func _exit_tree() -> void:
	remove_update_menu()


#region Add and remove things
func add_project_settings() -> void:
	# Used for the Updater looking for redist files and SteamCMD
	if ProjectSettings.has_setting(CHECK_UPDATES_SETTING):
		return
	ProjectSettings.set_setting(CHECK_UPDATES_SETTING, true)
	ProjectSettings.add_property_info({
		"name": CHECK_UPDATES_SETTING,
		"type": TYPE_BOOL
	})
	ProjectSettings.set_initial_value(CHECK_UPDATES_SETTING, true)
	ProjectSettings.set_as_basic(CHECK_UPDATES_SETTING, true)
	ProjectSettings.save()


func remove_update_menu() -> void:
	remove_tool_menu_item("Update to GodotSteam %s" % new_version)
#endregion


#region Version checking
func check_for_updates() -> void:
	if not ProjectSettings.get_setting(CHECK_UPDATES_SETTING):
		return
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_http_request_completed)
	# Using the Asset Library URL for now, will replace with version text from Codeberg
	if http_request.request("https://godotengine.org/asset-library/api/asset/2445") != OK:
		printerr("Failed to request GodotSteam plug-in remote current version")


func convert_version(version_string: String) -> int:
	return int(version_string.replace(".", "").rpad(4, "0"))


func _on_http_request_completed(result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	http_request.request_completed.disconnect(_on_http_request_completed)
	http_request.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS:
		return
	var response = JSON.parse_string(body.get_string_from_utf8())
	if response == null:
		return

	download_url = response.download_url
	new_version = response.version_string

	if convert_version(new_version) > convert_version(Steam.get_godotsteam_version()):
		print("New version of GodotSteam available, update in Project > Tools")
		add_tool_menu_item("Update to GodotSteam %s" % new_version, _on_update_pressed)
#endregion


#region Updating
func _on_close_updater() -> void:
	update_panel.queue_free()
	update_panel = null


func _on_update_pressed() -> void:
	print("Updating to GodotSteam %s" % new_version)
	update_panel = UPDATING.instantiate()
	update_panel.close_updater.connect(_on_close_updater)
	update_panel.popup_hide.connect(_on_close_updater)
	update_panel.download_url = download_url
	update_panel.new_version = new_version
	add_child(update_panel)
#endregion
