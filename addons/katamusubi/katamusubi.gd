@tool
extends EditorPlugin

const DEFINITION_LIST := preload("res://addons/katamusubi/scope_definition_list.tres")

const SceneSnapshotAnalyzer := preload("editor/scene_snapshot_analyzer.gd")

var _container_scope_inspector_plugin: EditorInspectorPlugin

const ScopeContainerObserver := preload("editor/scope_container_observer.gd")
var _scope_container_observer: ScopeContainerObserver

const TscnScanner := preload("editor/tscn_scanner.gd")

func _build() -> bool:
	var errors: PackedStringArray = []
	# シーンUIDごとに所属スコープ定義をまとめる
	# Array は Array[ScopeDefinition]
	var definitions_by_scene: Dictionary[StringName, Array] = {}
	for definition in DEFINITION_LIST.scope_definitions:
		if not definitions_by_scene.has(definition.scene_uid):
			definitions_by_scene[definition.scene_uid] = []
		definitions_by_scene[definition.scene_uid].append(definition)

	for scene_uid in definitions_by_scene:
		var definitions: Array[ScopeDefinition] = []
		definitions.assign(definitions_by_scene[scene_uid])
		var snapshot := TscnScanner.scan(scene_uid)
		if snapshot == null:
			errors.append("シーン %s を走査できませんでした。" % scene_uid)
			continue
		var analyzer := SceneSnapshotAnalyzer.new(snapshot, definitions)
		errors.append_array(analyzer.validate())

	print("エラー %d 件：\n%s" % [errors.size(), "\n".join(errors)])
		
	if errors.size() == 0:
		return true

	return false


func _enter_tree() -> void:
	_container_scope_inspector_plugin = preload(
			"res://addons/katamusubi/editor/container_scope_inspector_plugin.gd"
	).new()
	add_inspector_plugin(_container_scope_inspector_plugin)

	_scope_container_observer = ScopeContainerObserver.new(DEFINITION_LIST)

	# 編集中のシーン切り替え時のシグナル接続
	scene_changed.connect(_scope_container_observer.on_scene_changed)

	var scene_tree := get_tree()
	
	# node追加時のシグナルを接続
	get_tree().node_added.connect(
			_scope_container_observer.on_node_added,
			CONNECT_DEFERRED,
	)

	#シーン保存時のシグナルを接続
	scene_saved.connect(_scope_container_observer.on_scene_saved)

	# ここまで今後追加で開くシーンへの接続の設定はしたけど
	# 現在開いているシーンにはシグナルが来ないので手動で呼び出し
	var current_root_node := EditorInterface.get_edited_scene_root()
	if is_instance_valid(current_root_node):
		_scope_container_observer.on_scene_changed(current_root_node)


func _exit_tree() -> void:
	if _container_scope_inspector_plugin != null:
		remove_inspector_plugin(_container_scope_inspector_plugin)
		_container_scope_inspector_plugin = null
	
	
	if _scope_container_observer != null:
		# 編集中のシーン切り替え時
		if scene_changed.is_connected(_scope_container_observer.on_scene_changed):
			scene_changed.disconnect(_scope_container_observer.on_scene_changed)
			
		# node追加時のシグナルを切断
		if get_tree().node_added.is_connected(_scope_container_observer.on_node_added):
			get_tree().node_added.disconnect(_scope_container_observer.on_node_added)
		
		#シーン保存時のシグナルを接続
		if scene_saved.is_connected(_scope_container_observer.on_scene_saved):
			scene_saved.disconnect(_scope_container_observer.on_scene_saved)
		
		_scope_container_observer = null
