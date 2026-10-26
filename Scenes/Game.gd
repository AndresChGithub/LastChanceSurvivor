
extends Node2D

@export var allow_guest_testing: bool = false

@onready var player: CharacterBody2D = $Player
@onready var status_label: Label = $CanvasLayer/HUD/VBoxContainer/StatusLabel
@onready var wood_label: Label = $CanvasLayer/HUD/VBoxContainer/WoodLabel

var guest_wood: int = 0


func _ready() -> void:
	var buttons = $CanvasLayer/HUD/VBoxContainer

	buttons.get_node("AddWoodButton").pressed.connect(_on_add_wood_pressed)
	buttons.get_node("SaveButton").pressed.connect(_on_save_pressed)
	buttons.get_node("LogoutButton").pressed.connect(_on_logout_pressed)

	var account = DatabaseManager.current_account

	if account == null:
		if allow_guest_testing:
			status_label.text = "Guest mode - progress is not saved"
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
		guest_wood += 10
		status_label.text = "Guest: added 10 wood"
	else:
		DatabaseManager.current_account.item_dict["wood"] += 10
		status_label.text = "Added 10 wood. Remember to save!"

	_update_wood_label()


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
	var wood: int = guest_wood

	if DatabaseManager.current_account != null:
		wood = DatabaseManager.current_account.item_dict["wood"]

	wood_label.text = "Wood: %d" % wood
