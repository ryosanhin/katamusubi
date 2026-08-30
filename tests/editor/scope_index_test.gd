extends SceneTree


const ScopeIndex := preload("res://addons/katamusubi/editor/scope_index.gd")
const TestRunnerScript := preload("res://tests/support/test_runner.gd")

var _runner := TestRunnerScript.new()


func _init() -> void:
	_test_replace_scene_snapshots()
	_test_duplicate_is_atomic()
	_test_same_scene_duplicate_remains_build_visible()
	_test_rollback_restores_copies()

	await _runner.finish(self, "ScopeIndex")


func _test_replace_scene_snapshots() -> void:
	_runner.begin_test("replace_scene_snapshots")
	var index := ScopeIndex.new()
	index.scope_snapshots = [
		_definition(&"scene_a", &"old"),
		_definition(&"scene_b", &"other"),
	]
	var replacements: Array[ScopeDefinition] = [_definition(&"scene_a", &"new")]

	var action := index.replace_scene_snapshots(&"scene_a", replacements)

	_runner.assert_true(action.operation_succeeded, "シーン単位の置換が成功する")
	_runner.assert_null(index.get_scope_snapshot(&"old"), "置換前の定義が除去される")
	_expect(index.get_scope_snapshot(&"new") != null, "置換後の定義が追加される")
	_expect(index.get_scope_snapshot(&"other") != null, "他シーンの定義が維持される")


func _test_duplicate_is_atomic() -> void:
	_runner.begin_test("duplicate_is_atomic")
	var index := ScopeIndex.new()
	var original := _definition(&"scene_a", &"original")
	index.scope_snapshots = [original, _definition(&"scene_b", &"duplicate")]
	var replacements: Array[ScopeDefinition] = [_definition(&"scene_a", &"duplicate")]

	var action := index.replace_scene_snapshots(&"scene_a", replacements)

	_expect(not action.operation_succeeded, "他シーンとのID重複を拒否する")
	_runner.assert_equal(index.scope_snapshots.size(), 2, "重複時に一覧を変更しない")
	_runner.assert_same(index.scope_snapshots[0], original, "重複時に元の定義を維持する")


func _test_same_scene_duplicate_remains_build_visible() -> void:
	_runner.begin_test("same_scene_duplicate_remains_build_visible")
	var index := ScopeIndex.new()
	var replacements: Array[ScopeDefinition] = [
		_definition(&"scene_a", &"duplicate"),
		_definition(&"scene_a", &"duplicate"),
	]

	var action := index.replace_scene_snapshots(&"scene_a", replacements)

	_expect(action.operation_succeeded, "同一シーン内の重複はシーンの登録を維持する")
	_expect(index.scope_snapshots.size() == 1, "重複IDの代表スナップショットを1件登録する")
	_expect(index.scope_snapshots[0].scene_uid == &"scene_a", "ビルド時の再スキャン対象を維持する")


func _test_rollback_restores_copies() -> void:
	_runner.begin_test("rollback_restores_copies")
	var index := ScopeIndex.new()
	var original := _definition(&"scene_a", &"original", &"parent")
	index.scope_snapshots = [original]
	var replacements: Array[ScopeDefinition] = [_definition(&"scene_a", &"new")]
	var action := index.replace_scene_snapshots(&"scene_a", replacements)
	original.parent_scope_id = &"mutated_after_replace"

	action.rollback()

	var restored := index.get_scope_snapshot(&"original")
	_expect(restored != null, "ロールバックで置換前の定義を復元する")
	_runner.assert_not_equal(restored, original, "ロールバックでは定義の複製を復元する")
	_runner.assert_equal(restored.parent_scope_id, &"parent", "複製した全フィールドを復元する")


func _definition(
	scene_uid: StringName,
	scope_id: StringName,
	parent_scope_id: StringName = &"",
) -> ScopeDefinition:
	return ScopeDefinition.new(scene_uid, scope_id, scope_id, parent_scope_id)


func _expect(condition: bool, message: String) -> void:
	_runner.assert_true(condition, message)
