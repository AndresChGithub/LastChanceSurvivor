extends "res://tests/test_case.gd"
## Verifies the project is really wired up to SQLite through DatabaseManager:
## accounts, worlds, and per-world progress.
## Every write test uses its own throwaway .db file, never the real save file.

const MANAGER_SCRIPT = "res://Scripts/DatabaseManager.gd"
const PASSWORD = "Password1"
const EXPECTED_TABLES = ["players", "worlds", "world_players", "world_terrain_changes"]
const PLAYER_COLUMNS = ["id", "player_uid", "username", "password_hash", "password_salt"]
const WORLD_PLAYER_COLUMNS = [
	"world_id", "player_uid", "level", "coins", "score",
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


## Closes the connection completely, then opens a brand new one on the same file.
func _reopen_manager() -> void:
	_close_manager()
	manager = _open_manager()


func _column_names(table: String) -> Array[String]:
	var names: Array[String] = []
	manager.db.query("PRAGMA table_info(%s);" % table)
	for row in manager.db.query_result:
		names.append(str(row["name"]))
	return names


func _count(sql: String, bindings: Array = []) -> int:
	manager.db.query_with_bindings(sql, bindings)
	return int(manager.db.query_result[0].values()[0])


func _register_and_login(username: String) -> bool:
	return manager.register_account(username, PASSWORD) and manager.login_account(username, PASSWORD)


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


func test_all_tables_are_created() -> void:
	manager = _open_manager()
	for table in EXPECTED_TABLES:
		check_eq(_count("SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = ?;", [table]),
			1, "table '%s' exists" % table)


func test_tables_have_expected_columns() -> void:
	manager = _open_manager()
	var players := _column_names("players")
	for column in PLAYER_COLUMNS:
		check(column in players, "players table is missing column '%s'" % column)
	var world_players := _column_names("world_players")
	for column in WORLD_PLAYER_COLUMNS:
		check(column in world_players, "world_players table is missing column '%s'" % column)


# --- Registering accounts ----------------------------------------------------

func test_register_account_inserts_row_with_uid() -> void:
	manager = _open_manager()
	check(manager.register_account("alice", PASSWORD), "register_account('alice') returned false")
	var row: Dictionary = manager.get_player("alice")
	check(not row.is_empty(), "alice not found after register_account")
	if not row.is_empty():
		check_eq(row["username"], "alice", "username")
		check_eq(str(row["player_uid"]).length(), 32, "player_uid is 16 random bytes in hex")
		check_eq(manager.get_player_by_uid(str(row["player_uid"]))["username"], "alice",
			"lookup by uid finds the same player")


func test_passwords_are_hashed_and_salted() -> void:
	manager = _open_manager()
	manager.register_account("erin", PASSWORD)
	manager.register_account("frank", PASSWORD)
	manager.db.query("SELECT username, password_hash, password_salt FROM players ORDER BY username;")
	var rows: Array = manager.db.query_result
	check_eq(rows.size(), 2, "both accounts stored")
	if rows.size() == 2:
		for row in rows:
			check(not str(row["password_hash"]).contains(PASSWORD),
				"%s's password is stored in plain text" % row["username"])
		check(rows[0]["password_salt"] != rows[1]["password_salt"], "each account gets its own salt")
		check(rows[0]["password_hash"] != rows[1]["password_hash"],
			"same password should hash differently for different accounts")


func test_duplicate_username_is_rejected() -> void:
	manager = _open_manager()
	check(manager.register_account("bob", PASSWORD), "first register should succeed")
	check(not manager.register_account("bob", PASSWORD), "second register with same name should fail")
	check_eq(manager.last_error, "That username is already taken.", "duplicate name message")
	check(not manager.register_account("  bob  ", PASSWORD), "same name with extra spaces should fail")
	check_eq(_count("SELECT COUNT(*) FROM players WHERE username = 'bob';"), 1, "rows for 'bob'")


func test_blank_username_is_rejected() -> void:
	manager = _open_manager()
	check(not manager.register_account("", PASSWORD), "empty username should fail")
	check(not manager.register_account("    ", PASSWORD), "whitespace-only username should fail")
	check_eq(_count("SELECT COUNT(*) FROM players;"), 0, "no rows written")


func test_weak_password_is_rejected_by_the_database_layer() -> void:
	# The signup screen checks too, but the database must not trust the UI.
	manager = _open_manager()
	check(not manager.register_account("gina", "short"), "short password should fail")
	check(not manager.register_account("gina", "nocapitals1"), "password without a capital should fail")
	check_eq(_count("SELECT COUNT(*) FROM players;"), 0, "no rows written")


func test_username_is_stored_literally_not_run_as_sql() -> void:
	manager = _open_manager()
	var sneaky := "x'); DROP TABLE players; --"
	check(manager.register_account(sneaky, PASSWORD), "register with quote characters should succeed")
	check(not manager.get_player(sneaky).is_empty(), "username with quotes should round-trip")
	check(manager.db.query("SELECT COUNT(*) FROM players;"), "players table should still exist")


# --- Logging in and out ------------------------------------------------------

func test_login_unknown_user_fails() -> void:
	manager = _open_manager()
	check(not manager.login_account("nobody", PASSWORD), "login for a missing user should fail")
	check(manager.current_account == null, "current_account should stay null")
	check(not manager.is_signed_in(), "should not be signed in")


func test_login_wrong_password_fails() -> void:
	manager = _open_manager()
	manager.register_account("hank", PASSWORD)
	check(not manager.login_account("hank", "WrongPassword1"), "wrong password should fail")
	check_eq(manager.last_error, "Incorrect username or password.", "same message as unknown user")
	check(manager.current_account == null, "current_account should stay null")


func test_login_correct_password_signs_in() -> void:
	manager = _open_manager()
	manager.register_account("ivy", PASSWORD)
	check(manager.login_account("  ivy  ", PASSWORD), "login should succeed (username is trimmed)")
	check(manager.is_signed_in(), "is_signed_in() after login")
	if manager.current_account:
		check_eq(manager.current_account.username, "ivy", "current_account username")
	check_eq(manager.get_current_player_uid(), str(manager.get_player("ivy")["player_uid"]),
		"current uid matches the stored uid")
	check(not manager.current_world_id.is_empty(), "login should enter the development world")


func test_sign_out_clears_session() -> void:
	manager = _open_manager()
	_register_and_login("jack")
	manager.sign_out()
	check(not manager.is_signed_in(), "is_signed_in() after sign_out")
	check(manager.current_account == null, "current_account cleared")
	check_eq(manager.current_world_id, "", "current world cleared")
	check(not manager.save_current_account(), "saving with nobody signed in should fail")


func test_rename_account() -> void:
	manager = _open_manager()
	manager.register_account("taken", PASSWORD)
	_register_and_login("kate")
	check(not manager.rename_current_account("taken"), "renaming to a taken name should fail")
	check_eq(manager.last_error, "That username is already taken.", "taken name message")
	check(manager.rename_current_account("katherine"), "renaming to a free name should succeed")
	check_eq(manager.current_account.username, "katherine", "current_account updated")
	manager.sign_out()
	check(not manager.login_account("kate", PASSWORD), "old name should no longer log in")
	check(manager.login_account("katherine", PASSWORD), "new name logs in with the same password")


# --- Data actually persists --------------------------------------------------

func test_progress_survives_closing_and_reopening_database() -> void:
	manager = _open_manager()
	check(_register_and_login("carol"), "register and login")
	manager.current_account.score = 120
	manager.current_account.position = Vector2i(15, -7)
	manager.current_account.item_dict["wood"] = 30
	manager.current_account.item_dict["fiber"] = 4
	check(manager.save_current_account(), "save_current_account returned false")

	_reopen_manager()

	check(manager.login_account("carol", PASSWORD), "carol should still log in after reopening")
	var account = manager.current_account
	if account:
		check_eq(account.score, 120, "score after reopen")
		check_eq(account.position, Vector2i(15, -7), "position after reopen")
		check_eq(account.item_dict["wood"], 30, "wood after reopen")
		check_eq(account.item_dict["fiber"], 4, "fiber after reopen")
		check_eq(account.item_dict["stone"], 0, "stone after reopen")


func test_unsaved_changes_are_not_written() -> void:
	manager = _open_manager()
	_register_and_login("dave")
	manager.current_account.score = 999  # never saved
	manager.sign_out()
	manager.login_account("dave", PASSWORD)
	check_eq(manager.current_account.score, 0, "unsaved score should not persist")


func test_broken_terrain_survives_reopening() -> void:
	manager = _open_manager()
	_register_and_login("lena")
	var spot := Vector2i(300, -420)
	manager.mark_terrain_broken(spot)
	check(manager.is_terrain_broken(spot), "marked terrain is broken right away")
	check(manager.save_current_account(), "save")

	_reopen_manager()
	manager.login_account("lena", PASSWORD)
	check(manager.is_terrain_broken(spot), "broken terrain remembered after reopen")
	check(not manager.is_terrain_broken(Vector2i(301, -420)), "neighbouring spot not broken")


# --- Worlds ------------------------------------------------------------------

func test_create_world_requires_sign_in_and_name() -> void:
	manager = _open_manager()
	check_eq(manager.create_world("Nope", 1), "", "creating a world while signed out should fail")
	_register_and_login("mia")
	check_eq(manager.create_world("   ", 1), "", "blank world name should fail")
	check_eq(manager.get_owned_worlds().size(), 0, "no worlds created")


func test_created_world_is_listed_and_dev_world_is_hidden() -> void:
	manager = _open_manager()
	_register_and_login("ned")
	var world_id: String = manager.create_world("  Island  ", 98765)
	check(not world_id.is_empty(), "create_world returned an id")

	var worlds: Array[Dictionary] = manager.get_owned_worlds()
	check_eq(worlds.size(), 1, "only the created world is listed (dev world hidden)")
	if worlds.size() == 1:
		check_eq(worlds[0]["world_id"], world_id, "listed world id")
		check_eq(worlds[0]["world_name"], "Island", "world name is trimmed")
		check_eq(int(worlds[0]["seed"]), 98765, "world seed stored")


func test_entering_world_uses_its_seed() -> void:
	manager = _open_manager()
	_register_and_login("olga")
	var world_id: String = manager.create_world("Seeded", 424242)
	check(manager.enter_world(world_id), "enter_world")
	check_eq(manager.get_current_world_seed(), 424242, "current seed is the world's seed")
	check_eq(manager.current_world_id, world_id, "current world id")


func test_progress_is_separate_per_world() -> void:
	manager = _open_manager()
	_register_and_login("pete")
	var world_a: String = manager.create_world("A", 1)
	var world_b: String = manager.create_world("B", 2)

	manager.enter_world(world_a)
	manager.current_account.item_dict["wood"] = 50
	manager.mark_terrain_broken(Vector2i(10, 10))
	check(manager.save_current_account(), "save world A")

	manager.enter_world(world_b)
	check_eq(manager.current_account.item_dict["wood"], 0, "world B starts with no wood")
	check(not manager.is_terrain_broken(Vector2i(10, 10)), "world A's broken terrain not in world B")

	_reopen_manager()
	manager.login_account("pete", PASSWORD)
	manager.enter_world(world_a)
	check_eq(manager.current_account.item_dict["wood"], 50, "world A keeps its wood after reopen")
	check(manager.is_terrain_broken(Vector2i(10, 10)), "world A keeps its broken terrain")


func test_switching_worlds_saves_the_previous_world() -> void:
	manager = _open_manager()
	_register_and_login("quinn")
	var world_a: String = manager.create_world("A", 1)
	var world_b: String = manager.create_world("B", 2)

	manager.enter_world(world_a)
	manager.current_account.item_dict["stone"] = 7  # not saved by hand
	manager.enter_world(world_b)
	manager.enter_world(world_a)
	check_eq(manager.current_account.item_dict["stone"], 7, "progress kept when hopping between worlds")


func test_cannot_enter_another_players_world() -> void:
	manager = _open_manager()
	_register_and_login("rita")
	var ritas_world: String = manager.create_world("Rita's", 5)
	manager.sign_out()

	_register_and_login("sam")
	check(not manager.enter_world(ritas_world), "sam should not be able to load rita's world")
	check_eq(manager.last_error, "This world does not belong to the current account.", "error message")
	check(manager.current_world_id != ritas_world, "sam did not end up in rita's world")
