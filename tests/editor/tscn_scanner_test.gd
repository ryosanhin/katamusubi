extends SceneTree

const SCANNER_CASES_FIXTURE := &"res://tests/editor/fixtures/scanner_cases.tscn"
const SCANNER_ROOT_FIXTURE := &"res://tests/editor/fixtures/scanner_root.tscn"
const SCANNER_CHILD_FIXTURE := &"res://tests/editor/fixtures/scanner_child.tscn"
const SCANNER_ROOT_SCOPE_ID := &"scanner_root_scope"
const SCANNER_CHILD_SCOPE_ID := &"scanner_child_scope"

const TscnScanner := preload("res://addons/katamusubi/editor/tscn_scanner.gd")
const SceneSnapshot := preload("res://addons/katamusubi/editor/scene_snapshot.gd")
const SceneSnapshotAnalyzer := preload("res://addons/katamusubi/editor/scene_snapshot_analyzer.gd")
const ScannedEntry := preload("res://addons/katamusubi/editor/scanned_entry.gd")

var _failures: PackedStringArray = []

func _init() -> void:
	_test_multiple_scopes_in_one_scene()
	_test_multiple_scenes()
	_test_duplicate_id()
	_test_missing_id()
	_test_invalid_inheritance()
	_test_diff_calculation()
	_test_snapshot_rejects_entries_from_another_scene()

	if _failures.is_empty():
		print("TscnScanner tests passed")
		quit()
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_multiple_scopes_in_one_scene() -> void:
	var errors := _validate(SCANNER_CASES_FIXTURE, [
		_definition(SCANNER_CASES_FIXTURE, &"first"),
		_definition(SCANNER_CASES_FIXTURE, &"second"),
	])
	_expect(errors.is_empty(), "単一シーン内の複数スコープを検出できる")


func _test_multiple_scenes() -> void:
	var root_errors := _validate(SCANNER_ROOT_FIXTURE, [
		_definition(SCANNER_ROOT_FIXTURE, SCANNER_ROOT_SCOPE_ID),
	])
	var child_errors := _validate(SCANNER_CHILD_FIXTURE, [
		_definition(SCANNER_CHILD_FIXTURE, SCANNER_CHILD_SCOPE_ID),
	])
	_expect(root_errors.is_empty() and child_errors.is_empty(), "複数シーンを個別に検査できる")


func _test_duplicate_id() -> void:
	var errors := _validate(SCANNER_CASES_FIXTURE, [
		_definition(SCANNER_CASES_FIXTURE, &"duplicate"),
	])
	_expect(_contains(errors, "複数ノード"), "重複したスコープIDを報告する")


func _test_missing_id() -> void:
	var errors := _validate(SCANNER_CASES_FIXTURE, [
		_definition(SCANNER_CASES_FIXTURE, &"missing"),
	])
	_expect(_contains(errors, "見つかりませんでした"), "存在しないスコープIDを報告する")


func _test_invalid_inheritance() -> void:
	var errors := _validate(SCANNER_CASES_FIXTURE, [
		_definition(SCANNER_CASES_FIXTURE, &"invalid"),
	])
	_expect(_contains(errors, "継承していません"), "ContainerScopeの継承違反を報告する")


func _test_diff_calculation() -> void:
	var snapshot := TscnScanner.scan(SCANNER_CASES_FIXTURE)
	var definitions: Array[ScopeDefinition] = [
		_definition(SCANNER_CASES_FIXTURE, &"first"),
		_definition(SCANNER_CASES_FIXTURE, &"deleted"),
	]
	var diff := SceneSnapshotAnalyzer.new(snapshot, definitions).get_diff()
	_expect(&"first" in diff["continuous"], "継続しているスコープIDを差分に含める")
	_expect(&"deleted" in diff["deleted"], "削除されたスコープIDを差分に含める")
	_expect(&"second" in diff["new"], "新しいスコープIDを差分に含める")


func _test_snapshot_rejects_entries_from_another_scene() -> void:
	var matching_entry := _entry(SCANNER_ROOT_FIXTURE, &"matching")
	var foreign_entry := _entry(SCANNER_CHILD_FIXTURE, &"foreign")
	var snapshot := SceneSnapshot.new(
		SCANNER_ROOT_FIXTURE,
		[matching_entry, foreign_entry] as Array[ScannedEntry],
	)

	_expect(snapshot.entries == [matching_entry], "異なるシーンのエントリを保持しない")
	_expect(snapshot.get_entry(&"foreign") == null, "異なるシーンのエントリを取得できない")


func _entry(scene_uid: StringName, scope_id: StringName) -> ScannedEntry:
	return ScannedEntry.new(scene_uid, scope_id, scope_id, &"", NodePath(scope_id), true, true)


func _definition(scene_uid: StringName, scope_id: StringName) -> ScopeDefinition:
	return ScopeDefinition.new(scene_uid, &"", scope_id, &"")


func _validate(
	scene_uid: StringName,
	definitions: Array[ScopeDefinition],
) -> PackedStringArray:
	var snapshot := TscnScanner.scan(scene_uid)
	return SceneSnapshotAnalyzer.new(snapshot, definitions).validate()


func _contains(errors: PackedStringArray, text: String) -> bool:
	for error in errors:
		if error.contains(text):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
