extends Node

var label: StringName
var order: Array[StringName]


func inject_dependency() -> void:
	order.append(label)
