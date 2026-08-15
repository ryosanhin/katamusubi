extends Node

var _manager: AbstractTestManager

func inject_dependency(manager: AbstractTestManager) -> void:
	_manager = manager


func call_injected_instance() -> String:
	return _manager.test_method("call from test child user")
