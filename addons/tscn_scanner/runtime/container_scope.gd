@tool
@abstract
extends Node

## コンテナ初期化の内部状態
enum State {
	NOT_INITIALIZED,
	INITIALIZING,
	INITIALIZED,
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


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	_ensure_initialized()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_ensure_initialized()


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return

	if _container != null:
		_container.clear()

	_container = null
	_state = State.NOT_INITIALIZED


## 最も近い祖先コンテナを親として、このスコープを一度だけ初期化[br]
## 祖先にContainerManagerが存在しなければルートコンテナになる
func _ensure_initialized() -> void:
	if _state == State.INITIALIZING or _state == State.INITIALIZED:
		return

	_state = State.INITIALIZING

	var contaienrs := get_tree().get_nodes_in_group(CONTAINER_GROUP)

## 具体コンテナが登録内容を定義
@abstract
func _register_instance(parent: InjectionContainer = null) -> void
