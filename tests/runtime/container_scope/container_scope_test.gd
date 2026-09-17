extends SceneTree

const Const := preload("res://addons/katamusubi/katamusubi_global.gd")
const ContainerScopeScript := preload(
	"res://addons/katamusubi/runtime/scope/container_scope.gd"
)
const ContainerScopeTestContainerScope := preload("res://tests/runtime/container_scope/fixtures/scopes/test_container_scope.gd")
const BasicScopeScene := preload("res://tests/runtime/container_scope/fixtures/scopes/basic_scope.tscn")
const ParentChildScene := preload(
	"res://tests/runtime/container_scope/fixtures/scopes/parent_child_scopes.tscn"
)
const BaseService := preload("res://tests/runtime/container_scope/fixtures/services/base_service.gd")
const NoArgumentsTarget := preload(
	"res://tests/runtime/container_scope/fixtures/injection_targets/no_argument_method.gd"
)
const MissingMethodTarget := preload(
	"res://tests/runtime/container_scope/fixtures/injection_targets/no_injection_method.gd"
)
const OrderedInjectionTarget := preload(
	"res://tests/runtime/container_scope/fixtures/scopes/ordered_injection_target.gd"
)

var _runner := TestRunner.new(true)


func _init() -> void:
	await process_frame
	await _test_root_scope_initialization_async()
	await _test_registration_once_per_initialization_async()
	await _test_reinitialization_is_idempotent_async()
	await _test_parent_initializes_before_child_async()
	await _test_parent_service_resolution_async()
	await _test_child_registration_precedence_async()
	await _test_empty_parent_id_skips_lookup_async()
	await _test_missing_parent_fails_async()
	await _test_duplicate_parent_fails_async()
	await _test_circular_parent_relationship_async()
	await _test_parent_failure_propagates_to_child_async()
	await _test_injection_failure_clears_container_async()
	await _test_exit_tree_resets_scope_async()
	await _test_targets_are_injected_in_array_order_async()
	await _test_injection_stops_at_first_failure_async()

	await _runner.finish(self, "ContainerScope")


func _test_root_scope_initialization_async() -> void:
	_runner.change_test_name("root_scope_initialization")
	var manual: ContainerScopeTestContainerScope = ContainerScopeTestContainerScope.new()
	_runner.assert_true(manual.initialize_for_test(), "親なしスコープを明示的に初期化できる")
	_runner.assert_equal(manual.state, ContainerScopeScript.State.INITIALIZED, "明示初期化でINITIALIZEDになる")
	manual.free()

	var scene_scope: ContainerScopeTestContainerScope = BasicScopeScene.instantiate()
	root.add_child(scene_scope)
	_runner.assert_equal(scene_scope.state, ContainerScopeScript.State.INITIALIZED, "_readyでINITIALIZEDになる")
	await _free_node(scene_scope)


func _test_registration_once_per_initialization_async() -> void:
	_runner.change_test_name("registration_once_per_initialization")
	var scope: ContainerScopeTestContainerScope = BasicScopeScene.instantiate()
	root.add_child(scope)
	_runner.assert_equal(scope.registration_count, 1, "1回の初期化につき登録を一度だけ行う")
	await _free_node(scope)


func _test_reinitialization_is_idempotent_async() -> void:
	_runner.change_test_name("reinitialization_is_idempotent")
	var target = NoArgumentsTarget.new()
	var scope := _get_new_container_scope(&"scope")
	var holder := _holder_with([target, scope])
	scope._inject_target.assign([target])
	root.add_child(holder)
	_runner.assert_true(scope.initialize_for_test(), "初期化済みスコープの再初期化は成功扱いになる")
	_runner.assert_equal(scope.registration_count, 1, "再初期化で登録を繰り返さない")
	_runner.assert_equal(target.injection_count, 1, "再初期化で注入を繰り返さない")
	await _free_node(holder)


