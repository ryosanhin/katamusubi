extends Node

var injection_count := 0


func inject_dependency(untyped_service) -> void:
	injection_count += 1
