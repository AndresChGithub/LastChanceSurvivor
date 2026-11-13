extends Node

# Autoload: DatabaseManager
# Local accounts live in user://last_chance_survivor.db.
# A player's permanent UID does not change when their username changes.
# Gameplay saving below is temporary; we will move progress into individual
# world saves when we build the world-selection system.

@export var db_path: String = "user://last_chance_survivor.db"

var db: SQLite
var database_ready: bool = false
var last_error: String = ""
var current_player: Dictionary = {}
var current_account: Game_Data.User_Account = null


func _ready() -> void:
	db = SQLite.new()
	db.path = db_path

	if not db.open_db():
		last_error = "Could not open the database."
		push_error(last_error + " " + db.error_message)
		return

	if not _prepare_players_table():
		db.close_db()
		return

	database_ready = true
	print("Database opened: ", ProjectSettings.globalize_path(db_path))


func _prepare_players_table() -> bool:
	# Fresh schema only. Delete the old test database before using this file.
	var sql = """
		CREATE TABLE IF NOT EXISTS players (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			player_uid TEXT NOT NULL UNIQUE,
			username TEXT NOT NULL UNIQUE,
			password_hash TEXT NOT NULL,
			password_salt TEXT NOT NULL,
			level INTEGER NOT NULL DEFAULT 1,
			coins INTEGER NOT NULL DEFAULT 0,
			score INTEGER NOT NULL DEFAULT 0,
			pos_x INTEGER NOT NULL DEFAULT 0,
			pos_y INTEGER NOT NULL DEFAULT 0,
			wood INTEGER NOT NULL DEFAULT 0,
			stone INTEGER NOT NULL DEFAULT 0,
			fiber INTEGER NOT NULL DEFAULT 0
		);
	"""

	if not db.query(sql):
		last_error = "Could not create the players table."
		push_error(last_error + " " + db.error_message)
		return false

	return true


func check_password(password: String) -> String:
	# Keep the existing rules used by signup.gd.
	if password.length() < 8:
		return "passwords must be at least 8 characters"
	if password.to_lower() == password:
		return "password must contain a capital letter"
	return "good"


func register_account(username: String, password: String) -> bool:
	last_error = ""
	username = username.strip_edges()

	if not database_ready:
		last_error = "Database is not ready."
		return false
	if username.is_empty():
		last_error = "Enter a username."
		return false

	var password_result: String = check_password(password)
	if password_result != "good":
		last_error = password_result
		return false

	var player_uid: String = Crypto.new().generate_random_bytes(16).hex_encode()
	var salt: String = Crypto.new().generate_random_bytes(16).hex_encode()
	var password_hash: String = _hash_password(password, salt)

	var sql = """
		INSERT OR IGNORE INTO players
			(player_uid, username, password_hash, password_salt)
		VALUES (?, ?, ?, ?);
	"""
	if not db.query_with_bindings(sql, [player_uid, username, password_hash, salt]):
		last_error = "Could not create account."
		push_error(last_error + " " + db.error_message)
		return false

	# INSERT OR IGNORE succeeds even if the username already exists.
	if not db.query("SELECT changes() AS inserted;"):
		last_error = "Could not verify account creation."
		return false
	if db.query_result.is_empty() or int(db.query_result[0]["inserted"]) == 0:
		last_error = "That username is already taken."
		return false

	return true


func login_account(username: String, password: String) -> bool:
	sign_out()
	last_error = "Incorrect username or password."

	if not database_ready:
		last_error = "Database is not ready."
		return false

	username = username.strip_edges()
	var sql = "SELECT password_hash, password_salt FROM players WHERE username = ?;"
	if not db.query_with_bindings(sql, [username]):
		last_error = "Could not check login details."
		push_error(last_error + " " + db.error_message)
		return false
	if db.query_result.is_empty():
		return false

	var saved_hash: String = str(db.query_result[0]["password_hash"])
	var salt: String = str(db.query_result[0]["password_salt"])
	var typed_hash: String = _hash_password(password, salt)
	if not Crypto.new().constant_time_compare(saved_hash.hex_decode(), typed_hash.hex_decode()):
		return false

	var player_data: Dictionary = get_player(username)
	if player_data.is_empty():
		last_error = "Could not load account."
		return false

	_load_player(player_data)
	last_error = ""
	return true


