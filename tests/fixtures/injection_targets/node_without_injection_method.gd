extends Node

var unrelated_call_count := 0


func unrelated_method() -> void:
	unrelated_call_count += 1
