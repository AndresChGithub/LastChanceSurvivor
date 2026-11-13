extends RefCounted
## Tiny base class for test suites. Any method whose name starts with
## "test_" is run by tests/run_tests.gd. No addons required.

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func check_eq(actual, expected, message: String) -> void:
	if actual != expected:
		failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])


## Optional per-test hooks. Suites override these when they need setup.
func before_each() -> void:
	pass


func after_each() -> void:
	pass
