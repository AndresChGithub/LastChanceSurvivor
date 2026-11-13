extends Control

# Simple post-login menu. World selection and multiplayer come later.
const WELCOME_SCENE: String = "res://Scenes/enter_screen.tscn"
const WORLD_SELECT_SCENE: String = "res://Scenes/WorldSelect.tscn"

@onready var account_label: Label = $Center/Panel/Margin/Menu/AccountLabel
@onready var status_label: Label = $Center/Panel/Margin/Menu/StatusLabel


func _ready() -> void:
	if not DatabaseManager.is_signed_in():
		# Never allow an unsigned-in user to continue into the game menus.
		get_tree().call_deferred("change_scene_to_file", WELCOME_SCENE)
		return

	account_label.text = "Signed in as " + str(DatabaseManager.current_player.get("username", "Unknown"))
	status_label.text = ""


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(WORLD_SELECT_SCENE)


func _on_join_multiplayer_pressed() -> void:
	status_label.text = "Join Multiplayer is coming later."


func _on_profile_pressed() -> void:
	status_label.text = "Player Profile is coming later."


func _on_settings_pressed() -> void:
	status_label.text = "Settings are coming later."


func _on_log_out_pressed() -> void:
	# Save any progress from the development world before signing out.
	if not DatabaseManager.save_current_account():
		status_label.text = "Could not save: " + DatabaseManager.last_error
		return

	DatabaseManager.sign_out()
	get_tree().change_scene_to_file(WELCOME_SCENE)


func _on_quit_pressed() -> void:
	if DatabaseManager.is_signed_in():
		if not DatabaseManager.save_current_account():
			status_label.text = "Could not save: " + DatabaseManager.last_error
			return
	get_tree().quit()
