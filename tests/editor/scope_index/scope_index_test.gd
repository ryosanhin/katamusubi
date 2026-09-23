extends SceneTree

const ScopeIndex := preload("res://addons/katamusubi/editor/scope_index.gd")
const ScopeIndexStorage := preload("res://addons/katamusubi/editor/scope_index_storage.gd")
const TEST_DIRECTORY := "user://katamusubi_scope_index_test"
const TEST_PATH := TEST_DIRECTORY + "/scope_index.tres"
var _runner := TestRunner.new(true)


func _init() -> void:
	_test_scene_replacement()
	_test_zero_candidates()
	_test_storage_path()
	_test_missing_index_requires_rebuild_without_saving()
	_test_scanned_empty_index_and_loading()
	_test_regeneration_after_deletion()
	_test_reconstruction_after_corruption()
	_remove_test_directory()
	await _runner.finish(self, "ScopeIndex")


## 指定シーンのスナップショットだけを置換し、他シーンと同名IDの候補を保持することを確認します。
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


## 空のスナップショット一覧によって、指定シーンの候補をすべて削除できることを確認します。
func _test_zero_candidates() -> void:
	_runner.change_test_name("successful empty replacement")
	var index := ScopeIndex.new()
	index.scope_snapshots = [_candidate(&"a", &"old")]
	var empty: Array[ScopeSnapshot] = []
	_runner.assert_true(index.replace_scene_snapshots(&"a", empty), "候補ゼロを成功として扱う")
	_runner.assert_equal(index.scope_snapshots.size(), 0, "候補ゼロで対象シーンを空にする")


## 配布アドオンの外側に索引が保存されることを確認します。
func _test_storage_path() -> void:
	_runner.change_test_name("storage path")
	_runner.assert_true(
		ScopeIndexStorage.PATH.begins_with("res://.godot/"),
		"保存先を.godot配下にする",
	)
	_runner.assert_false(
		ScopeIndexStorage.PATH.begins_with("res://addons/"),
		"配布アドオン配下を可変データの保存先にしない",
	)


## 索引がない場合は未走査の空ファイルを作らず、起動のたびに再構築を要求することを確認します。
func _test_missing_index_requires_rebuild_without_saving() -> void:
	_runner.change_test_name("missing index requires rebuild without saving")
	_remove_test_directory()
	var storage := ScopeIndexStorage.new(TEST_PATH)
	_runner.assert_true(storage.needs_rebuild, "索引がない場合は全件再構築を要求する")
	_runner.assert_false(FileAccess.file_exists(TEST_PATH), "未走査の空索引を生成しない")

	var restarted_storage := ScopeIndexStorage.new(TEST_PATH)
	_runner.assert_true(restarted_storage.needs_rebuild, "再起動後も全件再構築を要求する")
	_runner.assert_false(FileAccess.file_exists(TEST_PATH), "再起動時にも未走査の空索引を生成しない")


## 全シーンの走査結果が空でも保存し、次回は有効な走査済み索引として読み込むことを確認します。
func _test_scanned_empty_index_and_loading() -> void:
	_runner.change_test_name("scanned empty index and loading")
	_remove_test_directory()
	var storage := ScopeIndexStorage.new(TEST_PATH)
	_runner.assert_equal(storage.get_index().scope_snapshots.size(), 0, "全シーン走査の結果を空にできる")
	_runner.assert_equal(storage.save(), OK, "走査済みの空索引を保存できる")
	_runner.assert_true(FileAccess.file_exists(TEST_PATH), "走査済みの空索引ファイルを生成する")

	var loaded_storage := ScopeIndexStorage.new(TEST_PATH)
	_runner.assert_false(loaded_storage.needs_rebuild, "走査済みの空索引は再構築を要求しない")
	_runner.assert_equal(loaded_storage.get_index().scope_snapshots.size(), 0, "走査済みの空索引を読み込む")


## 保存済み索引の削除を検知して、保存せずにメモリ上の索引を空にすることを確認します。
func _test_regeneration_after_deletion() -> void:
	_runner.change_test_name("regeneration after deletion")
	_remove_test_directory()
	var storage := ScopeIndexStorage.new(TEST_PATH)
	var index := storage.get_index()
	index.scope_snapshots = [_candidate(&"a", &"stale")]
	_runner.assert_equal(storage.save(), OK, "削除前の索引を保存できる")
	storage.needs_rebuild = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	_runner.assert_true(storage.ensure_available(), "削除された索引の再構築を要求する")
	_runner.assert_false(FileAccess.file_exists(TEST_PATH), "再走査前には削除された索引を再生成しない")
	_runner.assert_equal(index.scope_snapshots.size(), 0, "削除後は既存の索引を空にする")
	_runner.assert_same(storage.get_index(), index, "Inspectorが保持する索引の参照を維持する")


## 読み込めない索引を検知して、エディタ用の空の索引へ戻すことを確認します。
func _test_reconstruction_after_corruption() -> void:
	_runner.change_test_name("reconstruction after corruption")
	_remove_test_directory()
	var storage := ScopeIndexStorage.new(TEST_PATH)
	var index := storage.get_index()
	index.scope_snapshots = [_candidate(&"a", &"stale")]
	_runner.assert_equal(storage.save(), OK, "破損前の索引を保存できる")
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("This is not a Godot resource.")
	file.close()
	_runner.assert_true(storage.ensure_available(), "破損した索引の再構築を要求する")
	_runner.assert_true(FileAccess.file_exists(TEST_PATH), "破損ファイルは再走査前に上書きしない")
	_runner.assert_equal(storage.get_index().scope_snapshots.size(), 0, "再走査まで空の候補を利用できる")
	_runner.assert_same(storage.get_index(), index, "Inspectorが保持する索引の参照を維持する")


func _remove_test_directory() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(TEST_DIRECTORY)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIRECTORY))


## テスト用のスコープスナップショットを生成します。
func _candidate(scene: StringName, id: StringName) -> ScopeSnapshot:
	return ScopeSnapshot.new(scene, id)
