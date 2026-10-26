extends Control

@onready var username_input: LineEdit = $VBoxContainer/Username
@onready var password_input: LineEdit = $VBoxContainer/Password
@onready var status_label: Label = $VBoxContainer/StatusLabel


func good_password(password: String) -> String:
	return DatabaseManager.check_password(password)


func _on_button_button_down() -> void:
	var username: String = username_input.text.strip_edges()
	var password: String = password_input.text

	if username.is_empty():
		status_label.text = "Enter a username."
		return

	var password_result: String = good_password(password)
	if password_result != "good":
		status_label.text = password_result
		password_input.clear()
		password_input.placeholder_text = password_result
		return

	if DatabaseManager.register_account(username, password):
		status_label.text = "Account created! Click Go to Login."
		password_input.clear()
	else:
		status_label.text = DatabaseManager.last_error


func _on_go_to_login_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/login.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/enter_screen.tscn")
