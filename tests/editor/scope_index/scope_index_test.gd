extends SceneTree

const ScopeIndex := preload("res://addons/katamusubi/editor/scope_index.gd")
var _runner := TestRunner.new(true)


func _init() -> void:
	_test_scene_replacement()
	_test_zero_candidates()
	await _runner.finish(self, "ScopeIndex")


func _test_scene_replacement() -> void:
	_runner.change_test_name("scene replacement")
	var index := ScopeIndex.new()
	index.scope_snapshots = [
		_candidate(&"a", &"old"),
		_candidate(&"b", &"same"),
	]
	var replacements: Array[ScopeSnapshot] = [
		_candidate(&"a", &"same"),
		_candidate(&"a", &"same"),
	]
	_runner.assert_true(index.replace_scene_snapshots(&"a", replacements), "シーン単位で置換できる")
	_runner.assert_equal(index.scope_snapshots.size(), 3, "同名候補をシーン横断で全件保持する")
	_runner.assert_equal(index.scope_snapshots[0].scene_uid, &"b", "他シーンの候補を保持する")
	_runner.assert_equal(index.scope_snapshots[1].scene_uid, &"a", "置換した候補は登録元のシーンUIDを保持する")
	_runner.assert_equal(index.scope_snapshots[1].scope_id, &"same", "置換した候補はスコープIDを保持する")


func _test_zero_candidates() -> void:
	_runner.change_test_name("successful empty replacement")
	var index := ScopeIndex.new()
	index.scope_snapshots = [_candidate(&"a", &"old")]
	var empty: Array[ScopeSnapshot] = []
	_runner.assert_true(index.replace_scene_snapshots(&"a", empty), "候補ゼロを成功として扱う")
	_runner.assert_equal(index.scope_snapshots.size(), 0, "候補ゼロで対象シーンを空にする")


func _candidate(scene: StringName, id: StringName) -> ScopeSnapshot:
	return ScopeSnapshot.new(scene, id)
