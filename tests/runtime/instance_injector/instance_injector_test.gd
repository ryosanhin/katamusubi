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
const TypeOverridesNode := preload("fixtures/injection_targets/recording_type_overrides_node.gd")
const KeyedTypeOverrideNode := preload("fixtures/injection_targets/recording_keyed_type_override_node.gd")
const UntypedNode := preload("fixtures/injection_targets/recording_untyped_node.gd")

var _runner := TestRunner.new(true)
var _container: InjectionContainer
var _target: Variant


func _init() -> void:
	# SceneTreeの初期化を完了し、追加したNodeが即座にツリー内となる状態で検証します。
	await process_frame
	await _test_no_arguments_async()
	await _test_argument_order_key_precedence_and_fallback_async()
	await _test_type_overrides_and_normal_resolution_async()
	await _test_overridden_type_prefers_argument_key_async()
	await _test_missing_type_override_async()
	await _test_missing_overridden_type_is_atomic_async()
	await _test_resolution_failure_is_atomic_async()
	await _test_missing_method_async()
	await _test_invalid_targets_async()
	await _test_resolved_reference_and_success_state_async()

	await _runner.finish(self, "InstanceInjector")


## 引数のない注入メソッドを呼び出し、成功状態と副作用を正しく反映することを確認します。
func _test_no_arguments_async() -> void:
	_runner.change_test_name("no_arguments")
	_setup_target(NoArgumentsNode.new())
	var result = _injector().try_inject_arguments(_target)

	_runner.assert_true(result, "引数なしの注入に成功した場合だけtrueを返す")
	_runner.assert_equal(_target.injection_count, 1, "引数なしの注入メソッドを一度だけ呼ぶ")
	_runner.assert_array(_target.call_order, [&"inject_dependency"], "実際にメソッドが実行された順序を記録する")
	_runner.assert_true(_target.was_injected, "注入先メソッドによる状態変更を確認する")
	await _cleanup_async()


## 型上書きを指定した引数と通常の引数を、それぞれ適切なサービス型で解決することを確認します。
func _test_type_overrides_and_normal_resolution_async() -> void:
	_runner.change_test_name("type_overrides_and_normal_resolution")
	_setup_target(TypeOverridesNode.new())
	var local_service := UnnamedService.new()
	var derived_service := DerivedService.new()
	var base_service := DerivedService.new()
	_container.register(ServiceRegistration.create_instance_registration(local_service, UnnamedService))
	_container.register(ServiceRegistration.create_instance_registration(derived_service, DerivedService))
	_container.register(_instance_as(base_service))
	var result = _injector().try_inject_arguments(_target)

	_runner.assert_true(result, "型オーバーライドを含む複数引数をすべて解決できる")
	_runner.assert_equal(_target.injection_count, 1, "一部をオーバーライドして注入メソッドを一度だけ呼ぶ")
	_runner.assert_same(_target.received_local_service, local_service, "非グローバルクラスをScript指定で解決する")
	_runner.assert_same(_target.received_derived_service, derived_service, "宣言型の派生型で解決する")
	_runner.assert_same(_target.received_base_service, base_service, "無関係な型を採用せず宣言型で解決する")
	_runner.assert_same(_target.received_normal_service, base_service, "辞書にない引数は通常の宣言型で解決する")
	await _cleanup_async()


## 型上書きされた引数でも引数名のキーを優先してサービスを解決することを確認します。
func _test_overridden_type_prefers_argument_key_async() -> void:
	_runner.change_test_name("overridden_type_prefers_argument_key")
	_setup_target(KeyedTypeOverrideNode.new())
	var default_service := DerivedService.new()
	var keyed_service := DerivedService.new()
	_container.register(ServiceRegistration.create_instance_registration(default_service, DerivedService))
	_container.register(
		ServiceRegistration.create_instance_registration(keyed_service, DerivedService)
			.with_key(&"overridden_service")
	)
	var result = _injector().try_inject_arguments(_target)

	_runner.assert_true(result, "オーバーライド後の型を解決できる")
	_runner.assert_same(_target.received_service, keyed_service, "オーバーライド後も引数名と同じキーを優先する")
	await _cleanup_async()


