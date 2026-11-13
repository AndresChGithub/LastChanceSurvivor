extends Control

# Singleplayer world selection. Existing worlds are saved by DatabaseManager.
# The testing world is shown here even though get_owned_worlds() hides it.
const MAIN_MENU_SCENE: String = "res://Scenes/MainMenu.tscn"
const GAME_SCENE: String = "res://Scenes/Game.tscn"

@onready var account_label: Label = $Center/Panel/Outer/Layout/Header/AccountLabel
@onready var world_entries: VBoxContainer = $Center/Panel/Outer/Layout/Body/WorldColumn/WorldScroll/WorldEntries
@onready var selected_name: Label = $Center/Panel/Outer/Layout/Body/DetailsColumn/SelectedName
@onready var selected_details: Label = $Center/Panel/Outer/Layout/Body/DetailsColumn/SelectedDetails
@onready var world_name_input: LineEdit = $Center/Panel/Outer/Layout/Body/DetailsColumn/WorldNameInput
@onready var seed_input: LineEdit = $Center/Panel/Outer/Layout/Body/DetailsColumn/SeedInput
@onready var status_label: Label = $Center/Panel/Outer/Layout/StatusLabel
@onready var enter_button: Button = $Center/Panel/Outer/Layout/Footer/EnterButton

var _worlds: Array[Dictionary] = []
var _selected_world_id: String = ""


func _ready() -> void:
	if not DatabaseManager.is_signed_in():
		get_tree().call_deferred("change_scene_to_file", "res://Scenes/enter_screen.tscn")
		return

	account_label.text = "Account: " + str(DatabaseManager.current_player.get("username", "Unknown"))
	_refresh_worlds(DatabaseManager.current_world_id)


func _refresh_worlds(preferred_id: String = "") -> void:
	_worlds.clear()

	var test_id: String = "dev_" + DatabaseManager.get_current_player_uid()
	_worlds.append({
		"world_id": test_id,
		"world_name": "Testing World",
		"seed": Game_Data.seed,
		"is_development": true
	})

	for world in DatabaseManager.get_owned_worlds():
		var entry: Dictionary = world.duplicate(true)
		entry["is_development"] = false
		_worlds.append(entry)

	for child in world_entries.get_children():
		world_entries.remove_child(child)
		child.queue_free()

	var group := ButtonGroup.new()
	for world in _worlds:
		var world_id: String = str(world["world_id"])
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(0, 64)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 17)
		button.add_theme_color_override("font_color", Color("f4eee0"))
		button.add_theme_color_override("font_hover_color", Color("ffffff"))
		button.add_theme_stylebox_override("normal", _world_style(false))
		button.add_theme_stylebox_override("hover", _world_style(true))
		button.add_theme_stylebox_override("pressed", _world_style(true))
		button.add_theme_stylebox_override("hover_pressed", _world_style(true))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		if bool(world.get("is_development", false)):
			button.text = "  [TEST] Testing World  |  Seed " + str(world["seed"])
		else:
			button.text = "  " + str(world["world_name"]) + "  |  Seed " + str(world["seed"])
		button.pressed.connect(_select_world.bind(world_id))
		world_entries.add_child(button)

	if _worlds.is_empty():
		_selected_world_id = ""
		_update_selection_details()
		return

	var next_id: String = preferred_id
	var found: bool = false
	for world in _worlds:
		if str(world["world_id"]) == next_id:
			found = true
			break
	if not found:
		next_id = str(_worlds[0]["world_id"])
	_select_world(next_id)


func _world_style(is_highlighted: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("334b58") if is_highlighted else Color("23333d")
	style.border_color = Color("e1b56f") if is_highlighted else Color("435968")
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.content_margin_left = 12
	style.content_margin_right = 10
	return style


func _select_world(world_id: String) -> void:
	_selected_world_id = world_id
	for index in range(world_entries.get_child_count()):
		var button := world_entries.get_child(index) as Button
		if button != null and index < _worlds.size():
			button.set_pressed_no_signal(str(_worlds[index]["world_id"]) == world_id)
	_update_selection_details()


func _update_selection_details() -> void:
	enter_button.disabled = _selected_world_id.is_empty()
	for world in _worlds:
		if str(world["world_id"]) != _selected_world_id:
			continue
		selected_name.text = str(world["world_name"])
		var description: String = "Development save" if bool(world.get("is_development", false)) else "Singleplayer save"
		selected_details.text = description + "\nSeed: " + str(world["seed"])
		return
	selected_name.text = "No world selected"
	selected_details.text = "Select a world from the list."


func _on_create_world_pressed() -> void:
	var name_text: String = world_name_input.text.strip_edges()
	if name_text.is_empty():
		status_label.text = "Enter a name for the new world."
		return

	var world_seed: int
	var seed_text: String = seed_input.text.strip_edges()
	if seed_text.is_empty():
		world_seed = randi_range(1, 2147483647)
	elif not seed_text.is_valid_int():
		status_label.text = "Seed must be an integer, or left blank."
		return
	else:
		world_seed = int(seed_text)

	var new_id: String = DatabaseManager.create_world(name_text, world_seed)
	if new_id.is_empty():
		status_label.text = "Could not create world: " + DatabaseManager.last_error
		return

	world_name_input.clear()
	seed_input.clear()
	_refresh_worlds(new_id)
	status_label.text = "Created '" + name_text + "'. World seed generation hookup is next."


func _on_enter_pressed() -> void:
	if _selected_world_id.is_empty():
		status_label.text = "Choose a world first."
		return
	if not DatabaseManager.enter_world(_selected_world_id):
		status_label.text = "Could not open world: " + DatabaseManager.last_error
		return
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
