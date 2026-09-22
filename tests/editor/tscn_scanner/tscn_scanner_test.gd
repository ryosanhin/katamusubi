extends SceneTree

const TscnScanner := preload("res://addons/katamusubi/editor/scanning/tscn_scanner.gd")

var _runner := TestRunner.new(true)


func _init() -> void:
	_test_scanner_and_failure()
	await _runner.finish(self, "ParentScopeSelection")


## シーンの公開スコープを読み取り、スキャンの成功結果と失敗理由を取得できることを確認します。
func _test_scanner_and_failure() -> void:
	_runner.change_test_name("scanner")
	var result := TscnScanner.scan(&"res://tests/editor/tscn_scanner/fixtures/scopes/basic_scope.tscn")
	_runner.assert_true(result.succeeded, "保存済みScriptの継承をインスタンス化せず判定する")
	_runner.assert_equal(result.entries.size(), 1, "非空IDだけを候補にする")
	_runner.assert_equal(result.entries[0].scope_id, &"basic", "実行時の解決に必要なスコープIDを保持する")
	_runner.assert_equal(
			result.entries[0].scene_uid,
			&"res://tests/editor/tscn_scanner/fixtures/scopes/basic_scope.tscn",
			"候補の表示に必要なシーンUIDを保持する",
	)
	var failure := TscnScanner.scan(&"res://missing_scene.tscn")
	_runner.assert_false(failure.succeeded, "スキャン失敗を候補ゼロと区別する")
	_runner.assert_true(not failure.error_message.is_empty(), "スキャン失敗の理由を保持する")
