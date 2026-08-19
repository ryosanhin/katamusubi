extends RefCounted
class_name ArgumentData

var arg_name: StringName
var arg_class: StringName
var arg_type: int


func _init(
	init_arg_name: StringName,
	init_arg_class: StringName,
	init_arg_type: int,
) -> void:
	arg_name = init_arg_name
	arg_class = init_arg_class
	arg_type = init_arg_type


func _to_string() -> String:
	const KEY_NAME := "name"
	const KEY_CLASS_NAME := "class_name"
	const KEY_TYPE := "type"
	return """
	name: %s
	class_name: %s
	type: %d (%s)
	""" % [
		arg_name,
		arg_class,
		arg_type,
		type_string(arg_type),
	]