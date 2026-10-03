extends Node

var injection_count := 0


func inject_dependency() -> void:
	injection_count += 1
