extends SceneTree

const TestScope := preload("res://tests/child_container.gd")
const ROOT_SCOPE_ID := &"LqaexzOm"
const CHILD_SCOPE_ID := &"YCDZ7JOA"
const DELAYED_SCOPE_ID := &"delayed_child"
const UNKNOWN_SCOPE_ID := &"unknown_scope"

var _failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_root_scope_without_parent()
	_test_child_scope_with_valid_parent()
	await _test_child_scope_before_parent_is_added()
	_test_scope_without_definition()
	quit(_failures)


func _test_root_scope_without_parent() -> void:
	var scope := _create_scope(ROOT_SCOPE_ID)
	root.add_child(scope)

	_check(scope.state == ContainerScope.State.INITIALIZED, "ルートスコープが初期化される")
	_check(scope._container != null, "ルートコンテナが生成される")
	_check(scope._container._parent == null, "ルートコンテナは親を持たない")
	scope.free()


func _test_child_scope_with_valid_parent() -> void:
	var parent_scope := _create_scope(ROOT_SCOPE_ID)
	var child_scope := _create_scope(CHILD_SCOPE_ID)
	root.add_child(parent_scope)
	root.add_child(child_scope)

	_check(parent_scope.state == ContainerScope.State.INITIALIZED, "親スコープが先に初期化される")
	_check(child_scope.state == ContainerScope.State.INITIALIZED, "子スコープが初期化される")
	_check(child_scope._container._parent == parent_scope._container, "子コンテナが親コンテナを参照する")
	child_scope.free()
	parent_scope.free()


func _test_child_scope_before_parent_is_added() -> void:
	var definition := ScopeDefinition.create_new_definition(
		"", &"DelayedChild", DELAYED_SCOPE_ID, ROOT_SCOPE_ID
	)
	ContainerScope.DEFINITION_LIST.add_scope_definition(definition)

	var child_scope := _create_scope(DELAYED_SCOPE_ID)
	root.add_child(child_scope)
	_check(
		child_scope.state == ContainerScope.State.NOT_INITIALIZED,
		"親ノードが未追加なら子スコープは初期化を待機する"
	)

	var parent_scope := _create_scope(ROOT_SCOPE_ID)
	root.add_child(parent_scope)
	await process_frame
	await process_frame
	_check(child_scope.state == ContainerScope.State.INITIALIZED, "親ノードの追加後に初期化を再試行する")
	_check(child_scope._container._parent == parent_scope._container, "再試行後に親コンテナを参照する")

	child_scope.free()
	parent_scope.free()
	ContainerScope.DEFINITION_LIST.remove_scope_definition(DELAYED_SCOPE_ID)


func _test_scope_without_definition() -> void:
	var scope := _create_scope(UNKNOWN_SCOPE_ID)
	root.add_child(scope)

	_check(scope.state == ContainerScope.State.NOT_INITIALIZED, "定義がないスコープは初期化されない")
	_check(scope._container == null, "定義がないスコープのコンテナは生成されない")
	scope.free()


func _create_scope(id: StringName) -> ContainerScope:
	var scope := TestScope.new() as ContainerScope
	scope.scope_id = id
	return scope


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return

	_failures += 1
	push_error("FAIL: " + message)
