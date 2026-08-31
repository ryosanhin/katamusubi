extends Node


var injection_count := 0
var call_order: Array[StringName] = []
var was_injected := false


func inject_dependency() -> void:
	injection_count += 1
	call_order.append(&"inject_dependency")
	was_injected = true
