extends Node

var _manager: AbstactTestManager

func inject_dependency(manager: AbstactTestManager) -> void:
	_manager = manager


func call_injected_instance() -> String:
	return _manager.test_method("call from test root user")
