@tool
extends RefCounted

const ScopeIndex := preload("../runtime/scope_index.gd")

## インデックス読み込み時から変更がないスコープ定義
var stable_scope_definitions: Array[ScopeDefinition] = []

## インデックス読み込み時から変更があったスコープ定義
var active_scope_definitions: Array[ScopeDefinition] = []


signal scope_added(scope_id: StringName)
signal scope_removed(scope_id: StringName)
signal scope_changed(scope_id: StringName)


func _init(init_index: ScopeIndex) -> void:
	for def in init_index.scope_definitions:
		# 人力ディープコピー
		stable_scope_definitions.append(
				ScopeDefinition.new(
						def.scene_uid,
						def.scope_name,
						def.scope_id,
						def.parent_scope_id,
				)
		)


func get_scope_definitions() -> Array[ScopeDefinition]:
	return stable_scope_definitions + active_scope_definitions
