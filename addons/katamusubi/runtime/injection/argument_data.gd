extends RefCounted

var arg_name: StringName
var service_type: Script
var arg_type: int


func _init(
	init_arg_name: StringName,
	init_service_type: Script,
	init_arg_type: int,
) -> void:
	arg_name = init_arg_name
	service_type = init_service_type
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
		service_type.get_global_name(),
		arg_type,
		type_string(arg_type),
	]
