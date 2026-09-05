@tool
extends RefCounted

const Const := preload("res://addons/katamusubi/katamusubi_global.gd")
const ScopeIndex := preload("scope_index.gd")
const TscnScanner := preload("scanning/tscn_scanner.gd")
const IdGenerator := preload("utility/scope_id_generator.gd")

var _scope_index: ScopeIndex

## スクリプトの差し替え監視中のノード群
var _observed_nodes: Array[Node]

func _init(
	init_scope_index: ScopeIndex
) -> void:
	_scope_index = init_scope_index


## 編集中のシーンが変更になったときの処理
func on_scene_changed(node: Node) -> void:
	# null のときはシーンを閉じて編集中シーンが無くなったとき
	if node == null:
		_clear_observed_nodes()
		return
	
	# シーン内の編集対象ノードのスクリプト差し替え状況を監視
	_on_scene_changed(node)


## シーンにノードが追加されたときの処理
func on_node_added(node: Node) -> void:
	if EditorInterface.is_playing_scene():
		return
	
	if not is_instance_valid(node):
		return

	if not _is_owned_by_edited_scene(node):
		return

	# スクリプトの差し替えを監視する
	_connect_on_script_changed(node)

	var scope := node as ContainerScope
	if scope == null:
		return
	_assign_scope_id(scope)


## スクリプト差し替え時シグナル接続対象を総チェック
func _on_scene_changed(root: Node) -> void:
	_clear_observed_nodes()

	var stack: Array[Node] = [root]

	while not stack.is_empty():
		var node := stack.pop_back()
		if _is_owned_by_edited_scene(node):
			_connect_on_script_changed(node)
			# そもそもシグナル接続時に既にスコープのスクリプトをアタッチされていたら
			# 監視し損ねるのでここのタイミングで手動で確認
			var scope := node as ContainerScope
			if scope != null:
				_assign_scope_id(scope)
		for i in range(node.get_child_count() - 1, -1, -1):
			stack.append(node.get_child(i))


## スクリプト差し替え時のシグナルへの接続
func _connect_on_script_changed(node: Node) -> void:
	if not node.script_changed.is_connected(_on_script_changed.bind(node)):
		node.script_changed.connect(_on_script_changed.bind(node))
		_observed_nodes.append(node)


## スクリプトが差し替えられたときの実際に行われる処理
func _on_script_changed(node: Node) -> void:
	if not is_instance_valid(node):
		return

	if not _is_owned_by_edited_scene(node):
		return
	var scope := node as ContainerScope
	if scope == null:
		return
	_assign_scope_id(scope)


## スコープIDを適用する
func _assign_scope_id(scope: ContainerScope) -> void:
	var is_modified := false

	var is_in_group := scope.is_in_group(Const.GROUP_NAME)

	if not is_in_group:
		scope.add_to_group(Const.GROUP_NAME, true)
		is_modified = true
	
	if scope.scope_id.is_empty():
		var new_id := IdGenerator.get_unique_id(_scope_index.get_current_id_list())
		if new_id.is_empty():
			push_error("新規IDが取得できませんでした。")
		else:
			scope.scope_id = new_id
			is_modified = true
	
	if is_modified:
		EditorInterface.mark_scene_as_unsaved()


## 監視中のノードの監視を全て削除する
func _clear_observed_nodes() -> void:
	while not _observed_nodes.is_empty():
		var node := _observed_nodes.pop_back()
		if not is_instance_valid(node):
			continue
		if node.script_changed.is_connected(_on_script_changed.bind(node)):
			node.script_changed.disconnect(_on_script_changed.bind(node))
	_observed_nodes.clear()


func on_filesystem_changed() -> void:
	var removed_scene_uids: Dictionary[StringName, bool] = {}
	for snapshot in _scope_index.scope_snapshots:
		var path := ResourceUID.ensure_path(snapshot.scene_uid)

		# 削除されていた場合
		if path.is_empty() or not FileAccess.file_exists(path):
			removed_scene_uids[snapshot.scene_uid] = true

	for scene_uid in removed_scene_uids:
		var empty_snapshots: Array[ScopeSnapshot] = []
		var rollback_action := _scope_index.replace_scene_snapshots(
				scene_uid,
				empty_snapshots,
		)
		if rollback_action.operation_succeeded and not _try_save_scope_index():
			rollback_action.rollback()


func on_scene_saved(path: String) -> void:
	var scene_uid := ResourceUID.path_to_uid(path)
	if scene_uid == path:
		push_error("保存先のシーンのUIDが取得できませんでした。")
		return
	
	var snapshot := TscnScanner.scan(scene_uid)
	if snapshot == null:
		push_error("シーン %s が読み込めませんでした。" % path)
		return
	
	var rollback_action := _scope_index.replace_scene_snapshots(scene_uid, snapshot.entries)
	if not rollback_action.operation_succeeded:
		return

	if not _try_save_scope_index():
		rollback_action.rollback()


## 対象のノードが監視対象か確認[br]
## PackedScene のインスタンスはPackedScene 毎に編集しておけ
func _is_owned_by_edited_scene(node: Node) -> bool:
	var root := EditorInterface.get_edited_scene_root()
	# owner = 変更が保存されるtscnファイルのルートノード
	return node == root or node.owner == root


func _try_save_scope_index() -> bool:
	var error := _save_scope_index()
	if error != OK:
		push_error("failed save list: %s" % error_string(error))
		return false
	print("successfully saved list")
	# ファイルシステムで再スキャンを呼び出して、読み込ませる
	var fs := EditorInterface.get_resource_filesystem()
	fs.scan()
	return true


func _save_scope_index() -> Error:
	return _scope_index.save()
