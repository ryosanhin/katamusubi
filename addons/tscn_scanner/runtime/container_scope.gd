@tool
@abstract
extends Node
class_name ContainerScope

## コンテナ初期化の内部状態
enum State {
	NOT_INITIALIZED,
	INITIALIZING,
	INITIALIZED,
	CIRCULAR,
}

## このシーンスコープで利用する依存コンテナ
var _container: InjectionContainer

## 重複初期化と親子間の再帰初期化を防ぐ状態
var _state: State = State.NOT_INITIALIZED

## プロジェクト内のコンテナ情報のリスト
const CONTAINER_LIST := preload("res://addons/tscn_scanner/container_list.tres")

## コンテナ用グループ名
const CONTAINER_GROUP := &"test_group"

## コンテナIDの長さ
const UID_LENGTH := 8

@export var _scope_id: StringName
var scope_id: StringName:
	get:
		return _scope_id

@export_storage var _scope_uid: StringName
var scope_uid: StringName:
	get:
		return _scope_uid

@export var _perent_scope_id: StringName
var parent_scope_id: StringName:
	get:
		return _perent_scope_id

## 注入対象
@export var _inject_target: Array[Node] = []

func _enter_tree() -> void:
	var is_in_group := is_in_group(CONTAINER_GROUP)

	if not is_in_group:
			add_to_group(CONTAINER_GROUP, true)

	# エディタのみで実行
	if Engine.is_editor_hint():
		if not is_in_group:
			EditorInterface.mark_scene_as_unsaved()
		return


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_ensure_initialized()


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	_stop_initialization_retry()

	if _container != null:
		_container.clear()

	_container = null
	_state = State.NOT_INITIALIZED


## 論理IDが一致する親スコープを取得
func _find_parent_scope() -> ContainerScope:
	if _perent_scope_id.is_empty():
		return null

	var matched: Array[ContainerScope] = []

	for node in get_tree().get_nodes_in_group(CONTAINER_GROUP):
		var scope := node as ContainerScope
		
		if scope != null \
				and scope != self \
				and scope.scope_id == _perent_scope_id:
			matched.append(scope)

	if matched.size() != 1:
		push_error(
				"親スコープ '%s' は1個必要ですが、%d個見つかりました。"
				% [_perent_scope_id, matched.size()]
		)
		return null
	
	return matched[0]


## 親コンテナを先に構築し、このスコープを一度だけ初期化
func _ensure_initialized() -> void:
	if _state == State.INITIALIZED:
		return
	if _state == State.INITIALIZING:
		push_error("コンテナの親子関係が循環しています: %s" % scope_id)
		_state = State.CIRCULAR
		_stop_initialization_retry()
		return

	_state = State.INITIALIZING

	var parent_scope := _find_parent_scope()
	
	if not _perent_scope_id.is_empty() and parent_scope == null:
		_state = State.NOT_INITIALIZED
		_start_initialization_retry()
		return

	var parent_container: InjectionContainer = null
	if parent_scope != null:
		parent_scope._ensure_initialized()
		if parent_scope._state != State.INITIALIZED:
			_state = State.NOT_INITIALIZED
			_start_initialization_retry()
			return
		parent_container = parent_scope._container

	_container = InjectionContainer.new(parent_container)
	
	_register_instance(_container)

	if not _inject_dependencies():
		_container.clear()
		_container = null
		_state = State.NOT_INITIALIZED
		return

	_state = State.INITIALIZED
	
	_stop_initialization_retry()


## 登録完了後、指定されたすべてのノードへ依存を注入
func _inject_dependencies() -> bool:
	for target in _inject_target:
		if target == null:
			push_error(
					"依存注入対象が null です: 対象=<null>, 引数=<none>, 要求型=<none>, スコープID=%s"
					% scope_id
			)
			return false
		if not is_instance_valid(target):
			push_error(
					"依存注入対象は既に解放されています: 対象=<freed>, 引数=<none>, 要求型=<none>, スコープID=%s"
					% scope_id
			)
			return false
		if not target.is_inside_tree():
			push_error(
					"依存注入対象はツリーから削除されています: 対象=%s, 引数=<none>, 要求型=<none>, スコープID=%s"
					% [target.name, scope_id]
			)
			return false
		if target.get_script() == null:
			push_error(
					"依存注入対象にスクリプトがありません: 対象=%s, 引数=<none>, 要求型=<none>, スコープID=%s"
					% [target.get_path(), scope_id]
			)
			return false
		if not _inject_target_node(target):
			return false

	return true


## 1ノード分の引数を宣言順に解決し、すべて揃った場合だけ注入メソッドを呼ぶ
func _inject_target_node(target: Node) -> bool:
	var script := target.get_script() as Script
	var arguments := MethodReader.get_injection_arguments(script)
	var resolved_arguments: Array = []

	for argument in arguments:
		var service_script := _find_global_class_script(argument.arg_class)
		if service_script == null:
			_push_injection_error(
					target,
					argument,
					"要求型に対応するグローバルクラスが見つかりません"
			)
			return false

		var resolved_service: Variant = _container.resolve(service_script)
		if resolved_service == null:
			_push_injection_error(target, argument, "サービスを解決できませんでした")
			return false
		resolved_arguments.append(resolved_service)

	var injection_method := Callable(target, MethodReader.METHOD_NAME)
	if not injection_method.is_valid():
		push_error(
				"依存注入メソッドを呼び出せません: 対象=%s, 引数=<none>, 要求型=<none>, スコープID=%s"
				% [target.get_path(), scope_id]
		)
		return false

	target.callv(MethodReader.METHOD_NAME, resolved_arguments)
	return true


## class_name からコンテナの解決に必要な Script を取得
func _find_global_class_script(class_name_to_find: StringName) -> Script:
	for class_data: Dictionary in ProjectSettings.get_global_class_list():
		if StringName(class_data.get("class", "")) == class_name_to_find:
			return load(class_data.get("path", "")) as Script
	return null


func _push_injection_error(
	target: Node,
	argument: ArgumentData,
	reason: String,
) -> void:
	push_error(
			"依存注入に失敗しました（%s）: 対象=%s, 引数=%s, 要求型=%s, スコープID=%s"
			% [reason, target.get_path(), argument.arg_name, argument.arg_class, scope_id]
	)


# 後から追加されたのが親スコープかもしれないのでツリーへの追加を監視
func _start_initialization_retry() -> void:
	var node_added := get_tree().node_added
	if not node_added.is_connected(_on_node_added):
		node_added.connect(_on_node_added)


# 親スコープを確認できたのでツリー監視の必要はもうない
func _stop_initialization_retry() -> void:
	var node_added := get_tree().node_added
	if node_added.is_connected(_on_node_added):
		node_added.disconnect(_on_node_added)


func _on_node_added(_node: Node) -> void:
	# node_added の発火中では候補の _enter_tree() が完了していない場合がある
	# node_added が全部終わってから、ツリーへの追加が終わってから実行する
	_ensure_initialized.call_deferred()


## 具体コンテナが登録内容を定義
@abstract
func _register_instance(container: InjectionContainer) -> void