func _test_parent_initializes_before_child_async() -> void:
	_runner.change_test_name("parent_initializes_before_child")
	var pair = ParentChildScene.instantiate()
	var child: ContainerScopeTestContainerScope = pair.get_node("Child")
	var parent: ContainerScopeTestContainerScope = pair.get_node("Parent")
	root.add_child(pair)
	_runner.assert_equal(parent.state, ContainerScopeScript.State.INITIALIZED, "子を先にreadyしても親を初期化する")
	_runner.assert_equal(child.state, ContainerScopeScript.State.INITIALIZED, "親の後に子を初期化する")
	_runner.assert_true(child.parent_container_for_test() != null, "子コンテナが初期化済み親コンテナを保持する")
	await _free_node(pair)


func _test_parent_service_resolution_async() -> void:
	_runner.change_test_name("parent_service_resolution")
	var parent := _get_new_container_scope(&"parent", &"", &"parent_only")
	var child := _get_new_container_scope(&"child", &"parent", &"child_only")
	var holder := _holder_with([child, parent])
	root.add_child(holder)
	_runner.assert_same(child.resolve_for_test(BaseService, &"parent_only"), parent.registered_service, "子から親だけの登録を解決する")
	await _free_node(holder)


func _test_child_registration_precedence_async() -> void:
	_runner.change_test_name("child_registration_precedence")
	var parent := _get_new_container_scope(&"parent", &"", &"shared")
	var child := _get_new_container_scope(&"child", &"parent", &"shared")
	var holder := _holder_with([child, parent])
	root.add_child(holder)
	_runner.assert_same(child.resolve_for_test(BaseService, &"shared"), child.registered_service, "同じ型とキーでは子の登録を優先する")
	await _free_node(holder)


func _test_empty_parent_id_skips_lookup_async() -> void:
	_runner.change_test_name("empty_parent_id_skips_lookup")
	var unrelated_a := _get_new_container_scope(&"candidate")
	var unrelated_b := _get_new_container_scope(&"candidate")
	var scope := _get_new_container_scope(&"independent")
	var holder := _holder_with([scope, unrelated_a, unrelated_b])
	root.add_child(holder)
	_runner.assert_equal(scope.state, ContainerScopeScript.State.INITIALIZED, "親IDが空なら候補数にかかわらず初期化する")
	_runner.assert_null(scope.parent_container_for_test(), "親探索を行わず親コンテナを設定しない")
	await _free_node(holder)


func _test_missing_parent_fails_async() -> void:
	_runner.change_test_name("missing_parent_fails")
	var scope := _get_new_container_scope(&"child", &"missing")
	var capture := ErrorCapture.new()
	capture.start()
	root.add_child(scope)
	capture.stop()
	_runner.assert_equal(scope.state, ContainerScopeScript.State.FAILED, "一致する親が0件ならFAILEDになる")
	_runner.assert_true(capture.contains("親スコープID 'missing' は1個必要ですが、0個見つかりました"), "親が0件のエラーを出す")
	_runner.assert_false(scope.has_container(), "親探索失敗時はコンテナを保持しない")
	await _free_node(scope)


func _test_duplicate_parent_fails_async() -> void:
	_runner.change_test_name("duplicate_parent_fails")
	var child := _get_new_container_scope(&"child", &"duplicate")
	var holder := _holder_with([child, _get_new_container_scope(&"duplicate"), _get_new_container_scope(&"duplicate")])
	var capture := ErrorCapture.new()
	capture.start()
	root.add_child(holder)
	capture.stop()
	_runner.assert_equal(child.state, ContainerScopeScript.State.FAILED, "一致する親が複数ならFAILEDになる")
	_runner.assert_true(capture.contains("親スコープID 'duplicate' は1個必要ですが、2個見つかりました"), "親が複数のエラーを出す")
	await _free_node(holder)


func _test_circular_parent_relationship_async() -> void:
	_runner.change_test_name("circular_parent_relationship")
	var scope_a := _get_new_container_scope(&"a", &"b")
	var scope_b := _get_new_container_scope(&"b", &"a")
	var holder := _holder_with([scope_a, scope_b])
	var capture := ErrorCapture.new()
	capture.start()
	root.add_child(holder)
	capture.stop()
	_runner.assert_equal(scope_a.state, ContainerScopeScript.State.CIRCULAR, "循環を開始したスコープをCIRCULARにする")
	_runner.assert_equal(scope_b.state, ContainerScopeScript.State.FAILED, "循環相手の初期化も失敗する")
	_runner.assert_true(capture.contains("コンテナの親子関係が循環しています"), "循環エラーを出す")
	await _free_node(holder)


