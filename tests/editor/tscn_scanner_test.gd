extends SceneTree

const SCANNER_CASES_FIXTURE := &"res://tests/editor/fixtures/scanner_cases.tscn"
const SCANNER_ROOT_FIXTURE := &"res://tests/editor/fixtures/scanner_root.tscn"
const SCANNER_CHILD_FIXTURE := &"res://tests/editor/fixtures/scanner_child.tscn"
const SCANNER_ROOT_SCOPE_ID := &"scanner_root_scope"
const SCANNER_CHILD_SCOPE_ID := &"scanner_child_scope"

var _failures: PackedStringArray = []


func _init() -> void:
	_test_multiple_scopes_in_one_scene()
	_test_multiple_scenes()
	_test_duplicate_id()
	_test_missing_id()
	_test_invalid_inheritance()

	if _failures.is_empty():
		print("TscnScanner tests passed")
		quit()
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_multiple_scopes_in_one_scene() -> void:
	var errors := Katamusubi.Editor.TscnScanner.scan(SCANNER_CASES_FIXTURE, [
		_definition(SCANNER_CASES_FIXTURE, &"first"),
		_definition(SCANNER_CASES_FIXTURE, &"second"),
	])
	_expect(errors.is_empty(), "単一シーン内の複数スコープを検出できる")


func _test_multiple_scenes() -> void:
	var root_errors := Katamusubi.Editor.TscnScanner.scan(SCANNER_ROOT_FIXTURE, [
		_definition(SCANNER_ROOT_FIXTURE, SCANNER_ROOT_SCOPE_ID),
	])
	var child_errors := Katamusubi.Editor.TscnScanner.scan(SCANNER_CHILD_FIXTURE, [
		_definition(SCANNER_CHILD_FIXTURE, SCANNER_CHILD_SCOPE_ID),
	])
	_expect(root_errors.is_empty() and child_errors.is_empty(), "複数シーンを個別に検査できる")


func _test_duplicate_id() -> void:
	var errors := Katamusubi.Editor.TscnScanner.scan(SCANNER_CASES_FIXTURE, [
		_definition(SCANNER_CASES_FIXTURE, &"duplicate"),
	])
	_expect(_contains(errors, "複数ノード"), "重複したスコープIDを報告する")


func _test_missing_id() -> void:
	var errors := Katamusubi.Editor.TscnScanner.scan(SCANNER_CASES_FIXTURE, [
		_definition(SCANNER_CASES_FIXTURE, &"missing"),
	])
	_expect(_contains(errors, "見つかりませんでした"), "存在しないスコープIDを報告する")


func _test_invalid_inheritance() -> void:
	var errors := Katamusubi.Editor.TscnScanner.scan(SCANNER_CASES_FIXTURE, [
		_definition(SCANNER_CASES_FIXTURE, &"invalid"),
	])
	_expect(_contains(errors, "継承していません"), "ContainerScopeの継承違反を報告する")


func _definition(scene_uid: StringName, scope_id: StringName) -> ScopeDefinition:
	return ScopeDefinition.create_new_definition(scene_uid, &"", scope_id, &"")


func _contains(errors: PackedStringArray, text: String) -> bool:
	for error in errors:
		if error.contains(text):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
