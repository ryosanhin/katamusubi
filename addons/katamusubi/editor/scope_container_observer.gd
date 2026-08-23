@tool
extends RefCounted

const RandomId := preload("random_id.gd")
const ScopeDefinitionList := preload("../runtime/scope_definition_list.gd")
const TscnScanner := preload("tscn_scanner.gd")
const SceneSnapshotAnalyzer := preload("scene_snapshot_analyzer.gd")

var _definition_list: ScopeDefinitionList

## スクリプトの差し替え監視中のノード群
var _observed_nodes: Array[Node]

func _init(
	init_definition_list: ScopeDefinitionList
) -> void:
	_definition_list = init_definition_list


## 編集中のシーンが変更になったときの処理
func on_scene_changed(node: Node) -> void:
	if node == null:
		return
	# シーン内の編集対象ノードのスクリプト差し替え状況を監視
	connect_children_signal(node)


## シーンにノードが追加されたときの処理
func on_node_added(node: Node) -> void:
	if EditorInterface.is_playing_scene():
		return
	
	if not is_instance_valid(node):
		return

	if not _is_editable(node):
		return

	# スクリプトの差し替えを監視する
	_connect_on_script_changed(node)

	var scope := node as ContainerScope
	if scope == null:
		return
	_assign_scope_id(scope)


## 対象のノードが編集可能か、編集して意味があるか確認[br]
## PackedScene のインスタンスはインスタンス前に編集しておけ
func _is_editable(node: Node) -> bool:
	var root := EditorInterface.get_edited_scene_root()
	
	if root == null:
		return false
	
	# 自分がシーンの root なら編集可能なシーン
	if node == root:
		return true
	
	# PackedScene の root より下位のノードの owner は PackedScene の root になる
	if node.owner != root:
		return false

	# PackedScene のインスタンスの root はファイルパスを持つ
	if not node.scene_file_path.is_empty():
		return false
	
	return true


## スクリプト差し替え時シグナル接続対象を総チェック
func connect_children_signal(root: Node) -> void:
	if root == null:
		return
	
	var stack: Array[Node] = [root]

	while not stack.is_empty():
		var node := stack.pop_back()
		if _is_editable(node):
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
		node.script_changed.connect(
				_on_script_changed.bind(node),
				CONNECT_DEFERRED
		)
		_observed_nodes.append(node)


## スクリプトが差し替えられたときの実際に行われる処理
func _on_script_changed(node: Node) -> void:
	if not _is_editable(node):
		return
	var scope := node as ContainerScope
	if scope == null:
		return
	_assign_scope_id(scope)


## スコープIDを適用する
func _assign_scope_id(scope: ContainerScope) -> void:
	var is_modified := false

	var is_in_group := scope.is_in_group(scope.CONTAINER_GROUP)

	if not is_in_group:
		scope.add_to_group(scope.CONTAINER_GROUP, true)
		is_modified = true
	
	if scope.scope_id.is_empty():
		var new_id := _get_new_id()
		if new_id.is_empty():
			push_error("新規IDが取得できませんでした。")
		else:
			scope.scope_id = new_id
			is_modified = true
	
	if is_modified:
		EditorInterface.mark_scene_as_unsaved()


func on_filesystem_changed() -> void:
	for definition in _definition_list.scope_definitions:
		var path := ResourceUID.uid_to_path(definition.scene_uid)

		# 削除されていた場合
		if not FileAccess.file_exists(path):
			_definition_list.remove_scope_definition(definition.scope_id)


func on_scene_saved(path: String) -> void:
	var scene_uid := ResourceUID.path_to_uid(path)
	if scene_uid == path:
		push_error("保存先のシーンのUIDが取得できませんでした。")
		return
	
	var snapshot := TscnScanner.scan(scene_uid)
	var analyzer := SceneSnapshotAnalyzer.new(snapshot, _definition_list.scope_definitions)
	var diff := analyzer.get_diff()
	var rollback_actions: Array[RollbackAction] = []
	
	for removed_id in diff.removed:
		rollback_actions.append(_definition_list.remove_scope_definition(removed_id))
	
	for added_id in diff.added:
		var scanned_entry := snapshot.get_entry(added_id)
		var definition := ScopeDefinition.new(
				scanned_entry.scene_uid,
				scanned_entry.scope_name,
				scanned_entry.scope_id,
				scanned_entry.parent_scope_id,
		)
		rollback_actions.append(_definition_list.add_scope_definition(definition))

	if rollback_actions.size() == 0:
		return
	
	if not _try_save_definition_list():
		for rollback_action in rollback_actions:
			if not rollback_action.operation_succeeded:
				continue
			rollback_action.rollback()


## 新規スコープIDを取得[br]
## 100回生成して新規IDが生成できなかった場合は[code]&""[/code]を返す
func _get_new_id() -> StringName:
	var current_id_list := _definition_list.get_current_id_list()

	var id := RandomID.get_random_id()
	var loop_count := 1
	const MAX_LOOP_COUNT := 100

	while current_id_list.has(id):
		if loop_count >= MAX_LOOP_COUNT:
			push_error("uid生成ループ回数が上限に達しました。")
			return &""
		id = RandomID.get_random_id()
		loop_count += 1

	return id


func _try_save_definition_list() -> bool:
	var error := _save_definition_list()
	if error != OK:
		push_error("failed save list: %s" % error_string(error))
		return false
	print("successfully saved list")
	return true


func _save_definition_list() -> Error:
	return _definition_list.save()
