extends RefCounted

const ScriptTypeCompatibility := preload("../utility/script_type_compatibility.gd")

## 登録検証エラーを、表示文言に依存せず識別するための安定したコードです。
enum Code {
	NULL_REGISTRATION,
	NULL_INSTANCE,
	INVALID_INSTANCE,
	MISSING_INSTANCE_SCRIPT,
	MISSING_IMPLEMENTATION_TYPE,
	INCOMPATIBLE_IMPLEMENTATION_TYPE,
	MISSING_SERVICE_TYPE,
	INCOMPATIBLE_SERVICE_TYPE,
}

## 登録検証エラーのコードと診断用メッセージを保持します。
class ValidationError:
	var code: Code
	var message: String

	func _init(init_code: Code, init_message: String) -> void:
		code = init_code
		message = init_message

## 登録情報に不備がないか検証し、従来APIとの互換性のため表示文言の一覧を返す
static func validate(registration: ServiceRegistration) -> PackedStringArray:
	var messages := PackedStringArray()
	for error: ValidationError in validate_structured(registration):
		messages.append(error.message)
	return messages


## 登録情報に不備がないか検証し、コードと表示文言を持つ問題一覧を返す
static func validate_structured(
		registration: ServiceRegistration,
) -> Array[ValidationError]:
	var errors: Array[ValidationError] = []

	if registration == null:
		errors.append(ValidationError.new(
				Code.NULL_REGISTRATION,
				"ServiceRegistration に null は指定できません。",
		))
		return errors

	if registration.instance == null:
		errors.append(ValidationError.new(
				Code.NULL_INSTANCE,
				"インスタンスに null は指定できません。",
		))
		return errors

	if not (registration.instance is Object) or not is_instance_valid(registration.instance):
		errors.append(ValidationError.new(
				Code.INVALID_INSTANCE,
				"インスタンスが有効な Object ではありません。",
		))
		return errors

	var actual_type: Script = registration.instance.get_script() as Script
	if actual_type == null:
		errors.append(ValidationError.new(
				Code.MISSING_INSTANCE_SCRIPT,
				"インスタンスにスクリプトがアタッチされていません。",
		))
		return errors

	if registration.implementation_type == null:
		errors.append(ValidationError.new(
				Code.MISSING_IMPLEMENTATION_TYPE,
				"生成するクラスが指定されていません。",
		))
		return errors

	if not ScriptTypeCompatibility.is_same_or_derived_from(
			actual_type,
			registration.implementation_type,
	):
		errors.append(ValidationError.new(
				Code.INCOMPATIBLE_IMPLEMENTATION_TYPE,
				"生成するインスタンスはスクリプト %s を実装していません。"
				% _get_displayable_name(registration.implementation_type),
		))
		return errors

	if registration.service_type == null:
		errors.append(ValidationError.new(
				Code.MISSING_SERVICE_TYPE,
				"公開するクラスが指定されていません。",
		))
		return errors

	if not ScriptTypeCompatibility.is_same_or_derived_from(
			registration.implementation_type,
			registration.service_type,
	):
		errors.append(ValidationError.new(
				Code.INCOMPATIBLE_SERVICE_TYPE,
				"生成するクラス %s は公開型 %s を継承していません。" % [
					_get_displayable_name(registration.implementation_type),
					_get_displayable_name(registration.service_type),
				],
		))

	return errors


## 診断に利用できるスクリプト名を返す
static func _get_displayable_name(type: Script) -> String:
	var global_name := type.get_global_name()
	return global_name if not global_name.is_empty() else type.resource_path
