extends Node

const PROFILE_PATH = "user://local_profile.json"

var player_id: String = ""
var username: String = "Guest"


func _ready() -> void:
	load_profile()


func load_profile() -> void:
	if FileAccess.file_exists(PROFILE_PATH):
		var file = FileAccess.open(PROFILE_PATH, FileAccess.READ)
		if file == null:
			push_error("Could not open local profile.")
			return

		var data = JSON.parse_string(file.get_as_text())

		if data is Dictionary:
			if data.get("player_id") is String and data.get("username") is String:
				if not data["player_id"].is_empty():
					player_id = data["player_id"]
					username = data["username"]
					print("Loaded local profile: ", username)
					print("Player ID: ", player_id)
					return

		push_error("Local profile file is invalid.")
		return

	# First launch: create a new local identity.
	player_id = Crypto.new().generate_random_bytes(16).hex_encode()
	username = "Guest_" + player_id.substr(0, 6).to_upper()

	save_profile()
	print("Created new local profile: ", username)
	print("Player ID: ", player_id)


func save_profile() -> void:
	var file = FileAccess.open(PROFILE_PATH, FileAccess.WRITE)

	if file == null:
		push_error("Could not save local profile.")
		return

	var data = {
		"player_id": player_id,
		"username": username
	}

	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func set_username(new_username: String) -> void:
	if new_username.strip_edges().is_empty():
		return

	username = new_username.strip_edges()
	save_profile()
