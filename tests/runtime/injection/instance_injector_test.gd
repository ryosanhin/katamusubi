extends SceneTree


const InstanceInjector := preload(
	"res://addons/katamusubi/runtime/injection/instance_injector.gd"
)
const BaseService := preload("res://tests/fixtures/services/base_service.gd")
const DerivedService := preload("res://tests/fixtures/services/derived_service.gd")
const TrackedService := preload("res://tests/fixtures/services/tracked_service.gd")
const NoArgumentsNode := preload(
	"res://tests/fixtures/injection_targets/recording_no_arguments_node.gd"
)
const ServicesNode := preload(
	"res://tests/fixtures/injection_targets/recording_services_node.gd"
)
const SingleServiceNode := preload(
	"res://tests/fixtures/injection_targets/recording_single_service_node.gd"
)
const FailedResolutionNode := preload(
	"res://tests/fixtures/injection_targets/recording_failed_resolution_node.gd"
)
const NoMethodNode := preload(
	"res://tests/fixtures/injection_targets/node_without_injection_method.gd"
)

var _runner := TestRunner.new(true)
var _container: InjectionContainer
var _target: Variant


func _init() -> void:
	# SceneTreeの初期化を完了し、追加したNodeが即座にツリー内となる状態で検証します。
	await process_frame
	await _test_no_arguments()
	await _test_argument_order_key_precedence_and_fallback()
	await _test_resolution_failure_is_atomic()
	await _test_missing_method()
	await _test_invalid_targets()
	await _test_resolved_reference_and_success_state()
	await _test_singleton_lifecycle()
	await _test_transient_lifecycle()

	await _runner.finish(self, "InstanceInjector")


func _test_no_arguments() -> void:
	_runner.change_test_name("no_arguments")
	_setup_target(NoArgumentsNode.new())
	var result = _injector().try_inject_arguments(_target)

	_runner.assert_true(result, "引数なしの注入に成功した場合だけtrueを返す")
	_runner.assert_equal(_target.injection_count, 1, "引数なしの注入メソッドを一度だけ呼ぶ")
	_runner.assert_array(_target.call_order, [&"inject_dependency"], "実際にメソッドが実行された順序を記録する")
	_runner.assert_true(_target.was_injected, "注入先メソッドによる状態変更を確認する")
	await _cleanup()


func _test_argument_order_key_precedence_and_fallback() -> void:
	_runner.change_test_name("argument_order_key_precedence_and_fallback")
	_setup_target(ServicesNode.new())
	var default_service := DerivedService.new()
	var keyed_service := DerivedService.new()
	_container.register(_instance_as(default_service))
	_container.register(_instance_as(keyed_service, &"primary_service"))
	var result = _injector().try_inject_arguments(_target)

	_runner.assert_true(result, "複数引数をすべて解決した場合はtrueを返す")
	_runner.assert_equal(_target.injection_count, 1, "複数引数でも注入メソッドを一度だけ呼ぶ")
	_runner.assert_same(_target.received_services[0], keyed_service, "引数名と同じキー付き登録を優先する")
	_runner.assert_same(_target.received_services[1], default_service, "対応するキーがなければデフォルト登録を使う")
	_runner.assert_array(
		_target.call_order,
		[&"primary_service", &"fallback_service", &"method_completed"],
		"サービスを宣言順に渡してメソッドを完了する",
	)
	_runner.assert_true(_target.was_injected, "Callableの有効性だけでなく注入先の状態変更を確認する")
	await _cleanup()


func _test_resolution_failure_is_atomic() -> void:
	_runner.change_test_name("resolution_failure_is_atomic")
	_setup_target(FailedResolutionNode.new())
	_container.register(_instance_as(DerivedService.new()))
	var capture := ErrorCapture.new()
	capture.start()
	var result = _injector().try_inject_arguments(_target)
	capture.stop()

	_runner.assert_false(result, "途中の引数を解決できなければfalseを返す")
	_runner.assert_equal(_target.injection_count, 0, "一部を解決済みでも注入メソッドを呼ばない")
	_runner.assert_false(_target.was_injected, "失敗時は注入先の状態を変更しない")
	await _cleanup()


func _test_missing_method() -> void:
	_runner.change_test_name("missing_method")
	_setup_target(NoMethodNode.new())
	var capture := ErrorCapture.new()
	capture.start()
	var result = _injector().try_inject_arguments(_target)
	capture.stop()

	_runner.assert_false(result, "inject_dependencyがないNodeは呼び出し段階でfalseを返す")
	_runner.assert_true(capture.contains("依存注入メソッドを呼び出せません"), "呼び出し失敗を報告する")
	_runner.assert_equal(_target.unrelated_call_count, 0, "別のメソッドを誤って呼ばない")
	await _cleanup()


