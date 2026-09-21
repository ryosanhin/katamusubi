extends SceneTree

const ScopeIndex := preload("res://addons/katamusubi/editor/scope_index.gd")
var _runner := TestRunner.new(true)


func _init() -> void:
	_test_scene_replacement_and_duplicates()
	_test_zero_candidates()
	_test_duplicates_excluding_origin()
	await _runner.finish(self, "ScopeIndex")


func _test_scene_replacement_and_duplicates() -> void:
	_runner.change_test_name("scene replacement keeps duplicates")
	var index := ScopeIndex.new()
	index.scope_snapshots = [
		_candidate(&"a", ^"Root/Old", &"old"),
		_candidate(&"b", ^"Root/Same", &"same"),
	]
	var replacements: Array[ScopeSnapshot] = [
		_candidate(&"a", ^"Root/First", &"same"),
		_candidate(&"a", ^"Root/Second", &"same"),
	]
	_runner.assert_true(index.replace_scene_snapshots(&"a", replacements), "シーン単位で置換できる")
	_runner.assert_equal(index.find_by_id(&"same").size(), 3, "同名候補をシーン横断で全件保持する")
	_runner.assert_equal(index.find_by_id(&"old").size(), 0, "古い候補を除去する")
	_runner.assert_equal(index.find_by_id(&"same")[1].scene_uid, &"a", "候補は登録元のシーンUIDを保持する")
	_runner.assert_equal(index.find_by_id(&"same")[1].node_path, ^"Root/First", "候補は登録元のNodePathを保持する")


func _test_zero_candidates() -> void:
	_runner.change_test_name("successful empty replacement")
	var index := ScopeIndex.new()
	index.scope_snapshots = [_candidate(&"a", ^"Root/Old", &"old")]
	var empty: Array[ScopeSnapshot] = []
	_runner.assert_true(index.replace_scene_snapshots(&"a", empty), "候補ゼロを成功として扱う")
	_runner.assert_equal(index.scope_snapshots.size(), 0, "候補ゼロで対象シーンを空にする")


func _test_duplicates_excluding_origin() -> void:
	_runner.change_test_name("duplicates excluding origin")
	var index := ScopeIndex.new()
	index.scope_snapshots = [_candidate(&"scene_a", ^"Root/Scope", &"shared")]
	_runner.assert_false(
		index.has_duplicate(&"shared", &"scene_a", ^"Root/Scope"),
		"同じ登録元にある自身だけなら重複にならない",
	)

	index.scope_snapshots.append(_candidate(&"scene_a", ^"Root/OtherScope", &"shared"))
	_runner.assert_true(
		index.has_duplicate(&"shared", &"scene_a", ^"Root/Scope"),
		"同じシーンでも別のNodePathなら重複になる",
	)

	index.scope_snapshots = [
		_candidate(&"scene_a", ^"Root/Scope", &"shared"),
		_candidate(&"scene_b", ^"Root/OtherScope", &"shared"),
	]
	_runner.assert_true(
		index.has_duplicate(&"shared", &"scene_a", ^"Root/Scope"),
		"別シーンの同じIDは重複になる",
	)

	index.scope_snapshots = [_candidate(&"scene_b", ^"Root/Scope", &"shared")]
	_runner.assert_true(
		index.has_duplicate(&"shared", &"scene_a", ^"Root/Scope"),
		"同じNodePathでも別シーンなら除外しない",
	)
	_runner.assert_false(
		index.has_duplicate(&"", &"scene_a", ^"Root/Scope"),
		"空のIDは重複にならない",
	)


func _candidate(scene: StringName, node_path: NodePath, id: StringName) -> ScopeSnapshot:
	return ScopeSnapshot.new(scene, node_path, id)
