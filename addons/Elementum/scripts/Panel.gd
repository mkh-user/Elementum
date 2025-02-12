@tool
extends Control
class_name Elementum_Panel

const LICENSE_LINK = "https://raw.githubusercontent.com/mkh-user/ElementumHost/refs/heads/main/LICENSE"
const ELEMENTS_LINK = "https://raw.githubusercontent.com/mkh-user/ElementumHost/refs/heads/main/elements.json"
const RAW_FILES_LINK = "https://raw.githubusercontent.com/mkh-user/ElementumHost/refs/heads/main/"
const ELEMENTS_PATH = "user://Elements List.json"
const BASE_ELEMET_PATH = "res://addons/Elementum/Downloads"

@export var search_bar: LineEdit
@export var filter_menu: OptionButton
@export var elements_list: ItemList
@export var reload: Button
@export var license: Button

var Downloader := preload("res://addons/Elementum/scripts/Downloader.gd")

## A reference to the list of scripts
var elements: Array = []


func _ready() -> void:
	search_bar.text_changed.connect(self._update_script_list.unbind(1))
	filter_menu.item_selected.connect(self._update_script_list.unbind(1))
	elements_list.item_selected.connect(self._on_elements_list_item_selected)
	reload.pressed.connect(self._load_elements)
	reload.icon = EditorInterface.get_base_control().get_theme_icon("Reload", "EditorIcons") # <- This line is commented for Signal Lens!
	license.pressed.connect(OS.shell_open.bind(LICENSE_LINK))
	self.custom_minimum_size = reload.size + Vector2(0, 100)
	_load_elements()
	_create_confirmation_dialog()


func _load_elements()-> void :
	var http_request: HTTPRequest = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(self._on_request_completed.bind(ELEMENTS_PATH))
	http_request.request(ELEMENTS_LINK)


func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, save_path: String) -> void:
	if response_code == 200:
		var file := FileAccess.open(save_path, FileAccess.WRITE)
		file.store_buffer(body)
		file.close()
		file = FileAccess.open(save_path, FileAccess.READ)
		var json_string := file.get_line()
		file.close()
		var json := JSON.new()
		var error := json.parse(json_string)
		if error:
			elements_list.clear()
			elements_list.add_item("Failed to parse elements list from server! Error {error} happend at line {line}.".format({"error": json.get_error_message(), "line": json.get_error_line()}), null, false)
			return
		elements = json.data
		_update_script_list()
	else:
		elements_list.clear()
		elements_list.add_item("Failed to load elements list from server!", null, false)
		match response_code:
			0:
				elements_list.add_item("ERR 0 : Cann't connect to the server!", null, false)
			403:
				elements_list.add_item("ERR 403 : Blocked from the server!", null, false)
			404:
				elements_list.add_item("ERR 404 : Cann't find request data!", null, false)


func _on_elements_list_item_selected(index: int) -> void:
	var script_info
	for script in elements:
		if elements_list.get_item_text(index).get_slice(" - ", 0) == script["name"].get_slice(".", 0):
			script_info = script
	var confirmation_dialog = $ConfirmationDialog
	confirmation_dialog.get_ok_button().text = "Download"
	confirmation_dialog.get_cancel_button().text = "Cancel"
	if confirmation_dialog.confirmed.is_connected(self._download_script):
		confirmation_dialog.confirmed.disconnect(self._download_script)
	confirmation_dialog.confirmed.connect(self._download_script.bind(script_info))
	confirmation_dialog.dialog_text = "Name: {name}\nType: {type}\n\nDescription: {description}".format(script_info)
	confirmation_dialog.popup_centered()


func _download_script(script_info: Dictionary) -> void:
	var downloader = Downloader.new()
	self.add_child(downloader)
	downloader.download_script(
			RAW_FILES_LINK + script_info.name, 
			BASE_ELEMET_PATH.path_join(script_info.type).path_join(script_info.name)
	)


func _update_script_list() -> void:
	elements_list.clear()
	var search_text: String = search_bar.text.to_snake_case()
	var selected_filter: String = filter_menu.get_item_text(filter_menu.selected).to_snake_case()
	var icon: Texture2D
	for script: Dictionary in elements:
		if (search_text == "" or script.name.to_snake_case().find(search_text) != -1) and (selected_filter == "all" or script.type.to_snake_case() == selected_filter):
			match script.type:
				"Node":
					icon = load("res://addons/Elementum/icons/N.svg")
				"Class":
					icon = load("res://addons/Elementum/icons/C.svg")
				"Library":
					icon = load("res://addons/Elementum/icons/L.svg")
			elements_list.add_item(script.name.erase(script.name.find(".gd"), 3) + " - " + script.description, icon)


func _create_confirmation_dialog() -> void:
	var confirmation_dialog := ConfirmationDialog.new()
	confirmation_dialog.name = "ConfirmationDialog"
	confirmation_dialog.dialog_autowrap = true
	add_child(confirmation_dialog)
