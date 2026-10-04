extends RefCounted
## インスタンス注入だけを担当

const MethodReader := preload("method_reader.gd")
const InjectionRequestValidator := preload("injection_request_validator.gd")

## 注入対象として固定利用するメソッド名
const INJECTION_METHOD_NAME := &"inject_dependency"

var _scope_name: StringName
var _container: InjectionContainer

func _init(
	container: InjectionContainer,
	scope_name: StringName,
) -> void:
	_container = container
	_scope_name = scope_name


## 1ノード分の引数を宣言順に解決し、すべて揃った場合だけ注入メソッドを呼ぶ
func try_inject_arguments(target: Variant) -> bool:
	var target_result := InjectionRequestValidator.validate_target(target, _scope_name)
	if not target_result.is_valid():
		push_error(InjectionRequestValidator.format_error(target_result))
		return false
	
	var injection_method := Callable(target, INJECTION_METHOD_NAME)
	if not injection_method.is_valid():
		push_error(
				"依存注入メソッドを呼び出せません: 対象=%s, スコープ名=%s"
				% [target.get_path(), _scope_name]
		)
		return false

	var script := target.get_script() as Script
	var method_reader := MethodReader.new(INJECTION_METHOD_NAME)
	var arguments := method_reader.get_injection_arguments(script)
	var resolved_arguments: Array = []

	for argument in arguments:
		# 実際に渡す型
		var service_type := argument.service_type

		var key := argument.arg_name

		if service_type == null:
			push_error(
					"引数の型はclass_nameで登録されたグローバルクラスである必要があります: 対象=%s, 引数=%s, スコープ名=%s"
					% [
							target.get_path(),
							argument.arg_name,
							_scope_name,
					]
			)
			return false
		
		# 引数名をKeyとして渡し、コンテナ側の優先順位に従ってNode参照を解決する
		var resolved_service: Variant = _container.resolve(
				service_type,
				key
		)

		if resolved_service == null:
			push_error(
					"サービスを解決できませんでした: 対象=%s, 引数=%s, 要求型=%s, スコープ名=%s"
					% [
							target.get_path(),
							key,
							service_type.get_global_name(),
							_scope_name,
					]
			)
			return false
		resolved_arguments.append(resolved_service)

	injection_method.callv(resolved_arguments)
	return true
