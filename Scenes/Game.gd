
extends Node2D

@export var allow_guest_testing: bool = false

@onready var player: CharacterBody2D = $Player
@onready var status_label: Label = $CanvasLayer/HUD/VBoxContainer/StatusLabel
@onready var wood_label: Label = $CanvasLayer/HUD/VBoxContainer/WoodLabel
@onready var stone_label: Label = $CanvasLayer/HUD/VBoxContainer/StoneLabel
@onready var fiber_label: Label = $CanvasLayer/HUD/VBoxContainer/FiberLabel

var crafting := Crafting.new()
var guest_resources: Dictionary[String, int] = {
	"wood": 0,
	"stone": 0,
	"fiber": 0,
	"knife": 0,
	"axe": 0,
	"string": 0,
	"bow": 0,
	"pickaxe": 0,
	"hoe": 0
}


func _ready() -> void:
	# rendered_chunks is a static var, so it survives scene changes. The tree/
	# boulder/plant nodes from the last time this scene was open were freed
	# on logout, so forget them here or render_chunks() will skip every chunk.
	Game_Data.rendered_chunks.clear()

	var buttons = $CanvasLayer/HUD/VBoxContainer

	buttons.get_node("AddWoodButton").pressed.connect(_on_add_wood_pressed)
	buttons.get_node("SaveButton").pressed.connect(_on_save_pressed)
	buttons.get_node("LogoutButton").pressed.connect(_on_logout_pressed)
	player.resource_collected.connect(_on_resource_collected)
	for item in crafting.recipe_book:
		var button := buttons.get_node("Crafting/" + item.name.capitalize()) as Button
		button.pressed.connect(_on_craft_pressed.bind(item.name))

	var account = DatabaseManager.current_account

	if account == null:
		if allow_guest_testing:
			status_label.text = "Admin mode - progress is not saved"
			_update_wood_label()
			return

		get_tree().call_deferred(
			"change_scene_to_file",
            "res://Scenes/login.tscn"
		)
		return

	if account.position != Vector2i.ZERO:
		player.position = Vector2(account.position)

	status_label.text = "Playing as " + account.username
	_update_wood_label()


func _on_add_wood_pressed() -> void:
	if DatabaseManager.current_account == null:
		guest_resources["wood"] += 10
		status_label.text = "Guest: added 10 wood"
	else:
		DatabaseManager.current_account.item_dict["wood"] += 10
		status_label.text = "Added 10 wood. Remember to save!"

	_update_wood_label()


func _on_resource_collected(resource_type: String, amount: int) -> void:
	if not guest_resources.has(resource_type):
		push_error("Unknown harvested resource: " + resource_type)
		return

	if DatabaseManager.current_account == null:
		guest_resources[resource_type] += amount
		status_label.text = "Guest: collected %d %s" % [amount, resource_type]
	else:
		DatabaseManager.current_account.item_dict[resource_type] += amount
		status_label.text = "Collected %d %s. Remember to save!" % [amount, resource_type]

	_update_resource_labels()


func _on_craft_pressed(item_name: String) -> void:
	var inventory: Dictionary = guest_resources
	if DatabaseManager.current_account != null:
		inventory = DatabaseManager.current_account.item_dict

	if not crafting.craft(item_name, inventory):
		status_label.text = "Not enough resources to craft " + item_name
		return

	status_label.text = "Crafted 1 " + item_name
	_update_resource_labels()


func _on_save_pressed() -> void:
	var account = DatabaseManager.current_account

	if account == null:
		status_label.text = "Guest progress cannot be saved"
		return

	account.position = Vector2i(
		roundi(player.position.x),
		roundi(player.position.y)
	)

	if DatabaseManager.save_current_account():
		status_label.text = "Progress saved."
	else:
		status_label.text = DatabaseManager.last_error


func _on_logout_pressed() -> void:
	var account = DatabaseManager.current_account

	if account != null:
		account.position = Vector2i(
			roundi(player.position.x),
			roundi(player.position.y)
		)

		if not DatabaseManager.save_current_account():
			status_label.text = DatabaseManager.last_error
			return

		DatabaseManager.sign_out()

	get_tree().change_scene_to_file("res://Scenes/enter_screen.tscn")


func _update_wood_label() -> void:
	_update_resource_labels()


func _update_resource_labels() -> void:
	var resources := guest_resources

	if DatabaseManager.current_account != null:
		resources = DatabaseManager.current_account.item_dict

	wood_label.text = "Wood: %d" % resources["wood"]
	stone_label.text = "Stone: %d" % resources["stone"]
	fiber_label.text = "Fiber: %d" % resources["fiber"]