func _test_parent_failure_propagates_to_child_async() -> void:
	_runner.change_test_name("parent_failure_propagates_to_child")
	var parent := _get_new_container_scope(&"parent", &"missing")
	var child := _get_new_container_scope(&"child", &"parent")
	var holder := _holder_with([child, parent])
	var capture := ErrorCapture.new()
	capture.start()
	root.add_child(holder)
	capture.stop()
	_runner.assert_equal(parent.state, ContainerScopeScript.State.FAILED, "親の初期化失敗を確認する")
	_runner.assert_equal(child.state, ContainerScopeScript.State.FAILED, "失敗した親を持つ子もFAILEDになる")
	_runner.assert_false(child.has_container(), "親失敗時に子はコンテナを保持しない")
	await _free_node(holder)


func _test_injection_failure_clears_container_async() -> void:
	_runner.change_test_name("injection_failure_clears_container")
	var failed_target = MissingMethodTarget.new()
	var scope := _get_new_container_scope(&"scope")
	scope._inject_target.assign([failed_target])
	var holder := _holder_with([failed_target, scope])
	var capture := ErrorCapture.new()
	capture.start()
	root.add_child(holder)
	capture.stop()
	_runner.assert_equal(scope.state, ContainerScopeScript.State.FAILED, "注入対象の失敗でFAILEDになる")
	_runner.assert_false(scope.has_container(), "注入失敗時にコンテナをクリアする")
	await _free_node(holder)


func _test_exit_tree_resets_scope_async() -> void:
	_runner.change_test_name("exit_tree_resets_scope")
	var scope: ContainerScopeTestContainerScope = BasicScopeScene.instantiate()
	root.add_child(scope)
	root.remove_child(scope)
	_runner.assert_equal(scope.state, ContainerScopeScript.State.NOT_INITIALIZED, "_exit_tree後にNOT_INITIALIZEDへ戻る")
	_runner.assert_false(scope.has_container(), "_exit_tree後にコンテナを破棄する")
	await _free_node(scope)


func _test_targets_are_injected_in_array_order_async() -> void:
	_runner.change_test_name("targets_are_injected_in_array_order")
	var order: Array[StringName] = []
	var first := _recording_target(&"first", order)
	var second := _recording_target(&"second", order)
	var third := _recording_target(&"third", order)
	var scope := _get_new_container_scope(&"scope")
	scope._inject_target.assign([first, second, third])
	var holder := _holder_with([first, second, third, scope])
	root.add_child(holder)
	_runner.assert_array(order, [&"first", &"second", &"third"], "複数対象を配列順に注入する")
	await _free_node(holder)


func _test_injection_stops_at_first_failure_async() -> void:
	_runner.change_test_name("injection_stops_at_first_failure")
	var order: Array[StringName] = []
	var first := _recording_target(&"first", order)
	var failed := MissingMethodTarget.new()
	var skipped := _recording_target(&"skipped", order)
	var scope := _get_new_container_scope(&"scope")
	scope._inject_target.assign([first, failed, skipped])
	var holder := _holder_with([first, failed, skipped, scope])
	var capture := ErrorCapture.new()
	capture.start()
	root.add_child(holder)
	capture.stop()
	_runner.assert_array(order, [&"first"], "途中の失敗後は残りの対象へ注入しない")
	_runner.assert_equal(scope.state, ContainerScopeScript.State.FAILED, "途中の注入失敗でFAILEDになる")
	await _free_node(holder)


func _get_new_container_scope(id: StringName, parent_id: StringName = &"", key: StringName = &"") -> ContainerScopeTestContainerScope:
	var scope := ContainerScopeTestContainerScope.new()
	scope.scope_id = id
	scope.parent_scope_id = parent_id
	scope.registration_key = key
	scope.registration_label = String(id)
	scope.add_to_group(Const.GROUP_NAME)
	return scope


func _holder_with(nodes: Array) -> Node:
	var holder := Node.new()
	for node: Node in nodes:
		holder.add_child(node)
	return holder


func _recording_target(label: StringName, order: Array[StringName]) -> Node:
	var target = OrderedInjectionTarget.new()
	target.label = label
	target.order = order
	return target


func _free_node(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
	await process_frame
