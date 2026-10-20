extends "res://tests/test_case.gd"
## Verifies that the signup screen rejects short passwords.
## The rule lives in Scenes/signup.gd -> good_password().

const SIGNUP_SCRIPT = "res://Scenes/signup.gd"
const SIGNUP_SCENE = "res://Scenes/signup.tscn"
const TOO_SHORT = "passwords must be at least 8 characters"

var tree: SceneTree
var signup: Control


func before_each() -> void:
	signup = load(SIGNUP_SCRIPT).new()


func after_each() -> void:
	if is_instance_valid(signup):
		signup.free()


# --- Unit tests on good_password() -------------------------------------------

func test_empty_password_is_rejected() -> void:
	check_eq(signup.good_password(""), TOO_SHORT, "empty password")


func test_every_length_from_1_to_7_is_rejected() -> void:
	# Each candidate has a capital letter and isn't "password", so the ONLY
	# thing wrong with it is the length.
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


# --- UI test: the actual signup screen ---------------------------------------

func test_signup_screen_rejects_short_password() -> void:
	var screen: Control = load(SIGNUP_SCENE).instantiate()
	var username: LineEdit = screen.get_node("VBoxContainer/Username")
	var password: LineEdit = screen.get_node("VBoxContainer/Password")
	var button: Button = screen.get_node("VBoxContainer/Button")

	username.text = "tester"
	password.text = "Short1"
	# Fire the same signal the real button fires (tests the scene wiring too).
	button.button_down.emit()

	check_eq(password.text, "", "short password should be cleared from the field")
	check_eq(password.placeholder_text, TOO_SHORT, "error message shown to the player")
	screen.free()


func test_signup_screen_keeps_valid_password() -> void:
	var screen: Control = load(SIGNUP_SCENE).instantiate()
	var username: LineEdit = screen.get_node("VBoxContainer/Username")
	var password: LineEdit = screen.get_node("VBoxContainer/Password")
	var original_placeholder := password.placeholder_text

	username.text = "tester"
	password.text = "LongEnough1"
	screen.get_node("VBoxContainer/Button").button_down.emit()

	check_eq(password.text, "LongEnough1", "valid password should not be cleared")
	check_eq(password.placeholder_text, original_placeholder, "no error message for a valid password")
	screen.free()
