@tool
extends RefCounted

const RandomID := preload("random_id.gd")

## スコープ用グループ名
const CONTAINER_GROUP := &"test_group"


## 新規スコープIDを取得。[br]
## 100回生成して新規IDが生成できなかった場合は[code]&""[/code]を返す。[br]
## [param existed_ids]: 既存スコープID
static func get_unique_id(existed_ids: Array[StringName]) -> StringName:
	var tmp_ids: Array[StringName] = []
	# エディタで開いているシーンを全取得
	var opened_roots := EditorInterface.get_open_scene_roots()
	for root in opened_roots:
		if root == null:
			continue
		tmp_ids.append_array(_get_scope_ids_in_subtree(root))
	existed_ids.append_array(tmp_ids)

	var id := RandomID.get_random_id()
	var loop_count := 1
	const MAX_LOOP_COUNT := 100

	while id in existed_ids:
		if loop_count >= MAX_LOOP_COUNT:
			push_error("uid生成ループ回数が上限に達しました。")
			return &""
		id = RandomID.get_random_id()
		loop_count += 1

	return id


## 子ノード内に存在するスコープを検索し存在したスコープIDを返す。[br]
## [param root]: 検索する始点のノード
static func _get_scope_ids_in_subtree(root: Node) -> Array[StringName]:
	var scope_ids: Array[StringName] = []
	var nodes: Array[Node] = [root]

	for node in nodes:
		var scope := node as ContainerScope
		if scope != null:
			scope_ids.append(scope.scope_id)
		nodes.append_array(node.get_children())
	
	return scope_ids
