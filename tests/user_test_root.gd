extends Node

var _manager: AbstractTestManager

func inject_dependency(manager: AbstractTestManager) -> void:
	print("call injection at root user")
	_manager = manager


func call_injected_instance() -> String:
	return _manager.test_method("call from test root user")
