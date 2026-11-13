extends Node

# Autoload: DatabaseManager
# Accounts have permanent UIDs. Each world has its own ID and seed.
# Player progress and harvested terrain are stored per world, not per account.
# Until the world-select menu exists, login opens a hidden development world.
# This is local-only authentication, not secure online identity verification.

@export var db_path: String = "user://last_chance_survivor.db"

var db: SQLite
var database_ready: bool = false
var last_error: String = ""
var current_player: Dictionary = {}
var current_account: Game_Data.User_Account = null
var current_world_id: String = ""
var current_world_seed: int = 1234


func _ready() -> void:
	db = SQLite.new()
	db.path = db_path

	if not db.open_db():
		last_error = "Could not open the database."
		push_error(last_error + " " + db.error_message)
		return

	if not _prepare_tables():
		db.close_db()
		return

	database_ready = true
	print("Database opened: ", ProjectSettings.globalize_path(db_path))


func _prepare_tables() -> bool:
	# Fresh schema only: no legacy database migrations.
	if not db.query("PRAGMA foreign_keys = ON;"):
		last_error = "Could not enable database foreign keys."
		return false

	var statements = [
		"""
		CREATE TABLE IF NOT EXISTS players (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			player_uid TEXT NOT NULL UNIQUE,
			username TEXT NOT NULL UNIQUE,
			password_hash TEXT NOT NULL,
			password_salt TEXT NOT NULL
		);
		""",
		"""
		CREATE TABLE IF NOT EXISTS worlds (
			world_id TEXT PRIMARY KEY,
			owner_uid TEXT NOT NULL REFERENCES players(player_uid),
			world_name TEXT NOT NULL,
			seed INTEGER NOT NULL,
			is_development INTEGER NOT NULL DEFAULT 0,
			created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
		);
		""",
		"""
		CREATE TABLE IF NOT EXISTS world_players (
			world_id TEXT NOT NULL REFERENCES worlds(world_id) ON DELETE CASCADE,
			player_uid TEXT NOT NULL,
			level INTEGER NOT NULL DEFAULT 1,
			coins INTEGER NOT NULL DEFAULT 0,
			score INTEGER NOT NULL DEFAULT 0,
			pos_x INTEGER NOT NULL DEFAULT 0,
			pos_y INTEGER NOT NULL DEFAULT 0,
			wood INTEGER NOT NULL DEFAULT 0,
			stone INTEGER NOT NULL DEFAULT 0,
			fiber INTEGER NOT NULL DEFAULT 0,
			PRIMARY KEY (world_id, player_uid)
		);
		""",
		"""
		CREATE TABLE IF NOT EXISTS world_terrain_changes (
			world_id TEXT NOT NULL REFERENCES worlds(world_id) ON DELETE CASCADE,
			terrain_key TEXT NOT NULL,
			pos_x INTEGER NOT NULL,
			pos_y INTEGER NOT NULL,
			PRIMARY KEY (world_id, terrain_key)
		);
		"""
	]

	for sql in statements:
		if not db.query(sql):
			last_error = "Could not prepare database tables."
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

	var uid: String = Crypto.new().generate_random_bytes(16).hex_encode()
	var salt: String = Crypto.new().generate_random_bytes(16).hex_encode()
	var password_hash: String = _hash_password(password, salt)
	var sql = "INSERT OR IGNORE INTO players (player_uid, username, password_hash, password_salt) VALUES (?, ?, ?, ?);"

	if not db.query_with_bindings(sql, [uid, username, password_hash, salt]):
		last_error = "Could not create account."
		push_error(last_error + " " + db.error_message)
		return false

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

	var sql = "SELECT password_hash, password_salt FROM players WHERE username = ?;"
	if not db.query_with_bindings(sql, [username.strip_edges()]):
		last_error = "Could not check login details."
		return false
	if db.query_result.is_empty():
		return false

	var saved_hash: String = str(db.query_result[0]["password_hash"])
	var salt: String = str(db.query_result[0]["password_salt"])
	var typed_hash: String = _hash_password(password, salt)
	if not Crypto.new().constant_time_compare(saved_hash.hex_decode(), typed_hash.hex_decode()):
		return false

	current_player = get_player(username)
	if current_player.is_empty():
		last_error = "Could not load account."
		return false

	current_account = Game_Data.User_Account.new(str(current_player["username"]), "")

	# Temporary compatibility: Game.tscn currently launches directly after login.
	# Every account gets its own hidden test world, separate from real world saves.
	var development_world_id: String = "dev_" + get_current_player_uid()
	if not _ensure_development_world(development_world_id):
		sign_out()
		return false
	if not enter_world(development_world_id):
		sign_out()
		return false

	last_error = ""
	return true


