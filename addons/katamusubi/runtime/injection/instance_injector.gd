extends RefCounted
## インスタンス注入だけを担当

const Const := preload("res://addons/katamusubi/katamusubi_global.gd")
const MethodReader := preload("method_reader.gd")
const ScriptTypeCompatibility := preload(
	"res://addons/katamusubi/runtime/utility/script_type_compatibility.gd"
)

var _scope_name: StringName
var _container: InjectionContainer

func _init(
	container: InjectionContainer,
	scope_name: StringName,
) -> void:
	_container = container
	_scope_name = scope_name


## 1ノード分の引数を宣言順に解決し、すべて揃った場合だけ注入メソッドを呼ぶ
func try_inject_arguments(target: Node) -> bool:
	if not _is_injectable(target):
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
	if not _validate_type_overrides(target, arguments, override_value):
		return false

	var args_override_dict: Dictionary[StringName, Script] = {}
	for override_key: Variant in override_value:
		args_override_dict[StringName(override_key)] = override_value[override_key]

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


## 型オーバーライド設定の形式、引数名、指定型を検証する
func _validate_type_overrides(
	target: Node,
	arguments: Array,
	override_value: Variant,
) -> bool:
	if not override_value is Dictionary:
		_push_invalid_override_error(target, &"<判定不能>", override_value, "戻り値がDictionaryではありません")
		return false

	var argument_types: Dictionary = {}
	for argument in arguments:
		argument_types[argument.arg_name] = argument.service_type

	for override_key: Variant in override_value:
		if not (override_key is String or override_key is StringName):
			_push_invalid_override_error(target, override_key, override_value[override_key], "存在しない引数名です")
			return false
		var argument_name := StringName(override_key)
		if not argument_types.has(argument_name):
			_push_invalid_override_error(target, argument_name, override_value[override_key], "存在しない引数名です")
			return false

		var specified_type: Variant = override_value[override_key]
		if specified_type == null or not specified_type is Script:
			_push_invalid_override_error(target, argument_name, specified_type, "指定値が有効なScriptではありません")
			return false

		var declared_type: Script = argument_types[argument_name]
		if declared_type != null and not ScriptTypeCompatibility.is_same_or_derived_from(
			specified_type,
			declared_type,
		):
			_push_invalid_override_error(target, argument_name, specified_type, "指定型が宣言型自身または派生型ではありません")
			return false

	return true


func _push_invalid_override_error(
	target: Node,
	argument_name: Variant,
	specified_value: Variant,
	reason: String,
) -> void:
	push_error(
		"型オーバーライドの設定が不正です: %s, 対象=%s, 引数=%s, 指定値=%s"
		% [reason, target.get_path(), argument_name, specified_value]
	)


func _is_injectable(target: Node) -> bool:
	if target == null:
		push_error("対象が null です: スコープ名=%s" % _scope_name)
		return false

	if not is_instance_valid(target):
		push_error("対象は既に解放されています: スコープ名=%s" % _scope_name)
		return false
	
	if not target.is_inside_tree():
		push_error("対象はツリーに存在しません: 対象=%s, スコープ名=%s"% [target.name, _scope_name])
		return false
	
	if target.get_script() == null:
		push_error("対象にスクリプトがありません: 対象=%s, スコープ名=%s"% [target.get_path(), _scope_name])
		return false

	return true
