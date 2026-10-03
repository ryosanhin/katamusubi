extends SceneTree

const InjectionRequestValidator := preload(
		"res://addons/katamusubi/runtime/injection/injection_request_validator.gd"
)
const MethodReader := preload(
		"res://addons/katamusubi/runtime/injection/method_reader.gd"
)
const InstanceInjector := preload(
		"res://addons/katamusubi/runtime/injection/instance_injector.gd"
)

const BaseService := preload("fixtures/services/base_service.gd")
const DerivedService := preload("fixtures/services/derived_service.gd")
const UnrelatedService := preload("fixtures/services/unrelated_service.gd")
const NoArgumentsNode := preload("fixtures/injection_targets/no_argument_method.gd")
const InvalidTypeOverrideNode := preload("fixtures/injection_targets/recording_invalid_type_override_node.gd")

const ErrorCode = InjectionRequestValidator.ErrorCode
const ArgumentEntry := preload("res://addons/katamusubi/runtime/injection/argument_entry.gd")

var _runner := TestRunner.new(true)


func _init() -> void:
	await process_frame
	_test_invalid_targets()
	_test_non_object_override()
	_test_error_formatting()
	await _test_type_override_results_async()
	await _test_invalid_type_overrides_async()
	await _runner.finish(self, "InjectionRequestValidator")


## null、解放済み、ツリー外、Scriptなしの対象をそれぞれ診断することを確認します。
func _test_invalid_targets() -> void:
	_runner.change_test_name("invalid_targets")
	_expect_code(
		InjectionRequestValidator.validate_target(null, &"validator_test"),
		ErrorCode.NULL_TARGET,
	)

	var freed_target := NoArgumentsNode.new()
	freed_target.free()
	_expect_code(
		InjectionRequestValidator.validate_target(freed_target, &"validator_test"),
		ErrorCode.FREED_TARGET,
	)

	var outside_tree := NoArgumentsNode.new()
	_expect_code(
		InjectionRequestValidator.validate_target(outside_tree, &"validator_test"),
		ErrorCode.TARGET_OUTSIDE_TREE,
	)
	outside_tree.free()

	var scriptless := Node.new()
	root.add_child(scriptless)
	_expect_code(
		InjectionRequestValidator.validate_target(scriptless, &"validator_test"),
		ErrorCode.MISSING_TARGET_SCRIPT,
	)
	scriptless.free()


## 正常な型オーバーライドを型付き辞書へ正規化し、診断なしで返すことを確認します。
func _test_type_override_results_async() -> void:
	_runner.change_test_name("type_override_result")
	var target := InvalidTypeOverrideNode.new()
	root.add_child(target)
	var arguments := MethodReader.new(InstanceInjector.INJECTION_METHOD_NAME).get_injection_arguments(
		target.get_script()
	)
	var result := InjectionRequestValidator.validate_type_overrides(
		target,
		arguments,
		{"service": DerivedService},
	)

	_runner.assert_true(result.is_valid(), "正常な設定では成功を返す")
	_runner.assert_equal(result.code, ErrorCode.OK, "正常な設定はOKを返す")
	_runner.assert_true(InjectionRequestValidator.validate_target(target, &"validator_test").is_valid(), "正常な対象を受け入れる")
	_runner.assert_equal(result.overrides.size(), 1, "検証済みの設定だけを辞書へ格納する")
	_runner.assert_true(result.overrides.has(&"service"), "StringキーをStringNameへ正規化する")
	_runner.assert_same(result.overrides[&"service"], DerivedService, "検証済みScriptを保持する")
	target.queue_free()
	await process_frame


