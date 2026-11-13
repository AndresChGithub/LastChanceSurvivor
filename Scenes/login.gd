extends Control

@onready var username_input: LineEdit = $VBoxContainer/Username
@onready var password_input: LineEdit = $VBoxContainer/Password
@onready var status_label: Label = $VBoxContainer/StatusLabel


func _on_login_pressed() -> void:
	var username: String = username_input.text.strip_edges()
	var password: String = password_input.text

	if DatabaseManager.login_account(username, password):
		get_tree().change_scene_to_file("res://Scenes/Game.tscn")
	else:
		status_label.text = DatabaseManager.last_error
		password_input.clear()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/enter_screen.tscn")
