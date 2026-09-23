extends SceneTree

const ScopeIndexStorage := preload("res://addons/katamusubi/editor/scope_index_storage.gd")


func _init() -> void:
	# 本番キャッシュと分離し、実行ごとにもファイル名を分ける。
	var path := "user://katamusubi_tests/scope_index_%s_%s.tres" % [
		OS.get_process_id(),
		Time.get_ticks_usec(),
	]

	var store := ScopeIndexStorage.new(path)
	assert(store.is_dirty())

	# 新規・空のインデックスも保存できる。
	var error := store.save()
	assert(error == OK)
	assert(not store.is_dirty())
	assert(FileAccess.file_exists(path))

	var scene_uid := StringName(ResourceUID.id_to_text(12345))
	var snapshots: Array[ScopeSnapshot] = [
		ScopeSnapshot.new(scene_uid, &"TestScope"),
	]

	var succeeded := store.get_index().replace_scene_snapshots(
		scene_uid,
		snapshots
	)
	assert(succeeded)
	assert(store.is_dirty())

	error = store.save()
	assert(error == OK)
	assert(not store.is_dirty())

	# 別インスタンスでディスクから読み直す。
	var reopened := ScopeIndexStorage.new(path)
	assert(not reopened.is_dirty())
	assert(reopened.get_index().scope_snapshots.size() == 1)
	assert(
		reopened.get_index().scope_snapshots[0].scope_id
		== &"TestScope"
	)

	# 別のSnapshotインスタンスでも、値が同じなら変更扱いにしない。
	var same_snapshots: Array[ScopeSnapshot] = [
		ScopeSnapshot.new(scene_uid, &"TestScope"),
	]
	succeeded = reopened.get_index().replace_scene_snapshots(
		scene_uid,
		same_snapshots
	)
	assert(succeeded)
	assert(not reopened.is_dirty())

	error = DirAccess.remove_absolute(path)
	assert(error == OK)

	print("ScopeIndexStorage test passed.")
	quit()
