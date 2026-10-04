extends SceneTree


const InstanceInjector := preload(
	"res://addons/katamusubi/runtime/injection/instance_injector.gd"
)
const BaseService := preload("fixtures/services/base_service.gd")
const DerivedService := preload("fixtures/services/derived_service.gd")
const TrackedService := preload("fixtures/services/tracked_service.gd")
const UnnamedService := preload("fixtures/services/unnamed_service.gd")

const NoArgumentsNode := preload("fixtures/injection_targets/no_argument_method.gd")
const ServicesNode := preload("fixtures/injection_targets/recording_services_node.gd")
const SingleServiceNode := preload("fixtures/injection_targets/recording_single_service_node.gd")
const FailedResolutionNode := preload("fixtures/injection_targets/recording_failed_resolution_node.gd")
const NoMethodNode := preload("fixtures/injection_targets/no_injection_method.gd")
const NonGlobalNode := preload("fixtures/injection_targets/recording_non_global_node.gd")
const UntypedNode := preload("fixtures/injection_targets/recording_untyped_node.gd")

var _runner := TestRunner.new(true)
var _container: InjectionContainer
var _target: Variant


func _init() -> void:
	# SceneTreeの初期化を完了し、追加したNodeが即座にツリー内となる状態で検証します。
	await process_frame
	await _test_no_arguments_async()
	await _test_argument_order_key_precedence_and_fallback_async()
	await _test_failed_injection_does_not_call_method_async()
	await _test_missing_method_async()
	await _test_resolved_reference_async()

	await _runner.finish(self, "InstanceInjector")


## 引数のない注入メソッドを呼び出し、成功状態と副作用を正しく反映することを確認します。
func _test_no_arguments_async() -> void:
	_runner.change_test_name("no_arguments")
	_setup_target(NoArgumentsNode.new())
	var result = _injector().try_inject_arguments(_target)

	_runner.assert_true(result, "引数なしの注入に成功した場合だけtrueを返す")
	_runner.assert_equal(_target.injection_count, 1, "引数なしの注入メソッドを一度だけ呼ぶ")
	await _cleanup_async()


## 複数引数を宣言順に解決し、引数名キーの優先と既定キーへのフォールバックを確認します。
func _test_argument_order_key_precedence_and_fallback_async() -> void:
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
	_container.clear()
	_runner.assert_same(_target.received_services[0], keyed_service, "clear後も注入先のキー付き参照を維持する")
	_runner.assert_same(_target.received_services[1], default_service, "clear後も注入先の既定参照を維持する")
	default_service.free()
	keyed_service.free()
	await _cleanup_async()


## 型指定不足や途中の解決失敗でも、注入メソッドを呼ばない。
func _test_failed_injection_does_not_call_method_async() -> void:
	# ケース名、対象Script、登録するScript、公開するScript。
	var cases := [
		["missing_global_type", UntypedNode, null, null],
		["non_global_type", NonGlobalNode, UnnamedService, UnnamedService],
		["resolution_failure", FailedResolutionNode, DerivedService, BaseService],
	]
	for test_case in cases:
		_runner.change_test_name(test_case[0])
		_setup_target(test_case[1].new())
		var service: Node = null
		if test_case[2] != null:
			service = test_case[2].new()
			_container.register(
				ServiceRegistration.create_instance_registration(service).as_type(test_case[3])
			)

		var result = _injector().try_inject_arguments(_target)
		_runner.assert_false(result, "引数をすべて決定・解決できなければ失敗する")
		_runner.assert_equal(_target.injection_count, 0, "途中まで解決しても注入しない")
		if service != null:
			service.free()
		await _cleanup_async()


## 注入メソッドを持たないNodeへの注入が失敗し、無関係なメソッドを呼ばないことを確認します。
func _test_missing_method_async() -> void:
	_runner.change_test_name("missing_method")
	_setup_target(NoMethodNode.new())
	var capture := ErrorCapture.new()
	capture.start()
	var result = _injector().try_inject_arguments(_target)
	capture.stop()

	_runner.assert_false(result, "inject_dependencyがないNodeは設定処理の前にfalseを返す")
	_runner.assert_equal(capture.errors.size(), 1, "注入失敗のログを報告する代表例")
	_runner.assert_equal(_target.unrelated_call_count, 0, "別のメソッドを誤って呼ばない")
	await _cleanup_async()


## 登録したサービスの参照を、そのまま対象へ渡すことを確認します。
func _test_resolved_reference_async() -> void:
	_runner.change_test_name("resolved_reference")
	_setup_target(SingleServiceNode.new())
	var provided := TrackedService.new()
	_container.register(ServiceRegistration.create_instance_registration(provided))
	var result = _injector().try_inject_arguments(_target)

	_runner.assert_true(result, "注入メソッドを実行できた成功時にtrueを返す")
	_runner.assert_equal(_target.injection_count, 1, "注入メソッドを一度だけ呼ぶ")
	_runner.assert_same(_target.received_service, provided, "登録したインスタンスをそのまま渡す")
	provided.free()
	await _cleanup_async()


func _setup_target(target: Node) -> void:
	_container = InjectionContainer.new(null)
	_target = target
	root.add_child(_target)


func _injector():
	return InstanceInjector.new(_container, &"instance_injector_test")


func _instance_as(instance: InstanceInjectorTestDerivedService, key: StringName = &"") -> ServiceRegistration:
	return ServiceRegistration.create_instance_registration(instance).as_type(BaseService).with_key(key)


func _cleanup_async() -> void:
	if is_instance_valid(_target):
		_target.queue_free()
	_target = null
	if _container != null:
		_container.clear()
	_container = null
	await process_frame
