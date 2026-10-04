extends SceneTree

const InjectionRequestValidator := preload(
		"res://addons/katamusubi/runtime/injection/injection_request_validator.gd"
)
const NoArgumentsNode := preload("fixtures/injection_targets/no_argument_method.gd")

const ErrorCode = InjectionRequestValidator.ErrorCode

var _runner := TestRunner.new(true)


func _init() -> void:
	await process_frame
	_test_invalid_targets()
	_test_valid_target()
	_test_error_formatting()
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


## ツリー内のScript付きNodeを注入対象として受け入れる。
func _test_valid_target() -> void:
	_runner.change_test_name("valid_target")
	var target := NoArgumentsNode.new()
	root.add_child(target)
	var result := InjectionRequestValidator.validate_target(target, &"validator_test")
	_runner.assert_true(result.is_valid(), "正常な対象を受け入れる")
	target.free()


## 説明文のテストは文面全体に依存せず、必要な情報だけ確認する。
func _test_error_formatting() -> void:
	_runner.change_test_name("error_formatting")
	var result := InjectionRequestValidator.ValidationResult.new()
	_runner.assert_equal(InjectionRequestValidator.format_error(result), "", "OKは説明文を持たない")
	result.error_code = ErrorCode.NULL_TARGET
	result.scope_name = &"format_scope"
	_runner.assert_true("format_scope" in InjectionRequestValidator.format_error(result), "対象検証の説明にスコープを含める")
	result.error_code = ErrorCode.MISSING_TARGET_SCRIPT
	result.target_path = "/root/format_target"
	_runner.assert_true(result.target_path in InjectionRequestValidator.format_error(result), "説明に対象パスを含める")


func _expect_code(result: InjectionRequestValidator.ValidationResult, expected: InjectionRequestValidator.ErrorCode) -> void:
	_runner.assert_equal(result.error_code, expected, "対象の失敗理由をコードで返す")
	_runner.assert_equal(result.scope_name, &"validator_test", "スコープ名を保持する")
