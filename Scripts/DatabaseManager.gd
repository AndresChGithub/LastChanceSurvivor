extends Node

# This script runs once as an Autoload named DatabaseManager.
# It stores local player accounts and progress in SQLite.
# Online multiplayer authentication will need a trusted server later.

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
	var sql = """
		CREATE TABLE IF NOT EXISTS players (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			username TEXT NOT NULL UNIQUE,
			password_hash TEXT NOT NULL DEFAULT '',
			password_salt TEXT NOT NULL DEFAULT '',
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

	# Older test databases do not have every column. Add missing ones.
	if not db.query("PRAGMA table_info(players);"):
		last_error = "Could not inspect the players table."
		return false

	var existing_columns: Array[String] = []
	for row in db.query_result:
		existing_columns.append(str(row["name"]))

	var required_columns = {
		"password_hash": "TEXT NOT NULL DEFAULT ''",
		"password_salt": "TEXT NOT NULL DEFAULT ''",
		"level": "INTEGER NOT NULL DEFAULT 1",
		"coins": "INTEGER NOT NULL DEFAULT 0",
		"score": "INTEGER NOT NULL DEFAULT 0",
		"pos_x": "INTEGER NOT NULL DEFAULT 0",
		"pos_y": "INTEGER NOT NULL DEFAULT 0",
		"wood": "INTEGER NOT NULL DEFAULT 0",
		"stone": "INTEGER NOT NULL DEFAULT 0",
		"fiber": "INTEGER NOT NULL DEFAULT 0"
	}

	for column in required_columns:
		if column not in existing_columns:
			var alter_sql = "ALTER TABLE players ADD COLUMN %s %s;" % [
				column, required_columns[column]
			]
			if not db.query(alter_sql):
				last_error = "Could not add database column: " + column
				push_error(last_error + " " + db.error_message)
				return false

	return true


func check_password(password: String) -> String:
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
	if check_password(password) != "good":
		last_error = check_password(password)
		return false

	var salt: String = Crypto.new().generate_random_bytes(16).hex_encode()
	var password_hash: String = _hash_password(password, salt)

	var sql = "INSERT OR IGNORE INTO players (username, password_hash, password_salt) VALUES (?, ?, ?);"
	if not db.query_with_bindings(sql, [username, password_hash, salt]):
		last_error = "Could not create account."
		push_error(db.error_message)
		return false

	# INSERT OR IGNORE does not report duplicates as SQL errors.
	if not db.query("SELECT changes() AS inserted;"):
		last_error = "Could not verify account creation."
		return false
	if int(db.query_result[0]["inserted"]) == 0:
		last_error = "That username is already taken."
		return false

	return true


func login_account(username: String, password: String) -> bool:
	last_error = "Incorrect username or password."
	sign_out()

	if not database_ready:
		last_error = "Database is not ready."
		return false

	username = username.strip_edges()
	var sql = "SELECT password_hash, password_salt FROM players WHERE username = ?;"
	if not db.query_with_bindings(sql, [username]):
		push_error("Login lookup failed: " + db.error_message)
		return false
	if db.query_result.is_empty():
		return false

	var saved_hash: String = str(db.query_result[0]["password_hash"])
	var salt: String = str(db.query_result[0]["password_salt"])
	if saved_hash.is_empty() or salt.is_empty():
		# Accounts from the old passwordless test cannot log in.
		return false

	var typed_hash: String = _hash_password(password, salt)
	if not Crypto.new().constant_time_compare(saved_hash.hex_decode(), typed_hash.hex_decode()):
		return false

	var player_data = get_player(username)
	if player_data.is_empty():
		return false

	_load_player(player_data)
	last_error = ""
	return true


func get_player(username: String) -> Dictionary:
	if not database_ready:
		return {}

	# Only return gameplay fields, not password credentials.
	var sql = """
		SELECT id, username, level, coins, score, pos_x, pos_y, wood, stone, fiber
		FROM players WHERE username = ?;
	"""
	if not db.query_with_bindings(sql, [username.strip_edges()]):
		push_error("Player lookup failed: " + db.error_message)
		return {}
	if db.query_result.is_empty():
		return {}

	return db.query_result[0].duplicate(true)


func _load_player(player_data: Dictionary) -> void:
	var account = Game_Data.User_Account.new(str(player_data["username"]), "")
	account.score = int(player_data["score"])
	account.position = Vector2i(int(player_data["pos_x"]), int(player_data["pos_y"]))
	account.item_dict["wood"] = int(player_data["wood"])
	account.item_dict["stone"] = int(player_data["stone"])
	account.item_dict["fiber"] = int(player_data["fiber"])

	current_player = player_data
	current_account = account


func save_current_account() -> bool:
	if not database_ready or current_account == null:
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

	current_player = get_player(current_account.username)
	last_error = ""
	return not current_player.is_empty()


func reload_current_account() -> bool:
	if current_account == null:
		return false
	var player_data = get_player(current_account.username)
	if player_data.is_empty():
		return false
	_load_player(player_data)
	return true


func sign_out() -> void:
	current_player = {}
	current_account = null


func _hash_password(password: String, salt: String) -> String:
	# A salted SHA-256 hash is enough to demonstrate this local prototype.
	# It is NOT suitable for production authentication. Use Argon2id or
	# another proper password-hashing system on the server in Sprint 2.
	return (salt + ":" + password).sha256_text()


func _exit_tree() -> void:
	if db != null and database_ready:
		db.close_db()
