extends Logger
class_name ErrorCapture

## push_error() の出力を、異常系テストで明示的に検証するためのロガーです。
var errors: PackedStringArray = []


func start() -> void:
	errors.clear()
	OS.add_logger(self)


func stop() -> void:
	OS.remove_logger(self)


func contains(expected_message: String) -> bool:
	for message in errors:
		if expected_message in message:
			return true
	return false


func _log_error(
	function: String,
	file: String,
	line: int,
	code: String,
	rationale: String,
	editor_notify: bool,
	error_type: int,
	script_backtraces: Array[ScriptBacktrace],
) -> void:
	# push_error() の本文は rationale に渡されます。code も保持して将来のGodot差分に備えます。
	errors.append(rationale if not rationale.is_empty() else code)
