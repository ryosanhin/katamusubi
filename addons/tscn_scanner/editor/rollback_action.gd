@tool
extends RefCounted
class_name RollbackAction

var _rollback_action: Callable

var _operation_succeeded: bool
## ロールバック対象の処理が成功しているか
var operation_succeeded: bool:
	get:
		return _operation_succeeded

var _rollback_executed := false
## ロールバックが実行済みか
var rollback_executed: bool:
	get:
		return _rollback_executed


## コンストラクタ[br]
## [param init_operation_succeeded]: ロールバック対象処理が成功したか[br]
## [param rollback_action]: ロールバック処理内容
func _init(
	init_operation_succeeded: bool,
	rollback_action: Callable,
) -> void:
	_operation_succeeded = init_operation_succeeded
	_rollback_action = rollback_action


## ロールバック実行
func rollback() -> void:
	if _rollback_executed:
		push_error("既にロールバック処理は実行されています。")
		return
	_rollback_executed = true
	_rollback_action.call()
	_rollback_action = Callable()