func get_player(username: String) -> Dictionary:
	if not database_ready:
		return {}

	# Intentionally omit password hashes and salts from the result.
	var sql = """
		SELECT id, player_uid, username, level, coins, score,
			pos_x, pos_y, wood, stone, fiber
		FROM players WHERE username = ?;
	"""
	if not db.query_with_bindings(sql, [username.strip_edges()]):
		push_error("Player lookup failed: " + db.error_message)
		return {}
	if db.query_result.is_empty():
		return {}

	return db.query_result[0].duplicate(true)


func get_player_by_uid(player_uid: String) -> Dictionary:
	if not database_ready or player_uid.is_empty():
		return {}

	var sql = """
		SELECT id, player_uid, username, level, coins, score,
			pos_x, pos_y, wood, stone, fiber
		FROM players WHERE player_uid = ?;
	"""
	if not db.query_with_bindings(sql, [player_uid]):
		push_error("Player UID lookup failed: " + db.error_message)
		return {}
	if db.query_result.is_empty():
		return {}

	return db.query_result[0].duplicate(true)


func get_current_player_uid() -> String:
	return str(current_player.get("player_uid", ""))


func is_signed_in() -> bool:
	return current_account != null and not current_player.is_empty()


func rename_current_account(new_username: String) -> bool:
	last_error = ""
	if not database_ready or not is_signed_in():
		last_error = "Sign in before changing your username."
		return false

	new_username = new_username.strip_edges()
	if new_username.is_empty():
		last_error = "Enter a username."
		return false
	if new_username == str(current_player["username"]):
		return true

	# Rename the account without changing its permanent player UID.
	var sql = "UPDATE OR IGNORE players SET username = ? WHERE id = ?;"
	if not db.query_with_bindings(sql, [new_username, current_player["id"]]):
		last_error = "Could not change username."
		push_error(last_error + " " + db.error_message)
		return false

	if not db.query("SELECT changes() AS updated;"):
		last_error = "Could not verify username change."
		return false
	if db.query_result.is_empty() or int(db.query_result[0]["updated"]) == 0:
		last_error = "That username is already taken."
		return false

	# Refresh the in-memory account and database record.
	var uid: String = get_current_player_uid()
	current_account.username = new_username
	current_player = get_player_by_uid(uid)
	return not current_player.is_empty()


func _load_player(player_data: Dictionary) -> void:
	# Preserve the existing object interface that Game.gd uses.
	var account = Game_Data.User_Account.new(str(player_data["username"]), "")
	account.score = int(player_data["score"])
	account.position = Vector2i(int(player_data["pos_x"]), int(player_data["pos_y"]))
	account.item_dict["wood"] = int(player_data["wood"])
	account.item_dict["stone"] = int(player_data["stone"])
	account.item_dict["fiber"] = int(player_data["fiber"])

	current_player = player_data
	current_account = account


func save_current_account() -> bool:
	# Temporary account-level progress storage for today's Game.tscn.
	# Later this will become world-specific, without changing player_uid.
	if not database_ready or not is_signed_in():
		last_error = "No signed-in account to save."
		return false

	var sql = """
		UPDATE players SET score = ?, pos_x = ?, pos_y = ?,
			wood = ?, stone = ?, fiber = ? WHERE id = ?;
	"""
	var values = [
		current_account.score,
		current_account.position.x,
		current_account.position.y,
		current_account.item_dict.get("wood", 0),
		current_account.item_dict.get("stone", 0),
		current_account.item_dict.get("fiber", 0),
		current_player["id"]
	]

	if not db.query_with_bindings(sql, values):
		last_error = "Could not save player progress."
		push_error(last_error + " " + db.error_message)
		return false

	var uid: String = get_current_player_uid()
	current_player = get_player_by_uid(uid)
	last_error = ""
	return not current_player.is_empty()


func reload_current_account() -> bool:
	if not is_signed_in():
		return false

	var player_data: Dictionary = get_player_by_uid(get_current_player_uid())
	if player_data.is_empty():
		return false

	_load_player(player_data)
	return true


func sign_out() -> void:
	current_player = {}
	current_account = null


func _hash_password(password: String, salt: String) -> String:
	# Salted SHA-256 is only for this local classroom prototype.
	# A real authentication service should use a slow password hash (Argon2id).
	return (salt + ":" + password).sha256_text()


func _exit_tree() -> void:
	if db != null and database_ready:
		db.close_db()
