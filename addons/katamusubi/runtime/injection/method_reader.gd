extends RefCounted
## スクリプトから[code]inject_dependency[/code]メソッドを探して引数を抽出

const ArgumentData := preload("argument_data.gd")
var _method_name: StringName


func _init(
	init_method_name: StringName
) -> void:
	_method_name = init_method_name

## 対象スクリプトからinject_dependencyを検索
func _find_injection_method(script: Script) -> Dictionary:
	for method_data in script.get_script_method_list():
		if StringName(method_data.get("name", "")) == _method_name:
			return method_data
	return {}


## inject_dependencyの引数情報を解決要求として読み取り
func _get_arguments(method_data: Dictionary) -> Array[ArgumentData]:
	const KEY_NAME := "name"
	const KEY_CLASS_NAME := "class_name"
	const KEY_TYPE := "type"

	var arguments: Array[ArgumentData] = []

	for argument_data: Dictionary in method_data.get("args", []):
		var arg_name := StringName(argument_data.get(KEY_NAME, ""))
		var arg_class_name := StringName(argument_data.get(KEY_CLASS_NAME, ""))
		var arg_variant_type := int(argument_data.get(KEY_TYPE, TYPE_NIL))
		var service_type := _get_global_class_script(arg_class_name)

		arguments.append(
				ArgumentData.new(arg_name, service_type, arg_variant_type)
		)

	return arguments


## 指定したスクリプトから依存注入用のメソッドの引数情報を返す
func get_injection_arguments(script: Script) -> Array[ArgumentData]:
	var method_data := _find_injection_method(script)
	return _get_arguments(method_data)


## グローバルクラス名からスクリプトを取得。[br]
## 存在しない場合は[code]null[/code]を返す。
func _get_global_class_script(arg_class_name: StringName) -> Script:
	for class_data in ProjectSettings.get_global_class_list():
		if StringName(class_data["class"]) == arg_class_name:
			return load(class_data["path"]) as Script

	return null
