extends SceneTree

const ScopeIndex := preload("res://addons/katamusubi/editor/scope_index.gd")
const TscnScanner := preload("res://addons/katamusubi/editor/scanning/tscn_scanner.gd")
const ParentScopeIdEditorProperty := preload(
		"res://addons/katamusubi/editor/inspector/parent_scope_id_editor_property.gd"
)
var _runner := TestRunner.new(true)


func _init() -> void:
	_test_scanner_and_failure()
	_test_candidate_preview_and_search()
	await _runner.finish(self, "ParentScopeSelection")


func _test_scanner_and_failure() -> void:
	_runner.change_test_name("scanner")
	var result := TscnScanner.scan(&"res://tests/editor/parent_scope_selection/fixtures/scopes/basic_scope.tscn")
	_runner.assert_true(result.succeeded, "保存済みScriptの継承をインスタンス化せず判定する")
	_runner.assert_equal(result.entries.size(), 1, "非空IDだけを候補にする")
	_runner.assert_equal(result.entries[0].scope_id, &"basic", "実行時の解決に必要なスコープIDを保持する")
	_runner.assert_equal(
			result.entries[0].scene_uid,
			&"res://tests/editor/parent_scope_selection/fixtures/scopes/basic_scope.tscn",
			"候補の表示に必要なシーンUIDを保持する",
	)
	var failure := TscnScanner.scan(&"res://missing_scene.tscn")
	_runner.assert_false(failure.succeeded, "スキャン失敗を候補ゼロと区別する")
	_runner.assert_true(not failure.error_message.is_empty(), "スキャン失敗の理由を保持する")


func _test_candidate_preview_and_search() -> void:
	_runner.change_test_name("candidate preview and search")
	var index := ScopeIndex.new()
	var first_id := ResourceUID.create_id()
	var second_id := ResourceUID.create_id()
	ResourceUID.add_id(first_id, "res://first_scene.tscn")
	ResourceUID.add_id(second_id, "res://second_scene.tscn")
	var first_scene_uid := ResourceUID.id_to_text(first_id)
	var second_scene_uid := ResourceUID.id_to_text(second_id)
	index.scope_snapshots = [
		ScopeSnapshot.new(first_scene_uid, ^"Root/FirstScope", &"ParentScope"),
		ScopeSnapshot.new(second_scene_uid, ^"Root/SecondScope", &"OtherScope"),
	]
	var editor := ParentScopeIdEditorProperty.new(index)
	var candidates := editor._get_candidate_preview()
	_runner.assert_equal(candidates.size(), 2, "保存済み索引から補完候補を作成する")
	_runner.assert_true(candidates.values().has(&"ParentScope"), "候補はスコープIDを値に持つ")

	editor._on_text_changed("parent")
	_runner.assert_equal(editor._item_list.item_count, 1, "候補を大文字小文字を区別せず部分一致で絞り込む")
	_runner.assert_true(editor._item_list.visible, "一致する候補があるときは一覧を表示する")

	editor._on_text_changed("")
	_runner.assert_equal(editor._item_list.item_count, 0, "空入力で候補を消去する")
	_runner.assert_false(editor._item_list.visible, "空入力で一覧を非表示にする")

	editor._line_edit.text = "NotInCandidates"
	_runner.assert_equal(editor._line_edit.text, "NotInCandidates", "候補外のスコープIDも自由入力できる")
	var submit_connections := editor._line_edit.text_submitted.get_connections()
	_runner.assert_equal(submit_connections.size(), 1, "入力の送信を確定処理に接続する")
	_runner.assert_equal(
			submit_connections[0].callable.get_method(),
			&"_on_text_submitted",
			"自由入力の送信時に値を確定する",
	)
	editor.free()
	ResourceUID.remove_id(first_id)
	ResourceUID.remove_id(second_id)
