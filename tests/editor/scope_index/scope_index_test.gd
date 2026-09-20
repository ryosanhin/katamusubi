extends SceneTree

const ScopeIndex := preload("res://addons/katamusubi/editor/scope_index.gd")
var _runner := TestRunner.new(true)


func _init() -> void:
	_test_scene_replacement_and_duplicates()
	_test_zero_candidates()
	await _runner.finish(self, "ScopeIndex")


func _test_scene_replacement_and_duplicates() -> void:
	_runner.change_test_name("scene replacement keeps duplicates")
	var index := ScopeIndex.new()
	index.scope_snapshots = [_candidate(&"a", "Old", &"old"), _candidate(&"b", "One", &"same")]
	var replacements: Array[ScopeSnapshot] = [
		_candidate(&"a", "One", &"same"), _candidate(&"a", "Two", &"same")]
	_runner.assert_true(index.replace_scene_snapshots(&"a", replacements), "シーン単位で置換できる")
	_runner.assert_equal(index.find_by_id(&"same").size(), 3, "同名候補をシーン横断で全件保持する")
	_runner.assert_equal(index.find_by_id(&"old").size(), 0, "古い候補を除去する")
	_runner.assert_equal(index.find_by_id(&"same")[1].node_path, NodePath("One"), "NodePathを保持する")


func _test_zero_candidates() -> void:
	_runner.change_test_name("successful empty replacement")
	var index := ScopeIndex.new()
	index.scope_snapshots = [_candidate(&"a", "Old", &"old")]
	var empty: Array[ScopeSnapshot] = []
	_runner.assert_true(index.replace_scene_snapshots(&"a", empty), "候補ゼロを成功として扱う")
	_runner.assert_equal(index.scope_snapshots.size(), 0, "候補ゼロで対象シーンを空にする")


func _candidate(scene: StringName, path: NodePath, id: StringName) -> ScopeSnapshot:
	return ScopeSnapshot.new(scene, path, id)
