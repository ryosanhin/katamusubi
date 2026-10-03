extends RefCounted
## 注入対象と型オーバーライドを検証し、注入処理で利用できる形へ正規化する

const ArgumentEntry := preload("argument_entry.gd")
const ScriptTypeCompatibility := preload("../utility/script_type_compatibility.gd")


enum ErrorCode {
	OK,
	NULL_TARGET,
	FREED_TARGET,
	TARGET_OUTSIDE_TREE,
	MISSING_TARGET_SCRIPT,
	OVERRIDES_NOT_DICTIONARY,
	INVALID_OVERRIDE_KEY,
	UNKNOWN_ARGUMENT,
	NON_OBJECT_ARGUMENT,
	INVALID_OVERRIDE_SCRIPT,
	INCOMPATIBLE_OVERRIDE_TYPE,
}


## 最初の失敗理由と、説明文の生成に必要な補足情報。
class ValidationResult extends RefCounted:
	var code: ErrorCode = ErrorCode.OK
	var target_path: String
	var scope_name: StringName
	var argument_name: Variant
	var specified_value: Variant
	var expected_type: Script
	var argument_type: int = TYPE_NIL


	func is_valid() -> bool:
		return code == ErrorCode.OK


class TypeOverrideValidationResult extends ValidationResult:
	var overrides: Dictionary[StringName, Script] = {}


## 注入対象として必要な状態を検証する。
static func validate_target(target: Variant, scope_name: StringName) -> ValidationResult:
	var result := ValidationResult.new()
	result.scope_name = scope_name
	if typeof(target) == TYPE_NIL:
		result.code = ErrorCode.NULL_TARGET
		return result
	if not is_instance_valid(target):
		result.code = ErrorCode.FREED_TARGET
		return result
	if not target.is_inside_tree():
		result.target_path = str(target.name)
		result.code = ErrorCode.TARGET_OUTSIDE_TREE
		return result
	result.target_path = str(target.get_path())
	if target.get_script() == null:
		result.code = ErrorCode.MISSING_TARGET_SCRIPT
	return result


## 型オーバーライドを検証し、キーと値を厳密に型付けした辞書を返す
static func validate_type_overrides(
	target: Node,
	arguments: Array[ArgumentEntry],
	override_value: Variant,
) -> TypeOverrideValidationResult:
	var result := TypeOverrideValidationResult.new()
	result.target_path = str(target.get_path())
	if not override_value is Dictionary:
		result.code = ErrorCode.OVERRIDES_NOT_DICTIONARY
		result.argument_name = &"<判定不能>"
		result.specified_value = override_value
		return result

	# オーバーライド前の引数データを取得
	var declared_arguments_by_name: Dictionary[StringName, ArgumentEntry] = {}
	for argument in arguments:
		declared_arguments_by_name[argument.arg_name] = argument

	var validated_overrides: Dictionary[StringName, Script] = {}
	for override_key: Variant in override_value:
		# まず文字列系か確認
		# 一個でもルールに沿っていないものが存在したら結果を破棄
		if not (override_key is String or override_key is StringName):
			result.code = ErrorCode.INVALID_OVERRIDE_KEY
			result.argument_name = override_key
			result.specified_value = override_value[override_key]
			return result

		# 指定された引数名が存在するか確認
		# 一個でもルールに沿っていないものが存在したら結果を破棄
		var argument_name := StringName(override_key)
		if not declared_arguments_by_name.has(argument_name):
			result.code = ErrorCode.UNKNOWN_ARGUMENT
			result.argument_name = argument_name
			result.specified_value = override_value[override_key]
			return result

		# オーバーライド対象がオーバーライド可能なオブジェクト型か確認
		# 一個でもルールに沿っていないものが存在したら結果を破棄
		if not declared_arguments_by_name[argument_name].arg_type == TYPE_OBJECT:
			result.code = ErrorCode.NON_OBJECT_ARGUMENT
			result.argument_name = argument_name
			result.specified_value = override_value[override_key]
			result.argument_type = declared_arguments_by_name[argument_name].arg_type
			return result

		# 引数名に示された値がスクリプトであるか確認
		# 一個でもルールに沿っていないものが存在したら結果を破棄
		var specified_type: Variant = override_value[override_key]
		if not specified_type is Script:
			result.code = ErrorCode.INVALID_OVERRIDE_SCRIPT
			result.argument_name = argument_name
			result.specified_value = specified_type
			return result

		# もともと引数の型として定義されていたスクリプトと同一、または派生か確認
		# 一個でもルールに沿っていないものが存在したら結果を破棄
		var declared_type: Script = declared_arguments_by_name[argument_name].service_type
		if declared_type != null and not ScriptTypeCompatibility.is_same_or_derived_from(
			specified_type,
			declared_type,
		):
			result.code = ErrorCode.INCOMPATIBLE_OVERRIDE_TYPE
			result.argument_name = argument_name
			result.specified_value = specified_type
			result.expected_type = declared_type
			return result

		# 最後まで残った場合、引数名をキー、オーバーライド型を値として登録
		validated_overrides[argument_name] = specified_type

	result.overrides = validated_overrides
	return result


## 検証コードを人間向けの説明文へ変換する。検証処理自体は文字列に依存しない。
static func format_error(result: ValidationResult) -> String:
	match result.code:
		ErrorCode.OK:
			return ""
		ErrorCode.NULL_TARGET:
			return "対象が null です: スコープ名=%s" % result.scope_name
		ErrorCode.FREED_TARGET:
			return "対象は既に解放されています: スコープ名=%s" % result.scope_name
		ErrorCode.TARGET_OUTSIDE_TREE:
			return "対象はツリーに存在しません: 対象=%s, スコープ名=%s" % [result.target_path, result.scope_name]
		ErrorCode.MISSING_TARGET_SCRIPT:
			return "対象にスクリプトがありません: 対象=%s, スコープ名=%s" % [result.target_path, result.scope_name]

	var reason: String
	match result.code:
		ErrorCode.OVERRIDES_NOT_DICTIONARY:
			reason = "戻り値がDictionaryではありません"
		ErrorCode.INVALID_OVERRIDE_KEY, ErrorCode.UNKNOWN_ARGUMENT:
			reason = "存在しない引数名です"
		ErrorCode.NON_OBJECT_ARGUMENT:
			reason = "オーバーライド対象がオブジェクト型（24）ではありません"
		ErrorCode.INVALID_OVERRIDE_SCRIPT:
			reason = "指定値が有効なScriptではありません"
		ErrorCode.INCOMPATIBLE_OVERRIDE_TYPE:
			reason = "指定型が宣言型自身または派生型ではありません"
		_:
			return "不明な注入検証エラーです。"
	return "型オーバーライドの設定が不正です: %s, 対象=%s, 引数=%s, 指定値=%s" % [
		reason, result.target_path, result.argument_name, result.specified_value,
	]
