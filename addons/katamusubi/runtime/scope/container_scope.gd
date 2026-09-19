@abstract
extends Node
class_name ContainerScope

const InstanceInjector := preload("../injection/instance_injector.gd")

## スコープのスクリプトがアタッチされているノードのグループ名
const GROUP_NAME := &"test_group"

## コンテナ初期化の内部状態
enum State {
	NOT_INITIALIZED,
	INITIALIZING,
	INITIALIZED,
	CIRCULAR,
	FAILED,
}

## このシーンスコープで利用する依存コンテナ
var _container: InjectionContainer

## 重複初期化と親子間の再帰初期化を防ぐ状態
var state: State = State.NOT_INITIALIZED

var scope_name: StringName:
	get:
		return name

## 自身のスコープID
@export_storage var scope_id: StringName

## 親スコープID
@export_storage var parent_scope_id: StringName

## エディターの親スコープ候補として公開するか
@export var selectable_as_parent := false

## 注入対象
@export var _inject_targets: Array[Node] = []


func _ready() -> void:
	_initialize_scope()


func _exit_tree() -> void:
	if _container != null:
		_container.clear()

	_container = null
	state = State.NOT_INITIALIZED


## 論理IDが一致する親スコープを取得
func _find_parent_scope() -> ContainerScope:
	if parent_scope_id.is_empty():
		return null

	var matched: Array[ContainerScope] = []

	for node in get_tree().get_nodes_in_group(GROUP_NAME):
		var scope := node as ContainerScope
		
		if (
				scope != null
				and scope != self
				and scope.scope_id == parent_scope_id
		):
			matched.append(scope)

	if matched.size() != 1:
		push_error(
				"親スコープID '%s' は1個必要ですが、%d個見つかりました。"
				% [parent_scope_id, matched.size()]
		)
		return null
	
	return matched[0]


## 親コンテナを先に構築し、このスコープを一度だけ初期化
func _initialize_scope() -> bool:
	if state == State.INITIALIZED:
		return true
	if state == State.FAILED or state == State.CIRCULAR:
		return false
	if state == State.INITIALIZING:
		push_error("コンテナの親子関係が循環しています: %s" % scope_name)
		state = State.CIRCULAR
		return false

	state = State.INITIALIZING

	var parent_container: InjectionContainer = null
	if not parent_scope_id.is_empty():
		var parent_scope := _find_parent_scope()
		
		# 親スコープが見つからない場合は初期化を失敗させる
		if parent_scope == null:
			push_error(
				"スコープ '%s' (scope_id: '%s') が要求する親スコープ (parent_scope_id: '%s') が見つかりません。"
				% [scope_name, scope_id, parent_scope_id]
			)
			state = State.FAILED
			return false

		# 先に親スコープを初期化
		if not parent_scope._initialize_scope():
			push_error(
				"スコープ '%s' (scope_id: '%s') は親スコープ (parent_scope_id: '%s') の初期化に失敗したため初期化できません。"
				% [scope_name, scope_id, parent_scope_id]
			)
			# 再帰呼び出しの途中で自身が循環元と判定された場合は、診断用の状態を
			# FAILED で上書きしない。循環元を待っていた側は通常どおり FAILED になる。
			if state != State.CIRCULAR:
				state = State.FAILED
			return false
		# 親スコープのコンテナを取得
		parent_container = parent_scope._container

	_container = InjectionContainer.new(parent_container)
	
	_register_instance(_container)
	if _container.has_registration_errors:
		_container.clear()
		_container = null
		state = State.FAILED
		return false

	# 登録完了後、指定されたすべてのノードへ依存を注入
	if not _inject_dependencies():
		_container.clear()
		_container = null
		state = State.FAILED
		return false
	state = State.INITIALIZED
	return true


func _inject_dependencies() -> bool:
	var injector := InstanceInjector.new(_container, scope_name)

	for target in _inject_targets:
		if not injector.try_inject_arguments(target):
			return false
	
	return true


## 具体コンテナが登録内容を定義します。
@abstract
func _register_instance(container: InjectionContainer) -> void
