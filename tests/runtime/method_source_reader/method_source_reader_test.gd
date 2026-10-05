extends SceneTree

const Reader := preload("res://addons/katamusubi/runtime/injection/method_source_reader.gd")
const Result := preload("res://addons/katamusubi/runtime/injection/method_source_result.gd")
const BaseTarget := preload("fixtures/base_target.gd")
const InheritedTarget := preload("fixtures/inherited_target.gd")
const OverriddenTarget := preload("fixtures/overridden_target.gd")
const DefaultOverrideTarget := preload("fixtures/default_override_target.gd")

var _runner := TestRunner.new(true)


## 宣言元の探索と引数部分の解析を確認する。
func _init() -> void:
	_test_declarations()
	_test_source_notation()
	_test_failures()
	await _runner.finish(self, "MethodSourceReader")


## 実際に読み込んだScriptの継承とオーバーライドを確認する。
func _test_declarations() -> void:
	_runner.change_test_name("declarations")
	var inherited := Reader.read(InheritedTarget, &"inject_dependency")
	_runner.assert_true(inherited.is_valid(), "継承メソッドの解析に成功する")
	_runner.assert_same(inherited.declaring_script, BaseTarget, "基底の定義を宣言元とする")
	if inherited.arguments.size() == 2:
		_runner.assert_equal(inherited.arguments[0].type_name, "Manager", "preload定数の表記を保持する")
		_runner.assert_equal(inherited.arguments[1].type_name, "MethodReaderTestDerivedService", "グローバルクラスの表記を保持する")
	_runner.assert_equal(inherited.arguments.size(), 2, "複数行と末尾カンマを読み取る")
	var overridden := Reader.read(OverriddenTarget, &"inject_dependency")
	_runner.assert_same(overridden.declaring_script, OverriddenTarget, "子のオーバーライドを優先する")
	if overridden.arguments.size() == 2:
		_runner.assert_equal(overridden.arguments[1].arg_name, &"replacement", "子の引数宣言を採用する")
	_runner.assert_equal(overridden.arguments.size(), 2, "子の全引数を取得する")
	var invalid_override := Reader.read(DefaultOverrideTarget, &"inject_dependency")
	_runner.assert_equal(invalid_override.error_code, Result.ErrorCode.DEFAULT_ARGUMENT, "非対応の子定義で失敗する")
	_runner.assert_same(invalid_override.declaring_script, DefaultOverrideTarget, "失敗しても基底定義へ切り替えない")


## 文字列や内部クラスを探索対象にせず、表記と順序を保持する。
func _test_source_notation() -> void:
	_runner.change_test_name("source_notation")
	var source := "extends Node\n"
	source += "# func inject_dependency(fake: Wrong):\n"
	source += "const TEXT = \"\"\"\nfunc inject_dependency(fake: Wrong):\n\"\"\"\n"
	source += "const ESCAPED = \"escaped \\\" # func inject_dependency(fake: Wrong)\"\n"
	source += "class Inner:\n\tfunc inject_dependency(fake: Wrong):\n\t\tpass\n"
	source += "func inject_dependency_other(fake: Wrong):\n\tpass\n"
	source += "func inject_dependency(\n first: Service, # ), ignored: Wrong\n second: Other,\n) -> void:\n\tpass\n"
	var result := _read_source(source.replace("\n", "\r\n"))
	_runner.assert_true(result.is_valid(), "コメント・文字列・内部クラス・似た名前を無視する")
	_runner.assert_equal(result.arguments.size(), 2, "CRLFとコメントを含む引数を取得する")
	if result.arguments.size() == 2:
		_runner.assert_equal(result.arguments[0].arg_name, &"first", "宣言順の引数名を保持する")
		_runner.assert_equal(result.arguments[1].type_name, "Other", "型表記を文字列で保持する")
	var empty := _read_source("extends Node\nfunc inject_dependency( # 引数なし\n):\n\tpass\n")
	_runner.assert_true(empty.is_valid() and empty.arguments.is_empty(), "引数なしは成功した空配列として返す")
	var builtin := _read_source("extends Node\nfunc inject_dependency(value: int):\n\tpass\n")
	_runner.assert_true(builtin.is_valid(), "単一識別子のサービス型検証は後続処理に委ねる")


## 失敗コードと部分結果を公開しないことを確認する。
func _test_failures() -> void:
	_runner.change_test_name("failures")
	_runner.assert_equal(Reader.read(null, &"inject_dependency").error_code, Result.ErrorCode.MISSING_SCRIPT, "Scriptなしを区別する")
	_runner.assert_equal(Reader.read(GDScript.new(), &"inject_dependency").error_code, Result.ErrorCode.SOURCE_UNAVAILABLE, "ソースなしを区別する")
	_runner.assert_equal(_read_source("extends Node\n").error_code, Result.ErrorCode.MISSING_METHOD, "メソッドなしを区別する")
	var cases := {
		"untyped": Result.ErrorCode.MISSING_TYPE_ANNOTATION,
		"value: Service = null": Result.ErrorCode.DEFAULT_ARGUMENT,
		"value: Service = make(1, 2)": Result.ErrorCode.DEFAULT_ARGUMENT,
		"value: Array[Service]": Result.ErrorCode.UNSUPPORTED_TYPE_NOTATION,
		"value: Dictionary[String, Service]": Result.ErrorCode.UNSUPPORTED_TYPE_NOTATION,
		"value: Namespace.Service": Result.ErrorCode.UNSUPPORTED_TYPE_NOTATION,
		"value:": Result.ErrorCode.UNSUPPORTED_TYPE_NOTATION,
		"value: \"Service\"": Result.ErrorCode.UNSUPPORTED_TYPE_NOTATION,
		", value: Service": Result.ErrorCode.INVALID_ARGUMENTS,
		"first: Service": Result.ErrorCode.INVALID_ARGUMENTS,
	}
	for declaration: String in cases:
		var source := "extends Node\nfunc inject_dependency(first: Service, %s):\n\tpass\n" % declaration
		var result := _read_source(source)
		_runner.assert_equal(result.error_code, cases[declaration], "失敗理由を保持する: " + declaration)
		_runner.assert_true(result.arguments.is_empty(), "失敗時に先行引数を公開しない: " + declaration)
		_runner.assert_true(result.declaring_script != null, "失敗時も宣言元を保持する: " + declaration)
	var default_result := _read_source("extends Node\nfunc inject_dependency(value: Service = null):\n\tpass\n")
	_runner.assert_equal(default_result.arg_name, &"value", "失敗した引数名を保持する")
	var incomplete := _read_source("extends Node\nfunc inject_dependency(value: Service")
	_runner.assert_equal(incomplete.error_code, Result.ErrorCode.INVALID_ARGUMENTS, "閉じ括弧の欠落で失敗する")


## コンパイルせずにソース解析だけを行う。[br]
## [param source]: 非対応・不正な宣言を含む検証用ソース
func _read_source(source: String) -> Result:
	var script := GDScript.new()
	script.source_code = source
	return Reader.read(script, &"inject_dependency")
