extends SceneTree

const Reader := preload("res://addons/katamusubi/runtime/injection/method_source_reader.gd")
const Result := preload("res://addons/katamusubi/runtime/injection/method_source_result.gd")
const BaseTarget := preload("fixtures/base_target.gd")
const InheritedTarget := preload("fixtures/inherited_target.gd")
const OverriddenTarget := preload("fixtures/overridden_target.gd")
const DefaultOverrideTarget := preload("fixtures/default_override_target.gd")
const ContinuedTarget := preload("fixtures/continued_target.gd")

var _runner := TestRunner.new(true)


## 宣言元の探索と引数部分の解析を確認する。
func _init() -> void:
	_test_declarations()
	_test_source_notation()
	_test_line_continuations()
	_test_method_name_search()
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


## 有効な行継続と、マスク後に正規化することを確認する。
func _test_line_continuations() -> void:
	_runner.change_test_name("line_continuations")
	var continued_script: Script = ContinuedTarget
	var result := Reader.read(continued_script, &"inject_dependency")
	_runner.assert_true(result.is_valid(), "行継続を持つ宣言を解析する")
	_runner.assert_same(result.declaring_script, ContinuedTarget, "行継続を持つ子の定義を優先する")
	_runner.assert_equal(result.arguments.size(), 2, "行継続を持つ全引数を取得する")
	if result.arguments.size() == 2:
		_runner.assert_equal(result.arguments[0].arg_name, &"manager", "引数名とコロンの間の行継続を許可する")
		_runner.assert_equal(result.arguments[0].type_name, "Manager", "コロンと型名の間の行継続を許可する")
	var crlf := _read_source(continued_script.source_code.replace("\n", "\r\n"))
	_runner.assert_true(crlf.is_valid() and crlf.arguments.size() == 2, "CRLFの行継続にも対応する")

	var source := "extends Node\n"
	source += "const TEXT = \"func \\\n inject_dependency(fake: Wrong):\"\n"
	source += "class Inner:\n\tfunc \\\n\t\tinject_dependency(fake: Wrong):\n\t\tpass\n"
	source += "# コメント末尾のバックスラッシュ \\\n"
	source += "func inject_dependency(value: Service):\n\tpass\n"
	var masked := _read_source(source)
	_runner.assert_true(masked.is_valid() and masked.arguments.size() == 1, "文字列・コメント・内部クラスの行継続を誤検出しない")
	if masked.arguments.size() == 1:
		_runner.assert_equal(masked.arguments[0].arg_name, &"value", "コメントの次の行の宣言を保持する")
	for declaration in [
		"fu\\\nnc inject_dependency",
		"func inject_depen\\\ndency",
		"func\ninject_dependency",
	]:
		var split := _read_source("extends Node\n%s(value: Service):\n\tpass\n" % declaration)
		_runner.assert_equal(split.error_code, Result.ErrorCode.MISSING_METHOD, "無効な分割による宣言を採用しない")
	var split_type := _read_source("extends Node\nfunc inject_dependency(value: Ser\\\nvice):\n\tpass\n")
	_runner.assert_equal(split_type.error_code, Result.ErrorCode.UNSUPPORTED_TYPE_NOTATION, "分割した型名を結合しない")


## 渡したメソッド名だけを検索し、正規表現として解釈しないことを確認する。
func _test_method_name_search() -> void:
	_runner.change_test_name("method_name_search")
	var script := GDScript.new()
	script.source_code = "extends Node\nfunc inject_dependency_extra(wrong: Other):\n\tpass\n"
	script.source_code += "static func custom_inject(value: Service):\n\tpass\n"
	var custom := Reader.read(script, &"custom_inject")
	_runner.assert_true(custom.is_valid() and custom.arguments.size() == 1, "指定名のstaticメソッドを検索する")
	_runner.assert_equal(Reader.read(script, &"inject_dependency").error_code, Result.ErrorCode.MISSING_METHOD, "名前の前方一致では採用しない")
	for method_name: StringName in [&"", &".*", &"custom_inject|other", &"custom_inject("]:
		_runner.assert_equal(Reader.read(script, method_name).error_code, Result.ErrorCode.MISSING_METHOD, "識別子以外を検索パターンとして扱わない")


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
