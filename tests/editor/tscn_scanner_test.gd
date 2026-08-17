extends SceneTree

const FIXTURE := &"res://tests/editor/fixtures/scanner_cases.tscn"

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
	var errors := TscnScanner.scan(FIXTURE, [
		_definition(FIXTURE, &"first"),
		_definition(FIXTURE, &"second"),
	])
	_expect(errors.is_empty(), "単一シーン内の複数スコープを検出できる")


func _test_multiple_scenes() -> void:
	var root_scene := &"res://tests/test_root.tscn"
	var child_scene := &"res://tests/test_child.tscn"
	var root_errors := TscnScanner.scan(root_scene, [_definition(root_scene, &"Ghlg8Ye0")])
	var child_errors := TscnScanner.scan(child_scene, [_definition(child_scene, &"YCDZ7JOA")])
	_expect(root_errors.is_empty() and child_errors.is_empty(), "複数シーンを個別に検査できる")


func _test_duplicate_id() -> void:
	var errors := TscnScanner.scan(FIXTURE, [_definition(FIXTURE, &"duplicate")])
	_expect(_contains(errors, "複数ノード"), "重複したスコープIDを報告する")


func _test_missing_id() -> void:
	var errors := TscnScanner.scan(FIXTURE, [_definition(FIXTURE, &"missing")])
	_expect(_contains(errors, "見つかりませんでした"), "存在しないスコープIDを報告する")


func _test_invalid_inheritance() -> void:
	var errors := TscnScanner.scan(FIXTURE, [_definition(FIXTURE, &"invalid")])
	_expect(_contains(errors, "継承していません"), "ContainerScopeの継承違反を報告する")


func _definition(scene_uid: StringName, scope_id: StringName) -> ScopeDefinition:
	return ScopeDefinition.create_new_definition(scene_uid, NodePath(), &"", scope_id, &"")


func _contains(errors: PackedStringArray, text: String) -> bool:
	for error in errors:
		if error.contains(text):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
