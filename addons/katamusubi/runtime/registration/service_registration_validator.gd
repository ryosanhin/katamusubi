extends RefCounted

const ScriptTypeCompatibility := preload("../utility/script_type_compatibility.gd")

enum ErrorCode {
	OK,
	NULL_REGISTRATION,
	NULL_INSTANCE,
	INVALID_INSTANCE,
	MISSING_SCRIPT,
	MISSING_SERVICE_TYPE,
	INCOMPATIBLE_SERVICE_TYPE,
}


## 最初の失敗理由と、説明文の生成に必要な補足情報。
class ValidationResult extends RefCounted:
	var error_code: ErrorCode = ErrorCode.OK
	var actual_type_name: StringName
	var service_type_name: StringName


	func is_valid() -> bool:
		return error_code == ErrorCode.OK


## 登録情報に不備がないか検証し、最初に見つかった問題を返す
static func validate(registration: ServiceRegistration) -> ValidationResult:
	var result := ValidationResult.new()
	if registration == null:
		result.error_code = ErrorCode.NULL_REGISTRATION
		return result
	
	if registration.instance == null:
		result.error_code = ErrorCode.NULL_INSTANCE
		return result
		
	if not is_instance_valid(registration.instance):
		result.error_code = ErrorCode.INVALID_INSTANCE
		return result
	
	var actual_type: Script = registration.instance.get_script() as Script
	if actual_type == null:
		result.error_code = ErrorCode.MISSING_SCRIPT
		return result
	
	if registration.service_type == null:
		result.error_code = ErrorCode.MISSING_SERVICE_TYPE
		return result

	if not ScriptTypeCompatibility.is_same_or_derived_from(
			actual_type,
			registration.service_type,
	):
		result.error_code = ErrorCode.INCOMPATIBLE_SERVICE_TYPE
		result.actual_type_name = _get_displayable_name(actual_type)
		result.service_type_name = _get_displayable_name(registration.service_type)
		return result

	return result


## 検証結果を人間向けの説明文へ変換する
static func format_error(result: ValidationResult) -> String:
	match result.error_code:
		ErrorCode.OK:
			return ""
		ErrorCode.NULL_REGISTRATION:
			return "ServiceRegistration に null は指定できません。"
		ErrorCode.NULL_INSTANCE:
			return "登録インスタンスに null は指定できません。"
		ErrorCode.INVALID_INSTANCE:
			return "登録インスタンスが有効な Object ではありません。"
		ErrorCode.MISSING_SCRIPT:
			return "登録インスタンスにスクリプトがアタッチされていません。"
		ErrorCode.MISSING_SERVICE_TYPE:
			return "公開型が指定されていません。"
		ErrorCode.INCOMPATIBLE_SERVICE_TYPE:
			return "登録インスタンスの型 %s は公開型 %s と同一または派生型ではありません。" % [
					result.actual_type_name,
					result.service_type_name,
			]

	return "不明な登録検証エラーです。"


## 診断に利用できるスクリプト名を返す
static func _get_displayable_name(type: Script) -> String:
	if type == null:
		return "<不明>"
	var global_name := type.get_global_name()
	return global_name if not global_name.is_empty() else type.resource_path
