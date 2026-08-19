extends RefCounted
class_name RollbackAction

var _rollback_action: Callable
var _is_executed := false
var is_executed: bool:
	get:
		return _is_executed

func _init(rollback_action: Callable) -> void:
	_rollback_action = rollback_action

func rollback() -> void:
	if _is_executed:
		push_error("既にロールバック処理は実行されています。")
		return
	_is_executed = true
	_rollback_action.call()
	_rollback_action = Callable()
