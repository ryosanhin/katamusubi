extends RefCounted
## 注入対象と型オーバーライドを検証し、注入処理で利用できる形へ正規化する

const ArgumentData := preload("argument_data.gd")
const ScriptTypeCompatibility := preload("../utility/script_type_compatibility.gd")


## 型オーバーライドの検証結果
class TypeOverrideValidationResult extends RefCounted:
	var overrides: Dictionary[StringName, Script] = {}
	var diagnostics := PackedStringArray()


	func is_valid() -> bool:
		return diagnostics.is_empty()


## 注入対象として必要な状態を検証する
static func validate_target(target: Variant, scope_name: StringName) -> PackedStringArray:
	var diagnostics := PackedStringArray()
	# 解放済みObjectもnullとの比較がtrueになるため、Variantの実型で未指定を判別する。
	if typeof(target) == TYPE_NIL:
		diagnostics.append("対象が null です: スコープ名=%s" % scope_name)
		return diagnostics

	if not is_instance_valid(target):
		diagnostics.append("対象は既に解放されています: スコープ名=%s" % scope_name)
		return diagnostics

	if not target.is_inside_tree():
		diagnostics.append(
			"対象はツリーに存在しません: 対象=%s, スコープ名=%s" % [target.name, scope_name]
		)
		return diagnostics

	if target.get_script() == null:
		diagnostics.append(
			"対象にスクリプトがありません: 対象=%s, スコープ名=%s"
			% [target.get_path(), scope_name]
		)

	return diagnostics


## 型オーバーライドを検証し、キーと値を厳密に型付けした辞書を返す
static func validate_type_overrides(
	target: Node,
	arguments: Array[ArgumentData],
	override_value: Variant,
) -> TypeOverrideValidationResult:
	var result := TypeOverrideValidationResult.new()
	if not override_value is Dictionary:
		result.diagnostics.append(
			_create_invalid_override_diagnostic(
				target,
				&"<判定不能>",
				override_value,
				"戻り値がDictionaryではありません",
			)
		)
		return result

	var argument_types: Dictionary[StringName, Script] = {}
	for argument in arguments:
		argument_types[argument.arg_name] = argument.service_type

	for override_key: Variant in override_value:
		# まず文字列系か確認
		# 一個でもルールに沿っていないものが存在したら結果を破棄
		if not (override_key is String or override_key is StringName):
			result.overrides.clear()
			result.diagnostics.append(
				_create_invalid_override_diagnostic(
					target,
					override_key,
					override_value[override_key],
					"存在しない引数名です",
				)
			)
			return result

		# 指定された引数名が存在するか確認
		# 一個でもルールに沿っていないものが存在したら結果を破棄
		var argument_name := StringName(override_key)
		if not argument_types.has(argument_name):
			result.overrides.clear()
			result.diagnostics.append(
				_create_invalid_override_diagnostic(
					target,
					argument_name,
					override_value[override_key],
					"存在しない引数名です",
				)
			)
			return result

		# 引数名に示されたスクリプトが存在するか確認
		# 一個でもルールに沿っていないものが存在したら結果を破棄
		var specified_type: Variant = override_value[override_key]
		if specified_type == null or not specified_type is Script:
			result.overrides.clear()
			result.diagnostics.append(
				_create_invalid_override_diagnostic(
					target,
					argument_name,
					specified_type,
					"指定値が有効なScriptではありません",
				)
			)
			return result

		# もともと引数の型として定義されていたスクリプトと同一、または派生か確認
		# 一個でもルールに沿っていないものが存在したら結果を破棄
		var declared_type: Script = argument_types[argument_name]
		if declared_type != null and not ScriptTypeCompatibility.is_same_or_derived_from(
			specified_type,
			declared_type,
		):
			result.overrides.clear()
			result.diagnostics.append(
				_create_invalid_override_diagnostic(
					target,
					argument_name,
					specified_type,
					"指定型が宣言型自身または派生型ではありません",
				)
			)
			return result

		# 最後まで残った場合、引数名をキー、オーバーライド型を値として登録
		result.overrides[argument_name] = specified_type

	return result


static func _create_invalid_override_diagnostic(
	target: Node,
	argument_name: Variant,
	specified_value: Variant,
	reason: String,
) -> String:
	return (
		"型オーバーライドの設定が不正です: %s, 対象=%s, 引数=%s, 指定値=%s"
		% [reason, target.get_path(), argument_name, specified_value]
	)
