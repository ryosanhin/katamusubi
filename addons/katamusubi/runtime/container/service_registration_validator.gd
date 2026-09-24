extends RefCounted

const ScriptTypeCompatibility := preload("../utility/script_type_compatibility.gd")

enum ErrorCode {
	OK,
	NULL_REGISTRATION,
	NULL_INSTANCE,
	INVALID_INSTANCE,
	MISSING_SCRIPT,
	MISSING_IMPLEMENTATION_TYPE,
	INCOMPATIBLE_IMPLEMENTATION_TYPE,
	MISSING_SERVICE_TYPE,
	INCOMPATIBLE_SERVICE_TYPE,
}


## 登録情報に不備がないか検証し、最初に見つかった問題を返す
static func validate(registration: ServiceRegistration) -> ErrorCode:

	if registration == null:
		return ErrorCode.NULL_REGISTRATION
	
	if registration.instance == null:
		return ErrorCode.NULL_INSTANCE
		
	if not (registration.instance is Object) or not is_instance_valid(registration.instance):
		return ErrorCode.INVALID_INSTANCE
	
	var actual_type: Script = registration.instance.get_script() as Script
	if actual_type == null:
		return ErrorCode.MISSING_SCRIPT
	
	if registration.implementation_type == null:
		return ErrorCode.MISSING_IMPLEMENTATION_TYPE

	if not ScriptTypeCompatibility.is_same_or_derived_from(
			actual_type,
			registration.implementation_type,
	):
		return ErrorCode.INCOMPATIBLE_IMPLEMENTATION_TYPE
	
	if registration.service_type == null:
		return ErrorCode.MISSING_SERVICE_TYPE

	if not ScriptTypeCompatibility.is_same_or_derived_from(
			registration.implementation_type,
			registration.service_type,
	):
		return ErrorCode.INCOMPATIBLE_SERVICE_TYPE

	return ErrorCode.OK


## 検証結果を人間向けの説明文へ変換する
static func format_error(code: ErrorCode, registration: ServiceRegistration) -> String:
	match code:
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
		ErrorCode.MISSING_IMPLEMENTATION_TYPE:
			return "実装型が指定されていません。"
		ErrorCode.INCOMPATIBLE_IMPLEMENTATION_TYPE:
			var actual_type := _get_valid_instance_script(registration)
			var implementation_type := registration.implementation_type if registration != null else null
			return "登録インスタンスの型 %s は実装型 %s と同一または派生型ではありません。" % [
					_get_displayable_name(actual_type),
					_get_displayable_name(implementation_type),
			]
		ErrorCode.MISSING_SERVICE_TYPE:
			return "公開型が指定されていません。"
		ErrorCode.INCOMPATIBLE_SERVICE_TYPE:
			var implementation_type := registration.implementation_type if registration != null else null
			var service_type := registration.service_type if registration != null else null
			return "実装型 %s は公開型 %s と同一または派生型ではありません。" % [
					_get_displayable_name(implementation_type),
					_get_displayable_name(service_type),
			]

	return "不明な登録検証エラーです。"


## 有効な登録インスタンスにアタッチされたスクリプトを返す
static func _get_valid_instance_script(registration: ServiceRegistration) -> Script:
	if registration == null:
		return null
	if not (registration.instance is Object) or not is_instance_valid(registration.instance):
		return null
	return registration.instance.get_script() as Script


## 診断に利用できるスクリプト名を返す
static func _get_displayable_name(type: Script) -> String:
	if type == null:
		return "<不明>"
	var global_name := type.get_global_name()
	return global_name if not global_name.is_empty() else type.resource_path
