extends SceneTree

const ScopeIndex := preload("res://addons/katamusubi/editor/scope_index.gd")

var _failures: PackedStringArray = []


func _init() -> void:
	_test_replace_scene_definitions()
	_test_duplicate_is_atomic()
	_test_rollback_restores_copies()

	if _failures.is_empty():
		print("ScopeIndex tests passed")
		quit()
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_replace_scene_definitions() -> void:
	var index := ScopeIndex.new()
	index.scope_definitions = [
		_definition(&"scene_a", &"old"),
		_definition(&"scene_b", &"other"),
	]
	var replacements: Array[ScopeDefinition] = [_definition(&"scene_a", &"new")]

	var action := index.replace_scene_definitions(&"scene_a", replacements)

	_expect(action.operation_succeeded, "シーン単位の置換が成功する")
	_expect(index.get_scope_definition(&"old") == null, "置換前の定義が除去される")
	_expect(index.get_scope_definition(&"new") != null, "置換後の定義が追加される")
	_expect(index.get_scope_definition(&"other") != null, "他シーンの定義が維持される")


func _test_duplicate_is_atomic() -> void:
	var index := ScopeIndex.new()
	var original := _definition(&"scene_a", &"original")
	index.scope_definitions = [original, _definition(&"scene_b", &"duplicate")]
	var replacements: Array[ScopeDefinition] = [_definition(&"scene_a", &"duplicate")]

	var action := index.replace_scene_definitions(&"scene_a", replacements)

	_expect(not action.operation_succeeded, "他シーンとのID重複を拒否する")
	_expect(index.scope_definitions.size() == 2, "重複時に一覧を変更しない")
	_expect(index.scope_definitions[0] == original, "重複時に元の定義を維持する")


func _test_rollback_restores_copies() -> void:
	var index := ScopeIndex.new()
	var original := _definition(&"scene_a", &"original", &"parent")
	index.scope_definitions = [original]
	var replacements: Array[ScopeDefinition] = [_definition(&"scene_a", &"new")]
	var action := index.replace_scene_definitions(&"scene_a", replacements)
	original.parent_scope_id = &"mutated_after_replace"

	action.rollback()

	var restored := index.get_scope_definition(&"original")
	_expect(restored != null, "ロールバックで置換前の定義を復元する")
	_expect(restored != original, "ロールバックでは定義の複製を復元する")
	_expect(restored.parent_scope_id == &"parent", "複製した全フィールドを復元する")


func _definition(
	scene_uid: StringName,
	scope_id: StringName,
	parent_scope_id: StringName = &"",
) -> ScopeDefinition:
	return ScopeDefinition.new(scene_uid, scope_id, scope_id, parent_scope_id)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
