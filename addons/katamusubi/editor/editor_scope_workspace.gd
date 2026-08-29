@tool
extends RefCounted

const ScopeIndex := preload("scope_index.gd")

## インデックス読み込み時から変更がないスコープ定義
var stable_scope_snapshot: Array[ScopeDefinition] = []

## インデックス読み込み時から変更があったスコープ定義
var active_scope_snapshot: Array[ScopeDefinition] = []


signal scope_added(scope_id: StringName)
signal scope_removed(scope_id: StringName)
signal scope_changed(scope_id: StringName)


func _init(init_index: ScopeIndex) -> void:
	for def in init_index.scope_snapshots:
		# 人力ディープコピー
		stable_scope_snapshot.append(
				ScopeDefinition.new(
						def.scene_uid,
						def.scope_name,
						def.scope_id,
						def.parent_scope_id,
				)
		)


func get_scope_snapshots() -> Array[ScopeDefinition]:
	return stable_scope_snapshot + active_scope_snapshot


## スコープIDから編集中のスコープ定義を取得
func get_scope_snapshot(scope_id: StringName) -> ScopeDefinition:
	for definition in get_scope_snapshots():
		if definition.scope_id == scope_id:
			return definition
	return null
