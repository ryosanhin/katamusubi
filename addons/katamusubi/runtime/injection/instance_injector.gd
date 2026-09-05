extends RefCounted
## インスタンス注入だけを担当

const Const := preload("res://addons/katamusubi/katamusubi_global.gd")
const MethodReader := preload("method_reader.gd")

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
	var args_override_dict: Dictionary[StringName, Script] = {}
	if target.has_method(Const.OVERRIDE_METHOD_NAME):
		var callable := Callable(target, Const.OVERRIDE_METHOD_NAME)
		args_override_dict = callable.call()

	for argument in arguments:
		var service_type := argument.service_type
		var key := argument.arg_name

		# 型のオーバーライドが可能なら実行
		if args_override_dict.has(key):
			var override_type := args_override_dict[key]
			if service_type == null:
				service_type = override_type
			else:
				if (
						# override_type --|> service_type のパターン
						_check_inheritance(override_type, service_type)
						# service_type --|> override_type のパターン
						or _check_inheritance(service_type, override_type)
				):
					service_type = override_type

		if service_type == null:
			push_error(
					"引数の型がグローバルクラスとして宣言されていないか、型オーバーライドが指定されていません: 対象=%s, 引数=%s, スコープ名=%s"
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


## 生成するクラスが公開するクラス自身か派生型であるか調べる[br]
## [param inherits]: サブクラス[br]
## [param inherited]: スーパークラス
func _check_inheritance(inherits: Script, inherited: Script) -> bool:
	var current: Script = inherits

	while current != null:
		if current == inherited:
			return true
		current = current.get_base_script()

	return false
