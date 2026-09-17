extends SceneTree

const ScopeIndex := preload("res://addons/katamusubi/editor/scope_index.gd")
const TscnScanner := preload("res://addons/katamusubi/editor/scanning/tscn_scanner.gd")
const ParentScopeCandidates := preload(
		"res://addons/katamusubi/editor/inspector/parent_scope_candidates.gd"
)
const ParentScopePicker := preload(
		"res://addons/katamusubi/editor/inspector/parent_scope_picker.gd"
)
const ParentScopeSelectionTestContainerScope := preload("fixtures/scopes/test_container_scope.gd")

var _runner := TestRunner.new(true)


func _init() -> void:
	_test_scanner_reads_selectable_as_parent()
	_test_scanner_defaults_missing_property_to_false()
	_test_saved_snapshot_keeps_selectability()
	_test_candidates_only_include_selectable_scopes()
	_test_current_unselectable_parent_is_preserved()

	await _runner.finish(self, "ParentScopeSelection")


## TSCNのselectable_as_parentプロパティをスコープスナップショットへ読み込めることを確認します。
func _test_scanner_reads_selectable_as_parent() -> void:
	_runner.change_test_name("scanner_reads_selectable_as_parent")
	var scene := TscnScanner.scan(
			&"res://tests/editor/parent_scope_selection/fixtures/scopes/selectable_scope.tscn"
	)
	var snapshot: ScopeSnapshot = scene.get_entry(&"selectable")
	_runner.assert_true(snapshot != null, "公開スコープを読み取る")
	_runner.assert_true(snapshot.selectable_as_parent, "公開フラグを読み取る")


## selectable_as_parentプロパティがない既存シーンを非公開スコープとして読み込むことを確認します。
func _test_scanner_defaults_missing_property_to_false() -> void:
	_runner.change_test_name("scanner_defaults_missing_property_to_false")
	var scene := TscnScanner.scan(&"res://tests/editor/parent_scope_selection/fixtures/scopes/basic_scope.tscn")
	var snapshot: ScopeSnapshot = scene.get_entry(&"basic")
	_runner.assert_true(snapshot != null, "既存シーンのスコープを読み取る")
	_runner.assert_false(
			snapshot.selectable_as_parent,
			"プロパティのない既存シーンは非公開として扱う",
	)


## 保存用スナップショットに公開フラグだけが引き継がれ、一時フィールドが除外されることを確認します。[br]
## あわせて、文字列表現に公開フラグが含まれることも確認します。
func _test_saved_snapshot_keeps_selectability() -> void:
	_runner.change_test_name("saved_snapshot_keeps_selectability")
	var scene_uid := &"uid://cydi7jyr1tte6"
	var scanned := ScopeSnapshot.new(
			scene_uid,
			&"Scope",
			&"scope",
			&"parent",
			true,
			NodePath("Scope"),
			true,
			true,
	)

	var saved := scanned.to_saved_snapshot()

	_runner.assert_true(saved.selectable_as_parent, "公開フラグを保存用複製に引き継ぐ")
	_runner.assert_equal(saved.node_path, NodePath(), "一時フィールドは保存しない")
	_runner.assert_false(saved.has_script, "Script検証結果は保存しない")
	_runner.assert_true("selectable_as_parent: true" in str(scanned), "文字列表現に公開フラグを含む")


## 親スコープ候補には、索引と編集中シーンにある公開スコープだけが含まれることを確認します。
func _test_candidates_only_include_selectable_scopes() -> void:
	_runner.change_test_name("candidates_only_include_selectable_scopes")
	var index := ScopeIndex.new()
	index.scope_snapshots = [
			_snapshot(&"indexed_public", true),
			_snapshot(&"indexed_private", false),
	]
	var provider := ParentScopeCandidates.new(index)
	var scene_root := Node.new()
	var target := _scope(&"target", false)
	var edited_public := _scope(&"edited_public", true)
	var edited_private := _scope(&"edited_private", false)
	scene_root.add_child(target)
	scene_root.add_child(edited_public)
	scene_root.add_child(edited_private)
	target.owner = scene_root
	edited_public.owner = scene_root
	edited_private.owner = scene_root

	var candidates := provider.get_candidates(target, scene_root)
	var ids: Array[StringName] = []
	for candidate in candidates:
		ids.append(candidate.scope_id)

	_runner.assert_array(ids, [&"indexed_public", &"edited_public"], "索引と編集中シーンの公開スコープだけを返す")
	_runner.assert_null(
			provider.get_candidate(&"indexed_private", target, scene_root),
			"選択可能候補の検索は非公開スコープを返さない",
	)
	_runner.assert_true(
			provider.get_existing_scope(&"indexed_private", target, scene_root) != null,
			"実在検索は非公開スコープを返す",
	)
	scene_root.free()


## 現在の親が非公開または欠落していても、そのIDと状態を選択欄に保持して表示することを確認します。
func _test_current_unselectable_parent_is_preserved() -> void:
	_runner.change_test_name("current_unselectable_parent_is_preserved")
	var picker := ParentScopePicker.new(&"child", &"private_parent")
	var option_button := picker.create([], null, true)
	var selected := option_button.selected

	_runner.assert_equal(
			option_button.get_item_metadata(selected),
			&"private_parent",
			"非公開になった現在値のIDを保持する",
	)
	_runner.assert_equal(
			option_button.get_item_text(selected),
			"Current parent (not selectable): private_parent",
			"実在する非公開の親と表示する",
	)
	_runner.assert_true(option_button.is_item_disabled(selected), "現在値は再選択できない")
	option_button.free()

	var missing_button := ParentScopePicker.new(&"child", &"missing").create([], null)
	_runner.assert_equal(
			missing_button.get_item_text(missing_button.selected),
			"Missing parent scope: missing",
			"実在しないIDは従来の欠落表示にする",
	)
	missing_button.free()


func _snapshot(scope_id: StringName, selectable: bool) -> ScopeSnapshot:
	return ScopeSnapshot.new(&"indexed_scene", scope_id, scope_id, &"", selectable)


func _scope(scope_id: StringName, selectable: bool) -> ParentScopeSelectionTestContainerScope:
	var scope := ParentScopeSelectionTestContainerScope.new()
	scope.name = scope_id
	scope.scope_id = scope_id
	scope.selectable_as_parent = selectable
	return scope