## 設定形式、引数名、値、型互換性の診断を検証クラスだけで完結できることを確認します。
func _test_invalid_type_overrides_async() -> void:
	var invalid_cases := [
		["non_dictionary", 42, &"<判定不能>", 42, ErrorCode.OVERRIDES_NOT_DICTIONARY],
		["invalid_key", {42: BaseService}, 42, BaseService, ErrorCode.INVALID_OVERRIDE_KEY],
		["unknown_argument", {&"unknown": BaseService}, &"unknown", BaseService, ErrorCode.UNKNOWN_ARGUMENT],
		["null_value", {&"service": null}, &"service", null, ErrorCode.INVALID_OVERRIDE_SCRIPT],
		["non_script_value", {&"service": 42}, &"service", 42, ErrorCode.INVALID_OVERRIDE_SCRIPT],
		["incompatible_type", {&"service": UnrelatedService}, &"service", UnrelatedService, ErrorCode.INCOMPATIBLE_OVERRIDE_TYPE],
	]

	var target := InvalidTypeOverrideNode.new()
	root.add_child(target)
	var arguments := MethodReader.new(InstanceInjector.INJECTION_METHOD_NAME).get_injection_arguments(
		target.get_script()
	)

	for invalid_case in invalid_cases:
		_runner.change_test_name("invalid_type_override_%s" % invalid_case[0])
		var result := InjectionRequestValidator.validate_type_overrides(
			target,
			arguments,
			invalid_case[1],
		)

		_runner.assert_true(result.overrides.is_empty(), "不正な設定を検証済み辞書へ残さない")
		_runner.assert_equal(result.code, invalid_case[4], "失敗理由をコードで返す")
		_runner.assert_equal(result.target_path, str(target.get_path()), "対象パスを保持する")
		_runner.assert_equal(result.argument_name, invalid_case[2], "問題の引数を保持する")
		_runner.assert_same(result.specified_value, invalid_case[3], "指定値を変換せず保持する")
		if result.code == ErrorCode.INCOMPATIBLE_OVERRIDE_TYPE:
			_runner.assert_same(result.expected_type, BaseService, "互換性検証の宣言型を保持する")

	target.queue_free()
	await process_frame


## 非Object引数の拒否と、途中まで正規化した辞書の破棄を確認する。
func _test_non_object_override() -> void:
	_runner.change_test_name("non_object_override")
	var target := InvalidTypeOverrideNode.new()
	root.add_child(target)
	var arguments: Array[ArgumentEntry] = [
		ArgumentEntry.new(&"service", BaseService, TYPE_OBJECT),
		ArgumentEntry.new(&"count", null, TYPE_INT),
	]
	var result := InjectionRequestValidator.validate_type_overrides(
		target, arguments, {&"service": DerivedService, &"count": BaseService},
	)
	_runner.assert_equal(result.code, ErrorCode.NON_OBJECT_ARGUMENT, "組み込み型の上書きを拒否する")
	_runner.assert_false(result.is_valid(), "失敗コードは無効な検証結果として扱う")
	_runner.assert_equal(result.argument_name, &"count", "失敗した引数名を保持する")
	_runner.assert_equal(result.argument_type, TYPE_INT, "元の引数型を保持する")
	_runner.assert_same(result.specified_value, BaseService, "指定されたScriptを保持する")
	_runner.assert_true(result.overrides.is_empty(), "途中の成功結果も破棄する")
	target.free()


## 説明文のテストは文面全体に依存せず、必要な情報だけ確認する。
func _test_error_formatting() -> void:
	_runner.change_test_name("error_formatting")
	var result := InjectionRequestValidator.ValidationResult.new()
	_runner.assert_equal(InjectionRequestValidator.format_error(result), "", "OKは説明文を持たない")
	result.code = ErrorCode.NULL_TARGET
	result.scope_name = &"format_scope"
	_runner.assert_true("format_scope" in InjectionRequestValidator.format_error(result), "対象検証の説明にスコープを含める")
	result.code = ErrorCode.UNKNOWN_ARGUMENT
	result.target_path = "/root/format_target"
	result.argument_name = &"format_argument"
	result.specified_value = 12345
	var message := InjectionRequestValidator.format_error(result)
	_runner.assert_true(result.target_path in message, "説明に対象パスを含める")
	_runner.assert_true(str(result.argument_name) in message, "説明に引数名を含める")
	_runner.assert_true("12345" in message, "説明に指定値を含める")


func _expect_code(result: InjectionRequestValidator.ValidationResult, expected: InjectionRequestValidator.ErrorCode) -> void:
	_runner.assert_equal(result.code, expected, "対象の失敗理由をコードで返す")
	_runner.assert_equal(result.scope_name, &"validator_test", "スコープ名を保持する")