func get_player(username: String) -> Dictionary:
	if not database_ready:
		return {}
	var sql = "SELECT id, player_uid, username FROM players WHERE username = ?;"
	if not db.query_with_bindings(sql, [username.strip_edges()]):
		push_error("Player lookup failed: " + db.error_message)
		return {}
	if db.query_result.is_empty():
		return {}
	return db.query_result[0].duplicate(true)


func get_player_by_uid(player_uid: String) -> Dictionary:
	if not database_ready or player_uid.is_empty():
		return {}
	var sql = "SELECT id, player_uid, username FROM players WHERE player_uid = ?;"
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

	var sql = "UPDATE OR IGNORE players SET username = ? WHERE player_uid = ?;"
	if not db.query_with_bindings(sql, [new_username, get_current_player_uid()]):
		last_error = "Could not change username."
		return false
	if not db.query("SELECT changes() AS updated;"):
		last_error = "Could not verify username change."
		return false
	if db.query_result.is_empty() or int(db.query_result[0]["updated"]) == 0:
		last_error = "That username is already taken."
		return false

	current_account.username = new_username
	current_player = get_player_by_uid(get_current_player_uid())
	return not current_player.is_empty()


func _ensure_development_world(world_id: String) -> bool:
	# The development world's seed matches the generator's current fixed seed.
	var sql = "INSERT OR IGNORE INTO worlds (world_id, owner_uid, world_name, seed, is_development) VALUES (?, ?, ?, ?, 1);"
	if not db.query_with_bindings(sql, [world_id, get_current_player_uid(), "Development World", Game_Data.seed]):
		last_error = "Could not create development world."
		push_error(last_error + " " + db.error_message)
		return false
	return true


func create_world(world_name: String, seed: int) -> String:
	# Future World Select menu will call this. It does NOT start Game.tscn yet.
	last_error = ""
	if not database_ready or not is_signed_in():
		last_error = "Sign in before creating a world."
		return ""
	world_name = world_name.strip_edges()
	if world_name.is_empty():
		last_error = "Enter a world name."
		return ""

	var world_id: String = Crypto.new().generate_random_bytes(16).hex_encode()
	var sql = "INSERT INTO worlds (world_id, owner_uid, world_name, seed) VALUES (?, ?, ?, ?);"
	if not db.query_with_bindings(sql, [world_id, get_current_player_uid(), world_name, seed]):
		last_error = "Could not create world."
		push_error(last_error + " " + db.error_message)
		return ""
	return world_id


func get_owned_worlds() -> Array[Dictionary]:
	# The hidden development world does not appear in the normal world list.
	var worlds: Array[Dictionary] = []
	if not database_ready or not is_signed_in():
		return worlds
	var sql = "SELECT world_id, world_name, seed, created_at FROM worlds WHERE owner_uid = ? AND is_development = 0 ORDER BY created_at DESC;"
	if not db.query_with_bindings(sql, [get_current_player_uid()]):
		push_error("Could not list worlds: " + db.error_message)
		return worlds
	for row in db.query_result:
		worlds.append(row.duplicate(true))
	return worlds


