extends SceneTree

const ScopeIndex := preload("res://addons/katamusubi/editor/scope_index.gd")
const TscnScanner := preload("res://addons/katamusubi/editor/scanning/tscn_scanner.gd")
const ParentScopeCandidates := preload("res://addons/katamusubi/editor/inspector/parent_scope_candidates.gd")
const ParentScopePicker := preload("res://addons/katamusubi/editor/inspector/parent_scope_picker.gd")
const TestScope := preload("fixtures/scopes/test_container_scope.gd")
var _runner := TestRunner.new(true)


func _init() -> void:
	_test_scanner_and_failure()
	_test_live_overlay_and_search()
	_test_free_input()
	await _runner.finish(self, "ParentScopeSelection")


func _test_scanner_and_failure() -> void:
	_runner.change_test_name("scanner")
	var result := TscnScanner.scan(&"res://tests/editor/parent_scope_selection/fixtures/scopes/basic_scope.tscn")
	_runner.assert_true(result.succeeded, "保存済みScriptの継承をインスタンス化せず判定する")
	_runner.assert_equal(result.entries.size(), 1, "非空IDだけを候補にする")
	_runner.assert_equal(result.entries[0].node_path, NodePath("."), "ルートNodePathを保存する")
	var failure := TscnScanner.scan(&"res://missing_scene.tscn")
	_runner.assert_false(failure.succeeded, "スキャン失敗を候補ゼロと区別する")


func _test_live_overlay_and_search() -> void:
	_runner.change_test_name("live overlay")
	var index := ScopeIndex.new()
	index.scope_snapshots = [ScopeSnapshot.new(&"other", "Parent", &"indexed")]
	var provider := ParentScopeCandidates.new(index)
	var root := Node.new()
	var target := TestScope.new()
	var public := TestScope.new()
	public.name = "PublicNode"
	public.scope_id = &"live-public"
	var private := TestScope.new()
	root.add_child(target)
	root.add_child(public)
	root.add_child(private)
	target.owner = root
	public.owner = root
	private.owner = root
	var found := provider.get_candidates(target, root, "pub")
	_runner.assert_equal(found.size(), 1, "編集中の非空IDを部分一致検索できる")
	_runner.assert_equal(found[0].node_path, NodePath("PublicNode"), "編集中のNodePathを合成する")
	root.free()


func _test_free_input() -> void:
	_runner.change_test_name("free input")
	var picker := ParentScopePicker.new(&"not-indexed", [], null)
	var values: Array[StringName] = []
	picker.value_committed.connect(func(value: StringName) -> void: values.append(value))
	picker.get_line_edit().text_submitted.emit("arbitrary")
	_runner.assert_equal(values[0], &"arbitrary", "候補外の名前も確定できる")
	picker.free()
