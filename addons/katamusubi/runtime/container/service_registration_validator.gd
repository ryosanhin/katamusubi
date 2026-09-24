extends RefCounted

const ScriptTypeCompatibility := preload("../utility/script_type_compatibility.gd")
const ValidationError := preload("service_registration_validation_error.gd")

## 登録情報に不備がないか検証し、従来APIとの互換性のため表示文言の一覧を返す
static func validate(registration: ServiceRegistration) -> PackedStringArray:
	var messages := PackedStringArray()
	for error: ServiceRegistrationValidationError in validate_structured(registration):
		messages.append(error.message)
	return messages


## 登録情報に不備がないか検証し、コードと表示文言を持つ問題一覧を返す
static func validate_structured(
		registration: ServiceRegistration,
) -> Array[ServiceRegistrationValidationError]:
	var errors: Array[ServiceRegistrationValidationError] = []

	if registration == null:
		errors.append(ValidationError.new(
				ValidationError.Code.NULL_REGISTRATION,
				"ServiceRegistration に null は指定できません。",
		))
		return errors

	if registration.instance == null:
		errors.append(ValidationError.new(
				ValidationError.Code.NULL_INSTANCE,
				"インスタンスに null は指定できません。",
		))
		return errors

	if not (registration.instance is Object) or not is_instance_valid(registration.instance):
		errors.append(ValidationError.new(
				ValidationError.Code.INVALID_INSTANCE,
				"インスタンスが有効な Object ではありません。",
		))
		return errors

	var actual_type: Script = registration.instance.get_script() as Script
	if actual_type == null:
		errors.append(ValidationError.new(
				ValidationError.Code.MISSING_INSTANCE_SCRIPT,
				"インスタンスにスクリプトがアタッチされていません。",
		))
		return errors

	if registration.implementation_type == null:
		errors.append(ValidationError.new(
				ValidationError.Code.MISSING_IMPLEMENTATION_TYPE,
				"生成するクラスが指定されていません。",
		))
		return errors

	if not ScriptTypeCompatibility.is_same_or_derived_from(
			actual_type,
			registration.implementation_type,
	):
		errors.append(ValidationError.new(
				ValidationError.Code.INCOMPATIBLE_IMPLEMENTATION_TYPE,
				"生成するインスタンスはスクリプト %s を実装していません。"
				% _get_displayable_name(registration.implementation_type),
		))
		return errors

	if registration.service_type == null:
		errors.append(ValidationError.new(
				ValidationError.Code.MISSING_SERVICE_TYPE,
				"公開するクラスが指定されていません。",
		))
		return errors

	if not ScriptTypeCompatibility.is_same_or_derived_from(
			registration.implementation_type,
			registration.service_type,
	):
		errors.append(ValidationError.new(
				ValidationError.Code.INCOMPATIBLE_SERVICE_TYPE,
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
