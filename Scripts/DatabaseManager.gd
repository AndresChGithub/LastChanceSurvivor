extends Node

# Local testing database. This runs as an Autoload called DatabaseManager.
# It does not provide real password authentication or multiplayer security.

var db: SQLite
var database_ready: bool = false
var current_player: Dictionary = {}
var current_account: Game_Data.User_Account = null


func _ready() -> void:
	db = SQLite.new()
	db.path = "user://last_chance_survivor.db"

	if not db.open_db():
		push_error("SQLite open failed: " + db.error_message)
		return

	if not _prepare_players_table():
		db.close_db()
		return

	database_ready = true
	print("SQLite ready: ", ProjectSettings.globalize_path(db.path))


func _prepare_players_table() -> bool:
	# Keep level and coins from the earlier simple database example.
	# The other columns match the fields in Game_Data.User_Account.
	var sql = """
        CREATE TABLE IF NOT EXISTS players (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL UNIQUE,
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
		push_error("Could not create players table: " + db.error_message)
		return false

	# A previous DatabaseManager may already have made a players table
	# with only id, username, level, and coins. Add missing columns.
	if not db.query("PRAGMA table_info(players);"):
		push_error("Could not inspect players table: " + db.error_message)
		return false

	var existing_columns: Array[String] = []
	for row in db.query_result:
		existing_columns.append(str(row["name"]))

	var default_values = {
		"level": 1,
		"coins": 0,
		"score": 0,
		"pos_x": 0,
		"pos_y": 0,
		"wood": 0,
		"stone": 0,
		"fiber": 0
	}

	for column in default_values:
		if column not in existing_columns:
			# Column names come only from this hardcoded dictionary.
			var add_column_sql = (
                "ALTER TABLE players ADD COLUMN %s INTEGER NOT NULL DEFAULT %d;"
				% [column, default_values[column]]
			)
			if not db.query(add_column_sql):
				push_error("Could not add column %s: %s" % [column, db.error_message])
				return false

	return true


func create_player(username: String) -> bool:
	if not database_ready:
		return false

	username = username.strip_edges()
	if username.is_empty():
		return false

	# The UNIQUE constraint prevents duplicate usernames.
	var sql = "INSERT OR IGNORE INTO players (username) VALUES (?);"
	if not db.query_with_bindings(sql, [username]):
		push_error("Player creation failed: " + db.error_message)
		return false

	# Check if the INSERT inserted a new record, not an ignored duplicate.
	if not db.query("SELECT changes() AS inserted;"):
		push_error("Could not check insert result: " + db.error_message)
		return false

	return int(db.query_result[0]["inserted"]) == 1


func get_player(username: String) -> Dictionary:
	if not database_ready:
		return {}

	var sql = "SELECT * FROM players WHERE username = ?;"
	if not db.query_with_bindings(sql, [username.strip_edges()]):
		push_error("Player lookup failed: " + db.error_message)
		return {}

	if db.query_result.is_empty():
		return {}

	return db.query_result[0].duplicate(true)


func sign_in(username: String) -> bool:
	var player_data = get_player(username)
	if player_data.is_empty():
		return false

	# Convert a saved SQL row into your teammate's existing data class.
	var account = Game_Data.User_Account.new(str(player_data["username"]), "")
	account.score = int(player_data["score"])
	account.position = Vector2i(
		int(player_data["pos_x"]),
		int(player_data["pos_y"])
	)
	account.item_dict["wood"] = int(player_data["wood"])
	account.item_dict["stone"] = int(player_data["stone"])
	account.item_dict["fiber"] = int(player_data["fiber"])

	current_player = player_data
	current_account = account
	return true


func save_current_account() -> bool:
	if not database_ready or current_account == null:
		return false

	var sql = """
        UPDATE players SET
            score = ?, pos_x = ?, pos_y = ?,
            wood = ?, stone = ?, fiber = ?
        WHERE id = ?;
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
		push_error("Could not save progress: " + db.error_message)
		return false

	current_player = get_player(current_account.username)
	return not current_player.is_empty()


func sign_out() -> void:
	current_player = {}
	current_account = null


func _exit_tree() -> void:
	if db != null and database_ready:
		db.close_db()
