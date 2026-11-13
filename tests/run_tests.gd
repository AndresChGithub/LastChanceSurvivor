extends SceneTree
## Headless test runner. From the project folder run:
##   godot --headless --path . --script res://tests/run_tests.gd
## Exit code is 0 when everything passes, 1 otherwise.
##
## A test fails if any check() fails, OR if a script error (e.g. calling a
## function that doesn't exist) or push_error() happens while it runs.
## Without that, a test that crashes halfway through would still say PASS.

const SUITES = [
	"res://tests/test_password_rules.gd",
	"res://tests/test_sqlite_connection.gd",
	"res://tests/test_world_generation.gd",
	"res://tests/test_harvesting.gd",
]


## Collects engine errors so the runner can blame them on the test that was running.
class ErrorCatcher extends Logger:
	var _mutex := Mutex.new()
	var _errors: Array[String] = []

	func _log_error(_function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var kind := "script error" if error_type == ERROR_TYPE_SCRIPT else "error"
		var text := rationale if not rationale.is_empty() else code
		_mutex.lock()
		_errors.append("%s: %s (%s:%d)" % [kind, text, file.get_file(), line])
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	## Returns everything logged since the last call, and forgets it.
	func take() -> Array[String]:
		_mutex.lock()
		var result := _errors.duplicate()
		_errors.clear()
		_mutex.unlock()
		return result


var _started := false
var _catcher := ErrorCatcher.new()


func _initialize() -> void:
	OS.add_logger(_catcher)


func _process(_delta: float) -> bool:
	# Run on the first frame so autoloads (DatabaseManager) have finished _ready().
	if _started:
		return false
	_started = true
	_catcher.take()  # ignore anything logged during startup

	var passed := 0
	var failed := 0

	for suite_path in SUITES:
		print("\n== ", suite_path.get_file())
		var suite_script: GDScript = load(suite_path)
		if suite_script == null or not suite_script.can_instantiate():
			failed += 1
			print("  FAIL  could not load suite (parse error?)")
			continue

		var probe = suite_script.new()
		var test_names: Array[String] = []
		for method in probe.get_method_list():
			if str(method["name"]).begins_with("test_"):
				test_names.append(str(method["name"]))
		probe = null

		for test_name in test_names:
			# Fresh suite object per test so state never leaks between tests.
			var suite = suite_script.new()
			suite.set("tree", self)
			suite.before_each()
			suite.call(test_name)
			suite.after_each()

			var problems: Array[String] = suite.failures.duplicate()
			for error in _catcher.take():
				if suite.allow_errors and not error.begins_with("script error"):
					continue
				problems.append(error)

			if problems.is_empty():
				passed += 1
				print("  PASS  ", test_name)
			else:
				failed += 1
				print("  FAIL  ", test_name)
				for message in problems:
					print("        - ", message)

	print("\n%d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
	return false
