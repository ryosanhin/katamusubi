@tool
extends RefCounted

var scene_uid: StringName
var scope_name: StringName
var scope_id: StringName
var parent_scope_id: StringName
var node_path: NodePath
var has_script: bool
var inherits_container_scope: bool


## コンストラクタ[br]
## ---ここからスコープ定義用---[br]
## [param init_scene_uid]: スキャンしたシーンのUID[br]
## [param init_scope_name]: スコープのノードの名前[br]
## [param init_scope_id]: スコープのID[br]
## [param init_parent_scope_id]: 親スコープのID
## ---ここまでスコープ定義用---[br]
## ---ここから静的確認用---[br]
## [param init_node_path]: ノードのパス（エラーメッセージで表示する）[br]
## [param init_has_script]: スクリプトを持っているか[br]
## [param init_inherits_container_scope]: [code]ContainerScope[/code]を継承しているか[br]
## ---ここまで静的確認用---
func _init(
	init_scene_uid: StringName,
	init_scope_name: StringName,
	init_scope_id: StringName,
	init_parent_scope_id: StringName,
	init_node_path: NodePath,
	init_has_script: bool,
	init_inherits_container_scope: bool,
) -> void:
	scene_uid = init_scene_uid
	scope_name = init_scope_name
	scope_id = init_scope_id
	parent_scope_id = init_parent_scope_id
	node_path = init_node_path
	has_script = init_has_script
	inherits_container_scope = init_inherits_container_scope
