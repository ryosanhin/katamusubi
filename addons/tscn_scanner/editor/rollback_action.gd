extends RefCounted
class_name RollbackAction

var _rollback_action: Callable

var _operation_succeeded: bool
var operation_succeeded: bool:
	get:
		return _operation_succeeded

var _rollback_executed := false
var rollback_executed: bool:
	get:
		return _rollback_executed


func _init(
	init_operation_succeeded: bool,
	rollback_action: Callable,
) -> void:
	_operation_succeeded = init_operation_succeeded
	_rollback_action = rollback_action


func rollback() -> void:
	if _rollback_executed:
		push_error("既にロールバック処理は実行されています。")
		return
	_rollback_executed = true
	_rollback_action.call()
	_rollback_action = Callable()
