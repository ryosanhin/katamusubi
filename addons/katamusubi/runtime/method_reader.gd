extends RefCounted
## スクリプトから[code]inject_dependency[/code]メソッドを探して引数を抽出

const ArgumentData := preload("res://addons/katamusubi/runtime/argument_data.gd")

## 注入対象として固定利用するメソッド名
const METHOD_NAME := &"inject_dependency"

## 対象スクリプトからinject_dependencyを検索
static func _find_injection_method(script: Script) -> Dictionary:
	for method_data in script.get_script_method_list():
		if StringName(method_data.get("name", "")) == METHOD_NAME:
			return method_data
	return {}


## inject_dependencyの引数情報を解決要求として読み取り
static func _get_arguments(method_data: Dictionary) -> Array[ArgumentData]:
	const KEY_NAME := "name"
	const KEY_CLASS_NAME := "class_name"
	const KEY_TYPE := "type"

	var arguments: Array[ArgumentData] = []

	for argument_data: Dictionary in method_data.get("args", []):
		var arg_name := StringName(argument_data.get(KEY_NAME, ""))
		var arg_class_name := StringName(argument_data.get(KEY_CLASS_NAME, ""))
		var arg_variant_type := int(argument_data.get(KEY_TYPE, TYPE_NIL))
		if arg_class_name == &"":
			arg_class_name = StringName(type_string(arg_variant_type)) 

		arguments.append(
				ArgumentData.new(arg_name, arg_class_name, arg_variant_type)
		)

	return arguments


## 指定したスクリプトから依存注入用のメソッドの引数情報を返す
static func get_injection_arguments(script: Script) -> Array[ArgumentData]:
	var method_data := _find_injection_method(script)
	return _get_arguments(method_data)