func _test_invalid_targets() -> void:
	_runner.change_test_name("invalid_targets")
	_container = InjectionContainer.new(null)
	var injector = _injector()
	var capture := ErrorCapture.new()
	capture.start()
	_runner.assert_false(injector.try_inject_arguments(null), "nullを拒否する")

	var freed_target := NoArgumentsNode.new()
	freed_target.free()
	_runner.assert_false(injector.try_inject_arguments(freed_target), "解放済みNodeを拒否する")

	var outside_tree := NoArgumentsNode.new()
	_runner.assert_false(injector.try_inject_arguments(outside_tree), "ツリー外Nodeを拒否する")
	outside_tree.free()

	var scriptless := Node.new()
	root.add_child(scriptless)
	_runner.assert_false(injector.try_inject_arguments(scriptless), "ScriptなしNodeを拒否する")
	capture.stop()
	scriptless.queue_free()
	_container.clear()
	_container = null
	await process_frame


func _test_resolved_reference_and_success_state() -> void:
	_runner.change_test_name("resolved_reference_and_success_state")
	_setup_target(SingleServiceNode.new())
	var provided := TrackedService.new()
	_container.register(ServiceRegistration.create_instance_registration(provided, TrackedService))
	var expected = _container.resolve_with_script(TrackedService)
	var result = _injector().try_inject_arguments(_target)

	_runner.assert_true(result, "注入メソッドを実行できた成功時にtrueを返す")
	_runner.assert_same(_target.received_service, expected, "対象が保持する参照はコンテナの解決結果と一致する")
	_runner.assert_true(_target.was_injected, "注入先メソッドの状態変更が行われる")
	await _cleanup()


func _test_singleton_lifecycle() -> void:
	_runner.change_test_name("singleton_lifecycle")
	TrackedService.reset_generation_count()
	_container = InjectionContainer.new(null)
	_container.register(ServiceRegistration.create_class_registration(TrackedService, Lifecycle.Type.SINGLETON))
	var first := SingleServiceNode.new()
	var second := SingleServiceNode.new()
	root.add_child(first)
	root.add_child(second)
	var injector = _injector()
	_runner.assert_true(injector.try_inject_arguments(first), "最初のSingleton注入に成功する")
	_runner.assert_true(injector.try_inject_arguments(second), "二度目のSingleton注入に成功する")
	_runner.assert_same(second.received_service, first.received_service, "注入経由でもSingleton参照を共有する")
	_runner.assert_equal(TrackedService.generation_count, 1, "注入経由のSingletonを一度だけ生成する")
	first.queue_free()
	second.queue_free()
	_container.clear()
	_container = null
	await process_frame


func _test_transient_lifecycle() -> void:
	_runner.change_test_name("transient_lifecycle")
	TrackedService.reset_generation_count()
	_container = InjectionContainer.new(null)
	_container.register(ServiceRegistration.create_class_registration(TrackedService, Lifecycle.Type.TRANSIENT))
	var first := SingleServiceNode.new()
	var second := SingleServiceNode.new()
	root.add_child(first)
	root.add_child(second)
	var injector = _injector()
	_runner.assert_true(injector.try_inject_arguments(first), "最初のTransient注入に成功する")
	_runner.assert_true(injector.try_inject_arguments(second), "二度目のTransient注入に成功する")
	_runner.assert_true(not is_same(second.received_service, first.received_service), "注入経由でもTransientを毎回生成する")
	_runner.assert_equal(TrackedService.generation_count, 2, "注入回数ごとにTransientを生成する")
	first.queue_free()
	second.queue_free()
	_container.clear()
	_container = null
	await process_frame


func _setup_target(target: Node) -> void:
	_container = InjectionContainer.new(null)
	_target = target
	root.add_child(_target)


func _injector():
	return InstanceInjector.new(_container, &"instance_injector_test")


func _instance_as(instance: TestDerivedService, key: StringName = &"") -> ServiceRegistration:
	return ServiceRegistration.create_instance_registration(instance, DerivedService).as_type(BaseService).with_key(key)


func _cleanup() -> void:
	if is_instance_valid(_target):
		_target.queue_free()
	_target = null
	if _container != null:
		_container.clear()
	_container = null
	await process_frame
