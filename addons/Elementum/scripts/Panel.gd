@tool
extends Control
class_name Elementum_Panel

@onready var search_bar := $V/H/SearchBar
@onready var filter_menu := $V/H/FilterMenu
@onready var elements_list := $V/Scroll/ItemList
@onready var reload := $V/H/Reload
@onready var license := $V/H/License

# A reference to the list of scripts
var elements := []

func _ready():
	search_bar.text_changed.connect(self._on_search_bar_text_changed)
	filter_menu.item_selected.connect(self._on_filter_menu_item_selected)
	elements_list.item_selected.connect(self._on_elements_list_item_selected)
	reload.pressed.connect(self._reload)
	license.pressed.connect(self._show_license)
	_load_elements()
	_create_confirmation_dialog()

func _show_license():
	OS.shell_open("https://raw.githubusercontent.com/mkh-user/ElementumHost/refs/heads/main/LICENSE")

func _reload():
	_load_elements()


func _load_elements():
	# Load initial script list (dummy data for example)
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(self._on_request_completed.bind(["res://addons/Elementum/elements.json"]))
	http_request.request("https://raw.githubusercontent.com/mkh-user/ElementumHost/refs/heads/main/elements.json")


func _on_request_completed(result, response_code, headers, body, save_path):
	if response_code == 200:
		save_path = save_path[0]
		var file = FileAccess.open(save_path, FileAccess.WRITE)
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


func _on_search_bar_text_changed(new_text):
	_update_script_list()


func _on_filter_menu_item_selected(index):
	_update_script_list()


func _on_elements_list_item_selected(index):
	var selected_script_index = elements_list.get_selected_items()[0]
	var script_info = elements[selected_script_index]
	var confirmation_dialog = $ConfirmationDialog
	confirmation_dialog.get_ok_button().text = "Download"
	confirmation_dialog.get_cancel_button().text = "Cancel"
	if confirmation_dialog.confirmed.is_connected(self._on_download_confirmed):
		confirmation_dialog.confirmed.disconnect(self._on_download_confirmed)
	confirmation_dialog.confirmed.connect(self._on_download_confirmed.bind(script_info))
	confirmation_dialog.dialog_text = "Name: " + script_info.name + "\n\nDescription: " + script_info.description
	confirmation_dialog.popup_centered()


func _download_script(script_info):
	var base_path = "res://addons/Elementum/Downloads/"
	var save_path = base_path + script_info.type + "/" + script_info.name
	var script_url = "https://raw.githubusercontent.com/mkh-user/ElementumHost/refs/heads/main/" + script_info.name
	var downloader = preload("res://addons/Elementum/scripts/Downloader.gd").new()
	self.add_child(downloader)
	downloader.download_script(script_url, save_path)

func _on_download_confirmed(script_info):
	_download_script(script_info)

func _update_script_list():
	elements_list.clear()
	var search_text = search_bar.text.to_snake_case()
	var selected_filter = filter_menu.get_item_text(filter_menu.selected).to_snake_case()
	var icon
	for script in elements:
		if (search_text == "" or script.name.to_snake_case().find(search_text) != -1) and (selected_filter == "all" or script.type.to_snake_case() == selected_filter):
			match script.type:
				"Node":
					icon = load("res://addons/Elementum/icons/N.svg")
				"Class":
					icon = load("res://addons/Elementum/icons/C.svg")
				"Library":
					icon = load("res://addons/Elementum/icons/L.svg")
			elements_list.add_item(script.name.erase(script.name.find(".gd"), 3) + " - " + script.description, icon)

func _create_confirmation_dialog():
	var confirmation_dialog = ConfirmationDialog.new()
	confirmation_dialog.name = "ConfirmationDialog"
	confirmation_dialog.dialog_autowrap = true
	add_child(confirmation_dialog)
