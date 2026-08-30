extends SceneTree


const MethodReader := preload("res://addons/katamusubi/runtime/injection/method_reader.gd")
const ArgumentData := preload("res://addons/katamusubi/runtime/injection/argument_data.gd")
const Const := preload("res://addons/katamusubi/katamusubi_global.gd")
const NoInjectionMethod := preload(
	"res://tests/fixtures/injection_targets/no_injection_method.gd"
)
const NoArgumentMethod := preload(
	"res://tests/fixtures/injection_targets/no_argument_method.gd"
)
const ClassArgumentsMethod := preload(
	"res://tests/fixtures/injection_targets/class_arguments_method.gd"
)
const BuiltinArgumentsMethod := preload(
	"res://tests/fixtures/injection_targets/builtin_arguments_method.gd"
)
const AliasedMethod := preload(
	"res://tests/fixtures/injection_targets/aliased_method.gd"
)

var _runner := TestRunner.new(true)


func _init() -> void:
	_test_missing_method()
	_test_no_arguments()
	_test_class_arguments_and_defaults()
	_test_builtin_arguments()
	_test_aliased_method()
	_test_argument_data_string()

	await _runner.finish(self, "MethodReader")


func _test_missing_method() -> void:
	_runner.change_test_name("missing_method")
	var arguments := _read(NoInjectionMethod)

	_runner.assert_true(arguments.is_empty(), "inject_dependencyがなければ空配列を返す")


func _test_no_arguments() -> void:
	_runner.change_test_name("no_arguments")
	var arguments := _read(NoArgumentMethod)

	_runner.assert_true(arguments.is_empty(), "引数なしのinject_dependencyなら空配列を返す")


func _test_class_arguments_and_defaults() -> void:
	_runner.change_test_name("class_arguments_and_defaults")
	var arguments := _read(ClassArgumentsMethod)
	var reflected_arguments := _get_reflected_arguments(ClassArgumentsMethod, Const.METHOD_NAME)

	_runner.assert_equal(arguments.size(), 2, "デフォルト引数を含むすべての引数を返す")
	_runner.assert_array(
		arguments.map(func(argument: ArgumentData) -> StringName: return argument.arg_name),
		[&"base_service", &"derived_service"],
		"複数のクラス型引数を宣言順に返す",
	)
	_assert_matches_reflection(arguments, reflected_arguments)
	_runner.assert_equal(arguments[0].arg_class, &"TestBaseService", "グローバルクラス名を解決条件にする")
	_runner.assert_equal(arguments[1].arg_class, &"TestDerivedService", "各クラス型のグローバル名を保持する")


func _test_builtin_arguments() -> void:
	_runner.change_test_name("builtin_arguments")
	var arguments := _read(BuiltinArgumentsMethod)
	var reflected_arguments := _get_reflected_arguments(BuiltinArgumentsMethod, Const.METHOD_NAME)

	_assert_matches_reflection(arguments, reflected_arguments)
	for index in arguments.size():
		_runner.assert_equal(
			arguments[index].arg_class,
			StringName(type_string(arguments[index].arg_type)),
			"class_nameが空の組み込み型はtype_string()を解決条件にする: %s" % index,
		)


func _test_aliased_method() -> void:
	_runner.change_test_name("aliased_method")
	var arguments := MethodReader.new(&"provide_dependencies").get_injection_arguments(AliasedMethod)
	var reflected_arguments := _get_reflected_arguments(AliasedMethod, &"provide_dependencies")

	_runner.assert_array(
		arguments.map(func(argument: ArgumentData) -> StringName: return argument.arg_name),
		[&"service", &"enabled"],
		"コンストラクタで指定したメソッドだけを解析する",
	)
	_assert_matches_reflection(arguments, reflected_arguments)


func _test_argument_data_string() -> void:
	_runner.change_test_name("argument_data_string")
	var argument := ArgumentData.new(&"service", &"TestBaseService", TYPE_OBJECT)
	var description := str(argument)

	_runner.assert_true("service" in description, "文字列表現に引数名を含む")
	_runner.assert_true("TestBaseService" in description, "文字列表現にクラス名を含む")
	_runner.assert_true(str(TYPE_OBJECT) in description, "文字列表現に型番号を含む")
	_runner.assert_true(type_string(TYPE_OBJECT) in description, "文字列表現に型名を含む")


## MethodReaderを使って引数を取得
func _read(script: Script) -> Array[ArgumentData]:
	return MethodReader.new(Const.METHOD_NAME).get_injection_arguments(script)


## MethodReaderを使わないで引数を取得
func _get_reflected_arguments(script: Script, method_name: StringName) -> Array:
	for method: Dictionary in script.get_script_method_list():
		if StringName(method.get("name", "")) == method_name:
			return method.get("args", [])
	return []


## 2パターンで取得した引数情報を比較
func _assert_matches_reflection(arguments: Array[ArgumentData], reflected_arguments: Array) -> void:
	_runner.assert_equal(arguments.size(), reflected_arguments.size(), "リフレクションと同じ引数数を返す")
	
	for index in mini(arguments.size(), reflected_arguments.size()):
		var reflected: Dictionary = reflected_arguments[index]
		var reflected_class := StringName(reflected.get("class_name", ""))
		var reflected_type := int(reflected.get("type", TYPE_NIL))
		if reflected_class == &"":
			reflected_class = StringName(type_string(reflected_type))

		_runner.assert_equal(
			arguments[index].arg_name,
			StringName(reflected.get("name", "")),
			"arg_nameがGodotのメソッド情報と一致する: %s" % index,
		)
		_runner.assert_equal(
			arguments[index].arg_class,
			reflected_class,
			"arg_classがGodotのメソッド情報と一致する: %s" % index,
		)
		_runner.assert_equal(
			arguments[index].arg_type,
			reflected_type,
			"arg_typeがGodotのメソッド情報と一致する: %s" % index,
		)
