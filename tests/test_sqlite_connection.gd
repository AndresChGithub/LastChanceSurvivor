extends "res://tests/test_case.gd"
## Verifies the project is really wired up to SQLite through DatabaseManager.
## Every write test uses its own throwaway .db file, never the real save file.

const MANAGER_SCRIPT = "res://Scripts/DatabaseManager.gd"
const EXPECTED_COLUMNS = [
	"id", "username", "level", "coins", "score",
	"pos_x", "pos_y", "wood", "stone", "fiber",
]

var tree: SceneTree
var test_db_path: String
var manager: Node


func before_each() -> void:
	test_db_path = "user://test_%d_%d.db" % [Time.get_ticks_usec(), randi()]


func after_each() -> void:
	_close_manager()
	var file := ProjectSettings.globalize_path(test_db_path)
	if FileAccess.file_exists(file):
		DirAccess.remove_absolute(file)


func _open_manager() -> Node:
	var node: Node = load(MANAGER_SCRIPT).new()
	node.db_path = test_db_path
	tree.root.add_child(node)  # triggers _ready(), which opens the DB
	return node


func _close_manager() -> void:
	if is_instance_valid(manager):
		tree.root.remove_child(manager)  # _exit_tree() closes the DB
		manager.free()
	manager = null


func _column_names(node: Node) -> Array[String]:
	var names: Array[String] = []
	node.db.query("PRAGMA table_info(players);")
	for row in node.db.query_result:
		names.append(str(row["name"]))
	return names


# --- Is SQLite hooked up at all? ---------------------------------------------

func test_sqlite_extension_is_loaded() -> void:
	check(ClassDB.class_exists("SQLite"), "godot-sqlite GDExtension did not load (SQLite class missing)")


func test_database_manager_is_registered_as_autoload() -> void:
	check(ProjectSettings.has_setting("autoload/DatabaseManager"),
		"DatabaseManager is not in Project Settings > Autoload")
	var live: Node = tree.root.get_node_or_null("DatabaseManager")
	check(live != null, "DatabaseManager autoload node missing from the scene tree")
	if live:
		check(live.get_script().resource_path == MANAGER_SCRIPT,
			"autoload points at the wrong script: " + live.get_script().resource_path)
		check(live.database_ready, "the game's DatabaseManager autoload failed to open its database")


func test_opens_database_and_creates_file_on_disk() -> void:
	manager = _open_manager()
	check(manager.database_ready, "database_ready should be true after _ready()")
	check(FileAccess.file_exists(ProjectSettings.globalize_path(test_db_path)),
		"no .db file was written to disk")


func test_players_table_has_expected_columns() -> void:
	manager = _open_manager()
	var columns := _column_names(manager)
	for column in EXPECTED_COLUMNS:
		check(column in columns, "players table is missing column '%s'" % column)


# --- Account rows ------------------------------------------------------------

func test_create_player_inserts_row_with_defaults() -> void:
	manager = _open_manager()
	check(manager.create_player("alice"), "create_player('alice') returned false")
	var row: Dictionary = manager.get_player("alice")
	check(not row.is_empty(), "alice not found after create_player")
	if not row.is_empty():
		check_eq(row["username"], "alice", "username")
		check_eq(int(row["level"]), 1, "default level")
		check_eq(int(row["score"]), 0, "default score")
		check_eq(int(row["wood"]), 0, "default wood")


func test_duplicate_username_is_rejected() -> void:
	manager = _open_manager()
	check(manager.create_player("bob"), "first create should succeed")
	check(not manager.create_player("bob"), "second create with same name should fail")
	check(not manager.create_player("  bob  "), "same name with extra spaces should fail")
	manager.db.query("SELECT COUNT(*) AS n FROM players WHERE username = 'bob';")
	check_eq(int(manager.db.query_result[0]["n"]), 1, "rows for 'bob'")


func test_blank_username_is_rejected() -> void:
	manager = _open_manager()
	check(not manager.create_player(""), "empty username should fail")
	check(not manager.create_player("    "), "whitespace-only username should fail")


func test_username_is_stored_literally_not_run_as_sql() -> void:
	manager = _open_manager()
	var sneaky := "x'); DROP TABLE players; --"
	check(manager.create_player(sneaky), "create with quote characters should succeed")
	check(not manager.get_player(sneaky).is_empty(), "username with quotes should round-trip")
	check(manager.db.query("SELECT COUNT(*) FROM players;"), "players table should still exist")


func test_sign_in_unknown_user_fails() -> void:
	manager = _open_manager()
	check(not manager.sign_in("nobody"), "sign_in for a missing user should fail")
	check(manager.current_account == null, "current_account should stay null")


# --- Data actually persists --------------------------------------------------

func test_progress_survives_closing_and_reopening_database() -> void:
	manager = _open_manager()
	manager.create_player("carol")
	check(manager.sign_in("carol"), "sign_in after create")
	manager.current_account.score = 120
	manager.current_account.position = Vector2i(15, -7)
	manager.current_account.item_dict["wood"] = 30
	manager.current_account.item_dict["fiber"] = 4
	check(manager.save_current_account(), "save_current_account returned false")

	# Close the connection completely, then open a brand new one on the same file.
	_close_manager()
	manager = _open_manager()

	check(manager.sign_in("carol"), "carol should still exist after reopening")
	var account = manager.current_account
	if account:
		check_eq(account.score, 120, "score after reopen")
		check_eq(account.position, Vector2i(15, -7), "position after reopen")
		check_eq(account.item_dict["wood"], 30, "wood after reopen")
		check_eq(account.item_dict["fiber"], 4, "fiber after reopen")
		check_eq(account.item_dict["stone"], 0, "stone after reopen")


func test_unsaved_changes_are_not_written() -> void:
	manager = _open_manager()
	manager.create_player("dave")
	manager.sign_in("dave")
	manager.current_account.score = 999  # never saved
	manager.sign_out()
	manager.sign_in("dave")
	check_eq(manager.current_account.score, 0, "unsaved score should not persist")


func test_old_schema_is_upgraded_without_losing_players() -> void:
	# Simulate a .db made by the earlier, smaller version of the table.
	var raw := SQLite.new()
	raw.path = test_db_path
	raw.verbosity_level = SQLite.QUIET
	raw.open_db()
	raw.query("""CREATE TABLE players (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		username TEXT NOT NULL UNIQUE,
		level INTEGER NOT NULL DEFAULT 1,
		coins INTEGER NOT NULL DEFAULT 0);""")
	raw.query("INSERT INTO players (username, level, coins) VALUES ('veteran', 5, 50);")
	raw.close_db()

	manager = _open_manager()
	check(manager.database_ready, "manager should open an old-format database")
	var columns := _column_names(manager)
	for column in EXPECTED_COLUMNS:
		check(column in columns, "upgrade did not add column '%s'" % column)
	var row: Dictionary = manager.get_player("veteran")
	check(not row.is_empty(), "existing player lost during upgrade")
	if not row.is_empty():
		check_eq(int(row["level"]), 5, "existing level kept")
		check_eq(int(row["score"]), 0, "new score column defaulted")