## 型上書きの設定が不足している場合、依存注入を拒否してエラーを報告することを確認します。
func _test_missing_type_override_async() -> void:
	_runner.change_test_name("missing_type_override")
	_setup_target(UntypedNode.new())
	var capture := ErrorCapture.new()
	capture.start()
	var result = _injector().try_inject_arguments(_target)
	capture.stop()

	_runner.assert_false(result, "型情報もオーバーライドもなければfalseを返す")
	_runner.assert_true(capture.contains("型オーバーライドが指定されていません"), "不足した型オーバーライドを報告する")
	_runner.assert_equal(_target.injection_count, 0, "型を決定できない場合は注入メソッドを呼ばない")
	await _cleanup_async()


## 上書き先の型を解決できない場合、注入メソッドを呼ばず対象の状態を変更しないことを確認します。
func _test_missing_overridden_type_is_atomic_async() -> void:
	_runner.change_test_name("missing_overridden_type_is_atomic")
	_setup_target(TypeOverridesNode.new())
	_container.register(
		ServiceRegistration.create_instance_registration(UnnamedService.new(), UnnamedService)
	)
	var capture := ErrorCapture.new()
	capture.start()
	var result = _injector().try_inject_arguments(_target)
	capture.stop()

	_runner.assert_false(result, "オーバーライド型の登録がなければfalseを返す")
	_runner.assert_equal(_target.injection_count, 0, "解決済み引数があっても注入メソッドを呼ばない")
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
	_runner.assert_array(
		_target.call_order,
		[&"primary_service", &"fallback_service", &"method_completed"],
		"サービスを宣言順に渡してメソッドを完了する",
	)
	_runner.assert_true(_target.was_injected, "Callableの有効性だけでなく注入先の状態変更を確認する")
	await _cleanup_async()


## 一部の引数を解決した後に失敗しても、注入メソッドを呼ばず変更を残さないことを確認します。
func _test_resolution_failure_is_atomic_async() -> void:
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
	await _cleanup_async()


## 注入メソッドを持たないNodeへの注入が失敗し、無関係なメソッドを呼ばないことを確認します。
func _test_missing_method_async() -> void:
	_runner.change_test_name("missing_method")
	_setup_target(NoMethodNode.new())
	var capture := ErrorCapture.new()
	capture.start()
	var result = _injector().try_inject_arguments(_target)
	capture.stop()

	_runner.assert_false(result, "inject_dependencyがないNodeは呼び出し段階でfalseを返す")
	_runner.assert_true(capture.contains("依存注入メソッドを呼び出せません"), "呼び出し失敗を報告する")
	_runner.assert_equal(_target.unrelated_call_count, 0, "別のメソッドを誤って呼ばない")
	await _cleanup_async()


## null、解放済み、ツリー外、ScriptなしのNodeを注入対象として拒否することを確認します。
func _test_invalid_targets_async() -> void:
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


## 解決したサービスと同じ参照を対象へ渡し、注入成功時の状態変更を確認します。
func _test_resolved_reference_and_success_state_async() -> void:
	_runner.change_test_name("resolved_reference_and_success_state")
	_setup_target(SingleServiceNode.new())
	var provided := TrackedService.new()
	_container.register(ServiceRegistration.create_instance_registration(provided, TrackedService))
	var expected = _container.resolve(TrackedService, &"")
	var result = _injector().try_inject_arguments(_target)

	_runner.assert_true(result, "注入メソッドを実行できた成功時にtrueを返す")
	_runner.assert_same(_target.received_service, expected, "対象が保持する参照はコンテナの解決結果と一致する")
	_runner.assert_true(_target.was_injected, "注入先メソッドの状態変更が行われる")
	await _cleanup_async()


func _setup_target(target: Node) -> void:
	_container = InjectionContainer.new(null)
	_target = target
	root.add_child(_target)


func _injector():
	return InstanceInjector.new(_container, &"instance_injector_test")


func _instance_as(instance: InstanceInjectorTestDerivedService, key: StringName = &"") -> ServiceRegistration:
	return ServiceRegistration.create_instance_registration(instance, DerivedService).as_type(BaseService).with_key(key)


func _cleanup_async() -> void:
	if is_instance_valid(_target):
		_target.queue_free()
	_target = null
	if _container != null:
		_container.clear()
	_container = null
	await process_frame
