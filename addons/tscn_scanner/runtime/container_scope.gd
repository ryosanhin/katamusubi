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

var scope_name: StringName:
	get:
		return name

@export_storage var scope_id: StringName

@export_storage var parent_scope_name: StringName

@export_storage var parent_scope_id: StringName

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
	if parent_scope_name.is_empty():
		return null

	var matched: Array[ContainerScope] = []

	for node in get_tree().get_nodes_in_group(CONTAINER_GROUP):
		var scope := node as ContainerScope
		
		if scope != null \
				and scope != self \
				and scope.scope_name == parent_scope_name:
			matched.append(scope)

	if matched.size() != 1:
		push_error(
				"親スコープ '%s' は1個必要ですが、%d個見つかりました。"
				% [parent_scope_name, matched.size()]
		)
		return null
	
	return matched[0]


## 親コンテナを先に構築し、このスコープを一度だけ初期化
func _ensure_initialized() -> void:
	if _state == State.INITIALIZED:
		return
	if _state == State.INITIALIZING:
		push_error("コンテナの親子関係が循環しています: %s" % scope_name)
		_state = State.CIRCULAR
		_stop_initialization_retry()
		return

	_state = State.INITIALIZING

	var parent_scope := _find_parent_scope()
	
	if not parent_scope_name.is_empty() and parent_scope == null:
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

	# 登録完了後、指定されたすべてのノードへ依存を注入
	if not _inject_dependencies():
		_container.clear()
		_container = null
		_state = State.NOT_INITIALIZED
		return

	_state = State.INITIALIZED
	
	_stop_initialization_retry()


func _inject_dependencies() -> bool:
	var injector := InstanceInjector.new(_container, scope_name)

	for target in _inject_target:
		if not injector.try_inject_arguments(target):
			return false
	
	return true


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
