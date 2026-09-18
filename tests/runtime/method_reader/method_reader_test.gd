extends SceneTree


const MethodReader := preload("res://addons/katamusubi/runtime/injection/method_reader.gd")
const ArgumentData := preload("res://addons/katamusubi/runtime/injection/argument_data.gd")

const INJECTION_METHOD_NAME := &"inject_dependency"

const BaseService := preload("fixtures/services/base_service.gd")
const DerivedService := preload("fixtures/services/derived_service.gd")

const NoInjectionMethod := preload("fixtures/injection_targets/no_injection_method.gd")
const NoArgumentMethod := preload("fixtures/injection_targets/no_argument_method.gd")
const ClassArgumentsMethod := preload("fixtures/injection_targets/class_arguments_method.gd")
const BuiltinArgumentsMethod := preload("fixtures/injection_targets/builtin_arguments_method.gd")

var _runner := TestRunner.new(true)


func _init() -> void:
	_test_missing_method()
	_test_no_arguments()
	_test_class_arguments_and_defaults()
	_test_builtin_arguments()
	_test_argument_data_string()

	await _runner.finish(self, "MethodReader")


## inject_dependencyメソッドを持たないスクリプトから空の引数一覧を取得することを確認します。
func _test_missing_method() -> void:
	_runner.change_test_name("missing_method")
	var arguments := _read(NoInjectionMethod)

	_runner.assert_true(arguments.is_empty(), "inject_dependencyがなければ空配列を返す")


## 引数のないinject_dependencyメソッドから空の引数一覧を取得することを確認します。
func _test_no_arguments() -> void:
	_runner.change_test_name("no_arguments")
	var arguments := _read(NoArgumentMethod)

	_runner.assert_true(arguments.is_empty(), "引数なしのinject_dependencyなら空配列を返す")


## デフォルト値を含むクラス型引数を宣言順に読み取り、型情報を保持することを確認します。
func _test_class_arguments_and_defaults() -> void:
	_runner.change_test_name("class_arguments_and_defaults")
	var arguments := _read(ClassArgumentsMethod)

	_runner.assert_equal(arguments.size(), 2, "デフォルト引数を含むすべての引数を返す")
	_runner.assert_array(
		arguments.map(func(argument: ArgumentData) -> StringName: return argument.arg_name),
		[&"base_service", &"derived_service"],
		"複数のクラス型引数を宣言順に返す",
	)
	_runner.assert_true(arguments[0].service_type == BaseService, "グローバルクラスのScriptを解決条件にする")
	_runner.assert_equal(arguments[0].arg_type, TYPE_OBJECT, "第1引数の型を保持する")
	_runner.assert_true(arguments[1].service_type == DerivedService, "各グローバルクラスのScriptを保持する")
	_runner.assert_equal(arguments[1].arg_type, TYPE_OBJECT, "第2引数の型を保持する")


## 組み込み型の全引数を宣言順に読み取り、それぞれの型情報を保持することを確認します。
func _test_builtin_arguments() -> void:
	_runner.change_test_name("builtin_arguments")
	var arguments := _read(BuiltinArgumentsMethod)

	_runner.assert_equal(arguments.size(), 3, "すべての組み込み型引数を返す")
	_runner.assert_array(
		arguments.map(func(argument: ArgumentData) -> StringName: return argument.arg_name),
		[&"count", &"display_name", &"position"],
		"組み込み型引数を宣言順に返す",
	)
	_runner.assert_null(arguments[0].service_type, "組み込み型intにサービスScriptを設定しない")
	_runner.assert_equal(arguments[0].arg_type, TYPE_INT, "第1引数の型を保持する")
	_runner.assert_null(arguments[1].service_type, "組み込み型StringにサービスScriptを設定しない")
	_runner.assert_equal(arguments[1].arg_type, TYPE_STRING, "第2引数の型を保持する")
	_runner.assert_null(arguments[2].service_type, "組み込み型Vector2にサービスScriptを設定しない")
	_runner.assert_equal(arguments[2].arg_type, TYPE_VECTOR2, "第3引数の型を保持する")


## 引数データの文字列表現に、引数名、クラス名、型番号、型名が含まれることを確認します。
func _test_argument_data_string() -> void:
	_runner.change_test_name("argument_data_string")
	var argument := ArgumentData.new(&"service", BaseService, TYPE_OBJECT)
	var description := str(argument)

	_runner.assert_true("service" in description, "文字列表現に引数名を含む")
	_runner.assert_true("MethodReaderTestBaseService" in description, "文字列表現にクラス名を含む")
	_runner.assert_true(str(TYPE_OBJECT) in description, "文字列表現に型番号を含む")
	_runner.assert_true(type_string(TYPE_OBJECT) in description, "文字列表現に型名を含む")


## MethodReaderを使って引数を取得
func _read(script: Script) -> Array[ArgumentData]:
	return MethodReader.new(INJECTION_METHOD_NAME).get_injection_arguments(script)