func enter_world(world_id: String) -> bool:
	# Currently for locally owned worlds only. Multiplayer clients later need
	# a host-authorized join flow; their IDs must not grant automatic access.
	last_error = ""
	if not database_ready or not is_signed_in():
		last_error = "Sign in before loading a world."
		return false

	var sql = "SELECT world_id, seed FROM worlds WHERE world_id = ? AND owner_uid = ?;"
	if not db.query_with_bindings(sql, [world_id, get_current_player_uid()]):
		last_error = "Could not look up world."
		return false
	if db.query_result.is_empty():
		last_error = "This world does not belong to the current account."
		return false
	var world_seed: int = int(db.query_result[0]["seed"])

	# Don't silently throw away unsaved progress when changing worlds.
	if not current_world_id.is_empty() and current_world_id != world_id:
		if not save_current_account():
			return false

	var membership_sql = "INSERT OR IGNORE INTO world_players (world_id, player_uid) VALUES (?, ?);"
	if not db.query_with_bindings(membership_sql, [world_id, get_current_player_uid()]):
		last_error = "Could not prepare player for world."
		return false

	var progress_sql = "SELECT score, pos_x, pos_y, wood, stone, fiber FROM world_players WHERE world_id = ? AND player_uid = ?;"
	if not db.query_with_bindings(progress_sql, [world_id, get_current_player_uid()]):
		last_error = "Could not load player progress."
		return false
	if db.query_result.is_empty():
		last_error = "Player progress is missing."
		return false
	var progress: Dictionary = db.query_result[0].duplicate(true)

	var terrain_sql = "SELECT pos_x, pos_y FROM world_terrain_changes WHERE world_id = ?;"
	if not db.query_with_bindings(terrain_sql, [world_id]):
		last_error = "Could not load harvested terrain."
		return false
	var terrain_rows: Array = db.query_result.duplicate(true)

	if current_world_id != world_id:
		_clear_chunk_caches()
	current_world_id = world_id
	current_world_seed = world_seed
	current_account.score = int(progress["score"])
	current_account.position = Vector2i(int(progress["pos_x"]), int(progress["pos_y"]))
	current_account.item_dict["wood"] = int(progress["wood"])
	current_account.item_dict["stone"] = int(progress["stone"])
	current_account.item_dict["fiber"] = int(progress["fiber"])
	current_account.broken_terrain.clear()
	for row in terrain_rows:
		var pos = Vector2i(int(row["pos_x"]), int(row["pos_y"]))
		current_account.broken_terrain[pos] = true

	return true


func get_current_world_seed() -> int:
	return current_world_seed


func save_current_account() -> bool:
	# Uses existing Game.gd API, but writes into the ACTIVE WORLD.
	last_error = ""
	if not database_ready or not is_signed_in() or current_world_id.is_empty():
		last_error = "No signed-in player and world to save."
		return false

	if not db.query("BEGIN TRANSACTION;"):
		last_error = "Could not begin saving."
		return false

	var sql = """
		UPDATE world_players SET score = ?, pos_x = ?, pos_y = ?,
			wood = ?, stone = ?, fiber = ? WHERE world_id = ? AND player_uid = ?;
	"""
	var values = [
		current_account.score,
		current_account.position.x,
		current_account.position.y,
		current_account.item_dict.get("wood", 0),
		current_account.item_dict.get("stone", 0),
		current_account.item_dict.get("fiber", 0),
		current_world_id,
		get_current_player_uid()
	]
	if not db.query_with_bindings(sql, values):
		db.query("ROLLBACK;")
		last_error = "Could not save player progress."
		push_error(last_error + " " + db.error_message)
		return false

	var terrain_sql = "INSERT OR IGNORE INTO world_terrain_changes (world_id, terrain_key, pos_x, pos_y) VALUES (?, ?, ?, ?);"
	for pos in current_account.broken_terrain:
		if not db.query_with_bindings(terrain_sql, [current_world_id, _terrain_key(pos), pos.x, pos.y]):
			db.query("ROLLBACK;")
			last_error = "Could not save harvested terrain."
			push_error(last_error + " " + db.error_message)
			return false

	if not db.query("COMMIT;"):
		db.query("ROLLBACK;")
		last_error = "Could not finish saving."
		return false

	return true


func reload_current_account() -> bool:
	if not is_signed_in() or current_world_id.is_empty():
		return false
	return enter_world(current_world_id)


func is_terrain_broken(world_pos: Vector2i) -> bool:
	return current_account != null and current_account.broken_terrain.has(world_pos)


func mark_terrain_broken(world_pos: Vector2i) -> void:
	# Saved to world_terrain_changes when save_current_account() runs.
	if current_account != null and not current_world_id.is_empty():
		current_account.broken_terrain[world_pos] = true


func _terrain_key(world_pos: Vector2i) -> String:
	# Position key supports the current tree.gd. Later the world generator
	# should provide an ID based on chunk + generation index instead.
	return "pos:%d:%d" % [world_pos.x, world_pos.y]


func sign_out() -> void:
	current_player = {}
	current_account = null
	current_world_id = ""
	current_world_seed = Game_Data.seed
	_clear_chunk_caches()


func _clear_chunk_caches() -> void:
	# The world scene itself must still be reloaded when entering another world.
	Game_Data.loaded_chunks.clear()
	Game_Data.rendered_chunks.clear()


func _hash_password(password: String, salt: String) -> String:
	# Only for the local classroom prototype, NOT real online authentication.
	return (salt + ":" + password).sha256_text()


func _exit_tree() -> void:
	if db != null and database_ready:
		db.close_db()
