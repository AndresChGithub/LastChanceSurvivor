extends Control

# Standalone testing scene. No changes to the existing sign-in UI are needed.

@onready var username_input: LineEdit = $MarginContainer/VBoxContainer/UsernameInput
@onready var create_button: Button = $MarginContainer/VBoxContainer/AccountButtons/CreateButton
@onready var login_button: Button = $MarginContainer/VBoxContainer/AccountButtons/SignInButton
@onready var logout_button: Button = $MarginContainer/VBoxContainer/AccountButtons/SignOutButton
@onready var wood_button: Button = $MarginContainer/VBoxContainer/ProgressButtons/WoodButton
@onready var score_button: Button = $MarginContainer/VBoxContainer/ProgressButtons/ScoreButton
@onready var move_button: Button = $MarginContainer/VBoxContainer/ProgressButtons/MoveButton
@onready var save_button: Button = $MarginContainer/VBoxContainer/SaveButtons/SaveButton
@onready var reload_button: Button = $MarginContainer/VBoxContainer/SaveButtons/ReloadButton
@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel
@onready var player_label: Label = $MarginContainer/VBoxContainer/PlayerLabel


func _ready() -> void:
	create_button.pressed.connect(_on_create)
	login_button.pressed.connect(_on_sign_in)
	logout_button.pressed.connect(_on_sign_out)
	wood_button.pressed.connect(_on_add_wood)
	score_button.pressed.connect(_on_add_score)
	move_button.pressed.connect(_on_move)
	save_button.pressed.connect(_on_save)
	reload_button.pressed.connect(_on_reload)

	status_label.text = "Ready. Create a fake account to begin."
	if not DatabaseManager.database_ready:
		status_label.text = "Database not ready. Check the Godot Output panel."
	_refresh_player_display()


func _get_typed_username() -> String:
	return username_input.text.strip_edges()


func _on_create() -> void:
	var username = _get_typed_username()
	if DatabaseManager.create_player(username):
		DatabaseManager.sign_in(username)
		status_label.text = "Created and signed in as %s." % username
	else:
		status_label.text = "Could not create account (empty/duplicate username or DB error)."
	_refresh_player_display()


func _on_sign_in() -> void:
	var username = _get_typed_username()
	if DatabaseManager.sign_in(username):
		status_label.text = "Signed in as %s. Saved values were loaded." % username
	else:
		status_label.text = "No account found for %s." % username
	_refresh_player_display()


func _on_sign_out() -> void:
	DatabaseManager.sign_out()
	status_label.text = "Signed out. Any unsaved changes were discarded."
	_refresh_player_display()


func _on_add_wood() -> void:
	if not _has_account():
		return
	DatabaseManager.current_account.item_dict["wood"] += 10
	status_label.text = "Added 10 wood (not saved yet)."
	_refresh_player_display()


func _on_add_score() -> void:
	if not _has_account():
		return
	DatabaseManager.current_account.score += 60
	status_label.text = "Added 60 seconds to score (not saved yet)."
	_refresh_player_display()


func _on_move() -> void:
	if not _has_account():
		return
	DatabaseManager.current_account.position += Vector2i(10, 5)
	status_label.text = "Moved player by (10, 5) (not saved yet)."
	_refresh_player_display()


func _on_save() -> void:
	if not _has_account():
		return
	if DatabaseManager.save_current_account():
		status_label.text = "Progress saved to SQLite!"
	else:
		status_label.text = "Save failed. See the Godot Output panel."
	_refresh_player_display()


func _on_reload() -> void:
	if not _has_account():
		return
	var username: String = DatabaseManager.current_account.username
	if DatabaseManager.sign_in(username):
		status_label.text = "Reloaded %s from SQLite. Unsaved changes are gone." % username
	else:
		status_label.text = "Reload failed."
	_refresh_player_display()


func _has_account() -> bool:
	if DatabaseManager.current_account == null:
		status_label.text = "Sign in or create an account first."
		return false
	return true


func _refresh_player_display() -> void:
	var account = DatabaseManager.current_account
	if account == null:
		player_label.text = "Current player: none"
		return

	player_label.text = (
        "Username: %s\nScore: %d seconds\nPosition: %s\n"
		+ "Wood: %d   Stone: %d   Fiber: %d"
	) % [
		account.username,
		account.score,
		str(account.position),
		account.item_dict["wood"],
		account.item_dict["stone"],
		account.item_dict["fiber"]
	]
