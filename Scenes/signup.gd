extends Control

var username = ""
var password

var account_created = false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

#returns "good" if the password is valid, else returns an error message like "password too short" etc.
func good_password(password: String) -> String:
	if password.length() < 8:
		return "passwords must be at least 8 characters"
	if password == "password":
		return "choose a stronger password!"
	if password.to_lower() == password:
		return "password must contain a capital letter"
	return "good"
	



func _on_button_button_down() -> void:
	var username = $VBoxContainer/Username.text
	var temp_password = $VBoxContainer/Password.text
	
	if username && temp_password:
		var message: String = good_password(temp_password)
		if message != "good":
			$VBoxContainer/Password.add_theme_color_override("font_placeholder_color", Color.RED)
			$VBoxContainer/Password.placeholder_text = message
			$VBoxContainer/Password.text = ""
		else:
			# This is used to encrypt the password
			var password = $VBoxContainer/Password.text.sha256_text()
			
			#TODO make sure username is unique before making an account
			
			var user = Game_Data.User_Account.new(username, password)
			#TODO this user should now be added to the SQL database
