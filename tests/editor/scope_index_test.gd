extends SceneTree


const ScopeIndex := preload("res://addons/katamusubi/editor/scope_index.gd")

## falseにすると各成功項目を省略し、最終結果とエラーだけを表示します。
const SHOW_PASSED_EXPECTATIONS := true

var _failures: PackedStringArray = []


func _init() -> void:
	_test_replace_scene_snapshots()
	_test_duplicate_is_atomic()
	_test_same_scene_duplicate_remains_build_visible()
	_test_rollback_restores_copies()

	if _failures.is_empty():
		print("ScopeIndex tests passed")
		quit()
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_replace_scene_snapshots() -> void:
	var index := ScopeIndex.new()
	index.scope_snapshots = [
		_definition(&"scene_a", &"old"),
		_definition(&"scene_b", &"other"),
	]
	var replacements: Array[ScopeDefinition] = [_definition(&"scene_a", &"new")]

	var action := index.replace_scene_snapshots(&"scene_a", replacements)

	_expect(action.operation_succeeded, "シーン単位の置換が成功する")
	_expect(index.get_scope_snapshot(&"old") == null, "置換前の定義が除去される")
	_expect(index.get_scope_snapshot(&"new") != null, "置換後の定義が追加される")
	_expect(index.get_scope_snapshot(&"other") != null, "他シーンの定義が維持される")


func _test_duplicate_is_atomic() -> void:
	var index := ScopeIndex.new()
	var original := _definition(&"scene_a", &"original")
	index.scope_snapshots = [original, _definition(&"scene_b", &"duplicate")]
	var replacements: Array[ScopeDefinition] = [_definition(&"scene_a", &"duplicate")]

	var action := index.replace_scene_snapshots(&"scene_a", replacements)

	_expect(not action.operation_succeeded, "他シーンとのID重複を拒否する")
	_expect(index.scope_snapshots.size() == 2, "重複時に一覧を変更しない")
	_expect(index.scope_snapshots[0] == original, "重複時に元の定義を維持する")


func _test_same_scene_duplicate_remains_build_visible() -> void:
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
	var index := ScopeIndex.new()
	var original := _definition(&"scene_a", &"original", &"parent")
	index.scope_snapshots = [original]
	var replacements: Array[ScopeDefinition] = [_definition(&"scene_a", &"new")]
	var action := index.replace_scene_snapshots(&"scene_a", replacements)
	original.parent_scope_id = &"mutated_after_replace"

	action.rollback()

	var restored := index.get_scope_snapshot(&"original")
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
	# 成功は設定に応じて都度表示し、失敗は最後にまとめて報告します。
	if condition:
		if SHOW_PASSED_EXPECTATIONS:
			print("[PASS] %s" % message)
		return

	_failures.append(message)
