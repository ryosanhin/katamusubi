extends RefCounted
## インスタンス注入だけを担当

const Const := preload("res://addons/katamusubi/katamusubi_global.gd")
const MethodReader := preload("method_reader.gd")
const InjectionRequestValidator := preload("injection_request_validator.gd")

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
	var target_diagnostics := InjectionRequestValidator.validate_target(target, _scope_name)
	if not target_diagnostics.is_empty():
		_report_diagnostics(target_diagnostics)
		return false
	
	var script := target.get_script() as Script
	var method_reader := MethodReader.new(Const.INJECTION_METHOD_NAME)
	var arguments := method_reader.get_injection_arguments(script)
	var resolved_arguments: Array = []

	# ここで引数の型のオーバーライドの辞書を取得
	var override_value: Variant = {}
	if target.has_method(Const.OVERRIDE_METHOD_NAME):
		var callable := Callable(target, Const.OVERRIDE_METHOD_NAME)
		override_value = callable.call()
	var override_result := InjectionRequestValidator.validate_type_overrides(
		target,
		arguments,
		override_value,
	)
	if not override_result.is_valid():
		_report_diagnostics(override_result.diagnostics)
		return false
	var args_override_dict: Dictionary[StringName, Script] = override_result.overrides

	for argument in arguments:
		# 実際に渡す型
		var service_type := argument.service_type

		var key := argument.arg_name

		# 型のオーバーライドが可能なら実行
		if args_override_dict.has(key):
			var overrided_type := args_override_dict[key]
			service_type = overrided_type

		if service_type == null:
			push_error(
					"引数の型がグローバルクラスとして宣言されていないか、\
					型オーバーライドが指定されていません: 対象=%s, 引数=%s, スコープ名=%s"
					% [
							target.get_path(),
							argument.arg_name,
							_scope_name,
					]
			)
			return false
		
		# 引数名をKeyとして渡し、コンテナ側の優先順位に従って生成する
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

	var injection_method := Callable(target, Const.INJECTION_METHOD_NAME)
	if not injection_method.is_valid():
		push_error(
				"依存注入メソッドを呼び出せません: 対象=%s, スコープ名=%s"
				% [target.get_path(), _scope_name]
		)
		return false

	injection_method.callv(resolved_arguments)
	return true


func _report_diagnostics(diagnostics: PackedStringArray) -> void:
	for diagnostic in diagnostics:
		push_error(diagnostic)
