extends SceneTree

const ScopeIndex := preload("res://addons/katamusubi/editor/scope_index.gd")
const ScopeIndexStorage := preload("res://addons/katamusubi/editor/scope_index_storage.gd")
const TEST_DIRECTORY := "user://katamusubi_scope_index_test"
const TEST_PATH := TEST_DIRECTORY + "/scope_index.tres"
var _runner := TestRunner.new(true)


func _init() -> void:
	_test_scene_replacement()
	_test_zero_candidates()
	_test_default_storage_path()
	_test_first_generation_and_loading()
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


## 配布アドオンの外側に既定の索引が保存されることを確認します。
func _test_default_storage_path() -> void:
	_runner.change_test_name("default storage path")
	_runner.assert_true(
		ScopeIndexStorage.DEFAULT_PATH.begins_with("res://.godot/"),
		"既定の保存先を.godot配下にする",
	)
	_runner.assert_false(
		ScopeIndexStorage.DEFAULT_PATH.begins_with("res://addons/"),
		"配布アドオン配下を可変データの保存先にしない",
	)


## 初回に索引を作成し、次回の読み込みでは保存内容を復元することを確認します。
func _test_first_generation_and_loading() -> void:
	_runner.change_test_name("first generation and loading")
	_remove_test_directory()
	var storage := ScopeIndexStorage.new(TEST_PATH)
	_runner.assert_true(storage.needs_rebuild, "初回生成後に全件再構築を要求する")
	_runner.assert_true(FileAccess.file_exists(TEST_PATH), "指定した保存先に索引を生成する")
	storage.index.scope_snapshots = [_candidate(&"a", &"saved")]
	_runner.assert_equal(storage.save(), OK, "生成した索引を保存できる")

	var loaded_storage := ScopeIndexStorage.new(TEST_PATH)
	_runner.assert_false(loaded_storage.needs_rebuild, "正常な索引の読み込みでは再構築しない")
	_runner.assert_equal(loaded_storage.index.scope_snapshots.size(), 1, "保存した候補を読み込む")


## 保存済み索引の削除を検知して、空の索引を再生成することを確認します。
func _test_regeneration_after_deletion() -> void:
	_runner.change_test_name("regeneration after deletion")
	_remove_test_directory()
	var storage := ScopeIndexStorage.new(TEST_PATH)
	storage.needs_rebuild = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	_runner.assert_true(storage.ensure_available(), "削除された索引の再構築を要求する")
	_runner.assert_true(FileAccess.file_exists(TEST_PATH), "削除された索引を再生成する")


## 読み込めない索引を検知して、エディタ用の空の索引へ戻すことを確認します。
func _test_reconstruction_after_corruption() -> void:
	_runner.change_test_name("reconstruction after corruption")
	_remove_test_directory()
	var storage := ScopeIndexStorage.new(TEST_PATH)
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("This is not a Godot resource.")
	file.close()
	_runner.assert_true(storage.ensure_available(), "破損した索引の再構築を要求する")
	_runner.assert_true(FileAccess.file_exists(TEST_PATH), "破損した索引を置き換える")
	_runner.assert_equal(storage.index.scope_snapshots.size(), 0, "再走査まで空の候補を利用できる")


func _remove_test_directory() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(TEST_DIRECTORY)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIRECTORY))


## テスト用のスコープスナップショットを生成します。
func _candidate(scene: StringName, id: StringName) -> ScopeSnapshot:
	return ScopeSnapshot.new(scene, id)
