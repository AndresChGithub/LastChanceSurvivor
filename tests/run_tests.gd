extends SceneTree
## Headless test runner. From the project folder run:
##   godot --headless --path . --script res://tests/run_tests.gd
## Exit code is 0 when everything passes, 1 otherwise.

const SUITES = [
	"res://tests/test_password_rules.gd",
	"res://tests/test_sqlite_connection.gd",
]

var _started := false


func _process(_delta: float) -> bool:
	# Run on the first frame so autoloads (DatabaseManager) have finished _ready().
	if _started:
		return false
	_started = true

	var passed := 0
	var failed := 0

	for suite_path in SUITES:
		print("\n== ", suite_path.get_file())
		var suite_script: GDScript = load(suite_path)
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

			if suite.failures.is_empty():
				passed += 1
				print("  PASS  ", test_name)
			else:
				failed += 1
				print("  FAIL  ", test_name)
				for message in suite.failures:
					print("        - ", message)

	print("\n%d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
	return false
