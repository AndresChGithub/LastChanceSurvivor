extends RefCounted
## Tiny base class for test suites. Any method whose name starts with
## "test_" is run by tests/run_tests.gd. No addons required.

var failures: Array[String] = []

## Set to true in a test that deliberately triggers push_error(). Script
## errors (crashes) still fail the test either way.
var allow_errors: bool = false


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
