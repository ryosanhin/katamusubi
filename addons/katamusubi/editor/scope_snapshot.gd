@tool
extends Resource
class_name ScopeSnapshot

## スキャン結果と保存済み索引で共通して使うスコープ記述。
## 値の正本は保存済みシーン内の[ContainerScope]。
## シーンスキャン中だけノードパスとScript検証結果も保持する。

## スコープのノードが存在するシーンのuid
@export var scene_uid: StringName

## スコープのノードの名前
@export var scope_name: StringName

## スコープのID
@export var scope_id: StringName

## 親スコープのID
@export var parent_scope_id: StringName

## スキャン時のノードパス。索引には保存しない。
var node_path: NodePath

## スキャン時にScriptが設定されていたか。索引には保存しない。
var has_script: bool

## スキャン時のScriptが[ContainerScope]を継承していたか。索引には保存しない。
var inherits_container_scope: bool

## コンストラクタ[br]
## 仕様上デフォルト引数が設定されているが、代入必須[br]
## [param init_scene_uid]: スコープのノードが存在するシーンのuid[br]
## [param init_scope_name]: スコープのノードの名前[br]
## [param init_scope_id]: スコープのID[br]
## [param init_parent_scope_id]: 親スコープのID[br]
## [param init_node_path]: スキャン時のノードパス[br]
## [param init_has_script]: スキャン時にScriptが設定されていたか[br]
## [param init_inherits_container_scope]: Scriptが[ContainerScope]を継承していたか
func _init(
	init_scene_uid: StringName = &"",
	init_scope_name: StringName = &"",
	init_scope_id: StringName = &"",
	init_parent_scope_id: StringName = &"",
	init_node_path: NodePath = NodePath(),
	init_has_script: bool = false,
	init_inherits_container_scope: bool = false,
) -> void:
	scene_uid = init_scene_uid
	scope_name = init_scope_name
	scope_id = init_scope_id
	parent_scope_id = init_parent_scope_id
	node_path = init_node_path
	has_script = init_has_script
	inherits_container_scope = init_inherits_container_scope


## 索引保存用の複製を返す。スキャン中だけ必要な一時フィールドは明示的に除外する。
func to_saved_snapshot() -> ScopeSnapshot:
	return ScopeSnapshot.new(
			scene_uid,
			scope_name,
			scope_id,
			parent_scope_id,
	)

func _to_string() -> String:
	var path := ResourceUID.uid_to_path(scene_uid)
	return """
		scene_uid: %s
		scope_name: %s
		scope_id: %s
		parent_scope_id: %s
	""" % [
		path,
		scope_name,
		scope_id,
		parent_scope_id,
	]
