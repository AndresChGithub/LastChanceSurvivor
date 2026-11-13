
extends Node2D

@export var allow_guest_testing: bool = false

# Ids for the items in the top-right menu dropdown.
enum MenuItem { ACCOUNT, SAVE, SAVE_AND_EXIT, ADD_TEST_WOOD }

@onready var player: CharacterBody2D = $Player
@onready var status_label: Label = $CanvasLayer/HUD/StatusLabel
@onready var status_timer: Timer = $CanvasLayer/HUD/StatusTimer
@onready var menu_button: MenuButton = $CanvasLayer/HUD/MenuButton
@onready var wood_label: Label = $CanvasLayer/HUD/ResourceBar/HBoxContainer/WoodLabel
@onready var stone_label: Label = $CanvasLayer/HUD/ResourceBar/HBoxContainer/StoneLabel
@onready var fiber_label: Label = $CanvasLayer/HUD/ResourceBar/HBoxContainer/FiberLabel

var guest_resources: Dictionary[String, int] = {
	"wood": 0,
	"stone": 0,
	"fiber": 0
}


func _ready() -> void:
	# rendered_chunks is a static var, so it survives scene changes. The tree/
	# boulder/plant nodes from the last time this scene was open were freed
	# on logout, so forget them here or render_chunks() will skip every chunk.
	Game_Data.rendered_chunks.clear()

	player.resource_collected.connect(_on_resource_collected)
	status_timer.timeout.connect(status_label.hide)

	var account = DatabaseManager.current_account

	if account == null and not allow_guest_testing:
		get_tree().call_deferred(
			"change_scene_to_file",
			"res://Scenes/login.tscn"
		)
		return

	_build_menu(account)

	if account != null and account.position != Vector2i.ZERO:
		player.position = Vector2(account.position)

	_update_resource_labels()


func _build_menu(account: Game_Data.User_Account) -> void:
	var popup: PopupMenu = menu_button.get_popup()
	popup.clear()
	popup.add_theme_font_size_override("font_size", 12)
	popup.id_pressed.connect(_on_menu_item_pressed)

	# First row just shows who is playing; it can't be clicked.
	if account != null:
		popup.add_item("Signed in as " + account.username, MenuItem.ACCOUNT)
	else:
		popup.add_item("Admin mode (not saved)", MenuItem.ACCOUNT)
	popup.set_item_disabled(popup.get_item_index(MenuItem.ACCOUNT), true)
	popup.add_separator()

	if account != null:
		popup.add_item("Save", MenuItem.SAVE)
		popup.add_item("Save and Log Out", MenuItem.SAVE_AND_EXIT)
	else:
		popup.add_item("+10 Wood (test)", MenuItem.ADD_TEST_WOOD)
		popup.add_item("Exit to Menu", MenuItem.SAVE_AND_EXIT)


func _on_menu_item_pressed(id: int) -> void:
	match id:
		MenuItem.SAVE:
			_on_save_pressed()
		MenuItem.SAVE_AND_EXIT:
			_on_logout_pressed()
		MenuItem.ADD_TEST_WOOD:
			_on_add_wood_pressed()


# Shows a short message above the resource bar, then hides it.
func _show_status(message: String) -> void:
	status_label.text = message
	status_label.show()
	status_timer.start()


func _on_add_wood_pressed() -> void:
	if DatabaseManager.current_account == null:
		guest_resources["wood"] += 10
	else:
		DatabaseManager.current_account.item_dict["wood"] += 10

	_update_resource_labels()


func _on_resource_collected(resource_type: String, amount: int) -> void:
	if not guest_resources.has(resource_type):
		push_error("Unknown harvested resource: " + resource_type)
		return

	if DatabaseManager.current_account == null:
		guest_resources[resource_type] += amount
	else:
		DatabaseManager.current_account.item_dict[resource_type] += amount

	_update_resource_labels()


func _on_save_pressed() -> void:
	var account = DatabaseManager.current_account

	if account == null:
		_show_status("Admin progress is not saved")
		return

	account.position = Vector2i(
		roundi(player.position.x),
		roundi(player.position.y)
	)

	if DatabaseManager.save_current_account():
		_show_status("Progress saved")
	else:
		_show_status(DatabaseManager.last_error)


func _on_logout_pressed() -> void:
	var account = DatabaseManager.current_account

	if account != null:
		account.position = Vector2i(
			roundi(player.position.x),
			roundi(player.position.y)
		)

		if not DatabaseManager.save_current_account():
			_show_status(DatabaseManager.last_error)
			return

		DatabaseManager.sign_out()

	get_tree().change_scene_to_file("res://Scenes/enter_screen.tscn")


func _update_resource_labels() -> void:
	var resources := guest_resources

	if DatabaseManager.current_account != null:
		resources = DatabaseManager.current_account.item_dict

	wood_label.text = "Wood: %d" % resources["wood"]
	stone_label.text = "Stone: %d" % resources["stone"]
	fiber_label.text = "Fiber: %d" % resources["fiber"]
