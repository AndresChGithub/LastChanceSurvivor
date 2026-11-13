extends "res://tests/test_case.gd"
## Verifies the password rules and that the signup screen enforces them.
## The rules live in DatabaseManager.check_password(); Scenes/signup.gd
## calls it through good_password().

const SIGNUP_SCRIPT = "res://Scenes/signup.gd"
const SIGNUP_SCENE = "res://Scenes/signup.tscn"
const TOO_SHORT = "passwords must be at least 8 characters"
const NO_CAPITAL = "password must contain a capital letter"

var tree: SceneTree
var signup: Control
var screen: Control
var _db_was_ready: bool


func before_each() -> void:
	signup = load(SIGNUP_SCRIPT).new()
	_db_was_ready = DatabaseManager.database_ready


func after_each() -> void:
	if is_instance_valid(signup):
		signup.free()
	if is_instance_valid(screen):
		screen.free()
	DatabaseManager.database_ready = _db_was_ready


## Instantiates signup.tscn inside the running tree so its @onready nodes exist.
func _open_signup_screen() -> void:
	screen = load(SIGNUP_SCENE).instantiate()
	tree.root.add_child(screen)


# --- Unit tests on good_password() -------------------------------------------

func test_empty_password_is_rejected() -> void:
	check_eq(signup.good_password(""), TOO_SHORT, "empty password")


func test_every_length_from_1_to_7_is_rejected() -> void:
	# Each candidate has a capital letter, so the ONLY thing wrong is the length.
	for length in range(1, 8):
		var candidate := "A" + "b".repeat(length - 1)
		check_eq(signup.good_password(candidate), TOO_SHORT,
			"%d-char password '%s'" % [length, candidate])


func test_seven_chars_with_digits_and_symbols_is_still_rejected() -> void:
	check_eq(signup.good_password("Ab1!x9Z"), TOO_SHORT, "7-char complex password")


func test_seven_chars_padded_with_spaces_is_rejected() -> void:
	check_eq(signup.good_password(" Ab12  "), TOO_SHORT, "7-char password with spaces")


func test_exactly_eight_chars_is_accepted() -> void:
	# Boundary check: 8 is the minimum, so this must pass.
	check_eq(signup.good_password("Abcdefgh"), "good", "8-char password with a capital")


func test_long_password_is_accepted() -> void:
	check_eq(signup.good_password("CorrectHorseBatteryStaple"), "good", "long password")


func test_password_without_capital_is_rejected() -> void:
	check_eq(signup.good_password("abcdefgh"), NO_CAPITAL, "all lowercase")
	check_eq(signup.good_password("abc123!@#"), NO_CAPITAL, "lowercase, digits and symbols")
	check_eq(signup.good_password("12345678"), NO_CAPITAL, "digits only")


func test_capital_anywhere_is_enough() -> void:
	check_eq(signup.good_password("abcdefgZ"), "good", "capital at the end")
	check_eq(signup.good_password("abcDefgh"), "good", "capital in the middle")


# --- UI tests: the actual signup screen --------------------------------------

func test_signup_screen_rejects_short_password() -> void:
	_open_signup_screen()
	var username: LineEdit = screen.get_node("VBoxContainer/Username")
	var password: LineEdit = screen.get_node("VBoxContainer/Password")
	var status: Label = screen.get_node("VBoxContainer/StatusLabel")

	username.text = "tester"
	password.text = "Short1"
	# Fire the same signal the real button fires (tests the scene wiring too).
	screen.get_node("VBoxContainer/Button").button_down.emit()

	check_eq(password.text, "", "short password should be cleared from the field")
	check_eq(password.placeholder_text, TOO_SHORT, "error shown in the password field")
	check_eq(status.text, TOO_SHORT, "error shown in the status label")


func test_signup_screen_rejects_password_without_capital() -> void:
	_open_signup_screen()
	var password: LineEdit = screen.get_node("VBoxContainer/Password")
	var status: Label = screen.get_node("VBoxContainer/StatusLabel")

	screen.get_node("VBoxContainer/Username").text = "tester"
	password.text = "longbutlowercase"
	screen.get_node("VBoxContainer/Button").button_down.emit()

	check_eq(password.text, "", "weak password should be cleared from the field")
	check_eq(status.text, NO_CAPITAL, "error shown in the status label")


func test_signup_screen_requires_username() -> void:
	_open_signup_screen()
	var password: LineEdit = screen.get_node("VBoxContainer/Password")
	var status: Label = screen.get_node("VBoxContainer/StatusLabel")

	screen.get_node("VBoxContainer/Username").text = "   "
	password.text = "LongEnough1"
	screen.get_node("VBoxContainer/Button").button_down.emit()

	check_eq(status.text, "Enter a username.", "blank username message")


func test_signup_screen_keeps_valid_password() -> void:
	# Stop the screen from writing a real account into the player's save file;
	# the SQLite suite covers register_account() against a throwaway database.
	DatabaseManager.database_ready = false

	_open_signup_screen()
	var password: LineEdit = screen.get_node("VBoxContainer/Password")
	var original_placeholder := password.placeholder_text

	screen.get_node("VBoxContainer/Username").text = "tester"
	password.text = "LongEnough1"
	screen.get_node("VBoxContainer/Button").button_down.emit()

	check_eq(password.text, "LongEnough1", "valid password should not be cleared")
	check_eq(password.placeholder_text, original_placeholder, "no password error for a valid password")
