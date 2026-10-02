extends SceneTree

const ScopeIndex := preload("res://addons/katamusubi/editor/scope_index.gd")
const BASIC_SCENE := "res://tests/editor/tscn_scanner/fixtures/scopes/basic_scope.tscn"
const PAIR_SCENE := "res://tests/runtime/container_scope/fixtures/scopes/parent_child_scopes.tscn"
const EMPTY_SCENE := "res://tests/editor/container_scope_observer/fixtures/empty_scene.tscn"

class RecordingObserver extends "res://addons/katamusubi/editor/inspector/container_scope_observer.gd":
	var scanned: PackedStringArray = []
	var fail_scan := false

	func _update_index(scene_uid: StringName) -> bool:
		scanned.append(ResourceUID.ensure_path(scene_uid))
		if fail_scan:
			return false
		return super._update_index(scene_uid)

var _runner := TestRunner.new(true)


func _init() -> void:
	_test_add_remove_and_save()
	_test_empty_scene_and_failed_rebuild()
	await _runner.finish(self, "ContainerScopeObserver")


func _test_add_remove_and_save() -> void:
	_runner.change_test_name("add remove and save")
	var index := ScopeIndex.new()
	var observer := RecordingObserver.new(index)
	_runner.assert_equal(index.scope_snapshots.size(), 0, "新しいインデックスは空で開始する")
	observer._synchronize_scene_paths([BASIC_SCENE], true)
	_runner.assert_equal(index.scope_snapshots.size(), 1, "開始時に保存済みシーンから構築する")

	observer.scanned.clear()
	observer._synchronize_scene_paths([BASIC_SCENE, PAIR_SCENE])
	_runner.assert_array(observer.scanned, [PAIR_SCENE], "追加シーンだけを読み込む")
	_runner.assert_equal(index.scope_snapshots.size(), 3, "追加シーンの候補を反映する")

	observer.scanned.clear()
	observer._synchronize_scene_paths([PAIR_SCENE])
	_runner.assert_equal(observer.scanned.size(), 0, "削除確認で既存シーンを再読込しない")
	_runner.assert_equal(index.scope_snapshots.size(), 2, "一覧から消えたシーンの候補を削除する")

	# 古い候補を入れ、保存通知で最新の内容に戻ることを確認する。
	var uid := StringName(ResourceUID.path_to_uid(PAIR_SCENE))
	index.replace_scene_snapshots(uid, [ScopeSnapshot.new(uid, &"old")])
	observer.update_scene_index(PAIR_SCENE)
	_runner.assert_equal(index.scope_snapshots.size(), 2, "既存シーンも保存時に更新する")
	_runner.assert_equal(index.scope_snapshots[0].scope_id, &"child", "保存済みのIDを読み直す")


func _test_empty_scene_and_failed_rebuild() -> void:
	_runner.change_test_name("empty scene and failed rebuild")
	var index := ScopeIndex.new()
	var observer := RecordingObserver.new(index)
	observer._synchronize_scene_paths([BASIC_SCENE, EMPTY_SCENE], true)
	_runner.assert_equal(index.scope_snapshots.size(), 1, "候補がないシーンも正常に走査する")
	observer.scanned.clear()
	observer._synchronize_scene_paths([BASIC_SCENE, EMPTY_SCENE])
	_runner.assert_equal(observer.scanned.size(), 0, "候補がない既知シーンも再読込しない")

	observer.fail_scan = true
	observer._synchronize_scene_paths([BASIC_SCENE, EMPTY_SCENE], true)
	_runner.assert_equal(observer.scanned.size(), 2, "明示的な再構築では既存シーンも走査する")
	_runner.assert_equal(index.scope_snapshots.size(), 1, "走査失敗時はセッション内の前回候補を保持する")
	observer._synchronize_scene_paths([])
	_runner.assert_equal(index.scope_snapshots.size(), 0, "全シーン削除で候補を空にする")
