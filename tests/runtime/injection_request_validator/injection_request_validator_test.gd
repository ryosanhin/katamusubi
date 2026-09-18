extends SceneTree

const InjectionRequestValidator := preload(
	"res://addons/katamusubi/runtime/injection/injection_request_validator.gd"
)
const MethodReader := preload(
	"res://addons/katamusubi/runtime/injection/method_reader.gd"
)
const Const := preload("res://addons/katamusubi/katamusubi_global.gd")
const BaseService := preload(
	"res://tests/runtime/instance_injector/fixtures/services/base_service.gd"
)
const DerivedService := preload(
	"res://tests/runtime/instance_injector/fixtures/services/derived_service.gd"
)
const UnrelatedService := preload(
	"res://tests/runtime/instance_injector/fixtures/services/unrelated_service.gd"
)
const NoArgumentsNode := preload(
	"res://tests/runtime/instance_injector/fixtures/injection_targets/no_argument_method.gd"
)
const InvalidTypeOverrideNode := preload(
	"res://tests/runtime/instance_injector/fixtures/injection_targets/recording_invalid_type_override_node.gd"
)

var _runner := TestRunner.new(true)


func _init() -> void:
	await process_frame
	_test_invalid_targets()
	await _test_type_override_results_async()
	await _test_invalid_type_overrides_async()
	await _runner.finish(self, "InjectionRequestValidator")


## null、解放済み、ツリー外、Scriptなしの対象をそれぞれ診断することを確認します。
func _test_invalid_targets() -> void:
	_runner.change_test_name("invalid_targets")
	_expect_diagnostic(
		InjectionRequestValidator.validate_target(null, &"validator_test"),
		"対象が null です",
	)

	var freed_target := NoArgumentsNode.new()
	freed_target.free()
	_expect_diagnostic(
		InjectionRequestValidator.validate_target(freed_target, &"validator_test"),
		"既に解放されています",
	)

	var outside_tree := NoArgumentsNode.new()
	_expect_diagnostic(
		InjectionRequestValidator.validate_target(outside_tree, &"validator_test"),
		"ツリーに存在しません",
	)
	outside_tree.free()

	var scriptless := Node.new()
	root.add_child(scriptless)
	_expect_diagnostic(
		InjectionRequestValidator.validate_target(scriptless, &"validator_test"),
		"スクリプトがありません",
	)
	scriptless.free()


## 正常な型オーバーライドを型付き辞書へ正規化し、診断なしで返すことを確認します。
func _test_type_override_results_async() -> void:
	_runner.change_test_name("type_override_result")
	var target := InvalidTypeOverrideNode.new()
	root.add_child(target)
	var arguments := MethodReader.new(Const.INJECTION_METHOD_NAME).get_injection_arguments(
		target.get_script()
	)
	var result := InjectionRequestValidator.validate_type_overrides(
		target,
		arguments,
		{"service": DerivedService},
	)

	_runner.assert_true(result.is_valid(), "正常な設定では診断情報を返さない")
	_runner.assert_equal(result.overrides.size(), 1, "検証済みの設定だけを辞書へ格納する")
	_runner.assert_true(result.overrides.has(&"service"), "StringキーをStringNameへ正規化する")
	_runner.assert_same(result.overrides[&"service"], DerivedService, "検証済みScriptを保持する")
	target.queue_free()
	await process_frame


## 設定形式、引数名、値、型互換性の診断を検証クラスだけで完結できることを確認します。
func _test_invalid_type_overrides_async() -> void:
	var invalid_cases := [
		["non_dictionary", 42, &"<判定不能>", "42", "戻り値がDictionaryではありません"],
		["invalid_key", {42: BaseService}, 42, str(BaseService), "存在しない引数名です"],
		["unknown_argument", {&"unknown": BaseService}, &"unknown", str(BaseService), "存在しない引数名です"],
		["null_value", {&"service": null}, &"service", "<null>", "有効なScriptではありません"],
		["non_script_value", {&"service": 42}, &"service", "42", "有効なScriptではありません"],
		["incompatible_type", {&"service": UnrelatedService}, &"service", str(UnrelatedService), "派生型ではありません"],
	]

	for invalid_case in invalid_cases:
		_runner.change_test_name("invalid_type_override_%s" % invalid_case[0])
		var target := InvalidTypeOverrideNode.new()
		root.add_child(target)
		var arguments := MethodReader.new(Const.INJECTION_METHOD_NAME).get_injection_arguments(
			target.get_script()
		)
		var result := InjectionRequestValidator.validate_type_overrides(
			target,
			arguments,
			invalid_case[1],
		)

		_runner.assert_false(result.is_valid(), "不正な設定では診断情報を返す")
		_runner.assert_true(result.overrides.is_empty(), "不正な設定を検証済み辞書へ残さない")
		_expect_diagnostic(result.diagnostics, str(target.get_path()))
		_expect_diagnostic(result.diagnostics, str(invalid_case[2]))
		_expect_diagnostic(result.diagnostics, invalid_case[3])
		_expect_diagnostic(result.diagnostics, invalid_case[4])
		target.queue_free()
		await process_frame


func _expect_diagnostic(diagnostics: PackedStringArray, expected: String) -> void:
	_runner.assert_expected_error(
		diagnostics,
		expected,
		"診断情報に「%s」を含む" % expected,
	)
