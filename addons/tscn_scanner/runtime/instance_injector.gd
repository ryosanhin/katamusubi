extends RefCounted
## インスタンス注入だけを担当
class_name InstanceInjector

var _scope_id: StringName
var _container: InjectionContainer

func _init(
	container: InjectionContainer,
	scope_id: StringName,
) -> void:
	_container = container
	_scope_id = scope_id


## 1ノード分の引数を宣言順に解決し、すべて揃った場合だけ注入メソッドを呼ぶ
func try_inject_arguments(target: Node) -> bool:
	if not _is_injectable(target):
		return false
	
	var script := target.get_script() as Script
	var arguments := MethodReader.get_injection_arguments(script)
	var resolved_arguments: Array = []

	for argument in arguments:
		# 引数名をKeyとして渡し、コンテナ側の優先順位に従って生成する
		var resolved_service: Variant = _container.resolve_with_string_name(
				argument.arg_class,
				argument.arg_name
		)
		
		if resolved_service == null:
			_push_injection_error(
						target,
						argument,
						"サービスを解決できませんでした",
			)
			return false
		
		resolved_arguments.append(resolved_service)

	var injection_method := Callable(target, MethodReader.METHOD_NAME)
	if not injection_method.is_valid():
		push_error(
				"依存注入メソッドを呼び出せません: 対象=%s, 引数=<none>, 要求型=<none>, スコープID=%s"
				% [target.get_path(), _scope_id]
		)
		return false

	injection_method.callv(resolved_arguments)
	return true


func _is_injectable(target: Node) -> bool:
	if target == null:
		push_error("対象が null です: スコープID=%s" % _scope_id)
		return false

	if not is_instance_valid(target):
		push_error("対象は既に解放されています: スコープID=%s" % _scope_id)
		return false
	
	if not target.is_inside_tree():
		push_error("対象はツリーに存在しません: 対象=%s, スコープID=%s"% [target.name, _scope_id])
		return false
	
	if target.get_script() == null:
		push_error("対象にスクリプトがありません: 対象=%s, スコープID=%s"% [target.get_path(), _scope_id])
		return false

	return true


## 注入時失敗エラーメッセージのテンプレート
func _push_injection_error(
	target: Node,
	argument: ArgumentData,
	reason: String,
) -> void:
	push_error(
			"依存注入に失敗しました（%s）: 対象=%s, 引数=%s, 要求型=%s, スコープID=%s"
			% [reason, target.get_path(), argument.arg_name, argument.arg_class, _scope_id]
	)
