@tool
extends Resource
class_name ScopeSnapshot

## 保存時点のスコープ情報を保持する読み取り用スナップショット。
## 値の正本は保存済みシーン内の[ContainerScope]。

## スコープのノードが存在するシーンのuid
@export var scene_uid: StringName

## スコープのノードの名前
@export var scope_name: StringName

## スコープのID
@export var scope_id: StringName

## 親スコープのID
@export var parent_scope_id: StringName

## コンストラクタ[br]
## 仕様上デフォルト引数が設定されているが、代入必須[br]
## [param init_scene_uid]: スコープのノードが存在するシーンのuid[br]
## [param init_scope_name]: スコープのノードの名前[br]
## [param init_scope_id]: スコープのID[br]
## [param init_parent_scope_id]: 親スコープのID
func _init(
	init_scene_uid: StringName = &"",
	init_scope_name: StringName = &"",
	init_scope_id: StringName = &"",
	init_parent_scope_id: StringName = &"",
) -> void:
	scene_uid = init_scene_uid
	scope_name = init_scope_name
	scope_id = init_scope_id
	parent_scope_id = init_parent_scope_id

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
