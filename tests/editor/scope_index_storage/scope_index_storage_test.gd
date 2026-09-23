extends SceneTree

const ScopeIndexStorage := preload("res://addons/katamusubi/editor/scope_index_storage.gd")
var _runner := TestRunner.new(true)


func _init() -> void:
	_test_save_and_reload()
	await _runner.finish(self, "ScopeIndexStorage")


## インデックスの保存と再読み込みを行い、変更状態が内容に応じて更新されることを確認します。
func _test_save_and_reload() -> void:
	_runner.change_test_name("save_and_reload")
	# 本番キャッシュと分離し、実行ごとにもファイル名を分ける。
	var path := "user://katamusubi_tests/scope_index_%s_%s.tres" % [
		OS.get_process_id(),
		Time.get_ticks_usec(),
	]

	var store := ScopeIndexStorage.new(path)
	_runner.assert_true(store.is_dirty(), "新規インデックスを変更済みとして扱う")

	# 新規・空のインデックスも保存できる。
	var error := store.save()
	_runner.assert_equal(error, OK, "空のインデックスを保存できる")
	_runner.assert_false(store.is_dirty(), "保存後に変更済み状態を解除する")
	_runner.assert_true(FileAccess.file_exists(path), "インデックスファイルを作成する")

	var scene_uid := StringName(ResourceUID.id_to_text(12345))
	var snapshots: Array[ScopeSnapshot] = [
		ScopeSnapshot.new(scene_uid, &"TestScope"),
	]

	var succeeded := store.get_index().replace_scene_snapshots(
		scene_uid,
		snapshots
	)
	_runner.assert_true(succeeded, "シーンのスナップショットを置換できる")
	_runner.assert_true(store.is_dirty(), "スナップショットの置換を変更として扱う")

	error = store.save()
	_runner.assert_equal(error, OK, "変更したインデックスを保存できる")
	_runner.assert_false(store.is_dirty(), "変更の保存後に変更済み状態を解除する")

	# 別インスタンスでディスクから読み直す。
	var reopened := ScopeIndexStorage.new(path)
	_runner.assert_false(reopened.is_dirty(), "保存済みインデックスを未変更として読み込む")
	_runner.assert_equal(reopened.get_index().scope_snapshots.size(), 1, "保存した候補数を復元する")
	_runner.assert_equal(
		reopened.get_index().scope_snapshots[0].scope_id,
		&"TestScope",
		"保存したスコープIDを復元する",
	)

	# 別のSnapshotインスタンスでも、値が同じなら変更扱いにしない。
	var same_snapshots: Array[ScopeSnapshot] = [
		ScopeSnapshot.new(scene_uid, &"TestScope"),
	]
	succeeded = reopened.get_index().replace_scene_snapshots(
		scene_uid,
		same_snapshots
	)
	_runner.assert_true(succeeded, "同じ値のスナップショットで置換できる")
	_runner.assert_false(reopened.is_dirty(), "同じ値での置換を変更として扱わない")

	error = DirAccess.remove_absolute(path)
	_runner.assert_equal(error, OK, "テスト用インデックスファイルを削除できる")
