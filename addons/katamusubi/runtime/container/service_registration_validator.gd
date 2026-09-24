extends RefCounted

const ScriptTypeCompatibility := preload("../utility/script_type_compatibility.gd")

## 登録情報に不備がないか検証し、問題一覧を返す
static func validate(registration: ServiceRegistration) -> PackedStringArray:
	var errors := PackedStringArray()

	if registration == null:
		errors.append("ServiceRegistration に null は指定できません。")
		return errors

	if registration.instance == null:
		errors.append("外部インスタンスに null は指定できません。")
		return errors

	if not (registration.instance is Object) or not is_instance_valid(registration.instance):
		errors.append("外部インスタンスが有効な Object ではありません。")
		return errors

	var actual_type: Script = registration.instance.get_script() as Script
	if actual_type == null:
		errors.append("外部インスタンスにスクリプトがアタッチされていません。")
		return errors

	if registration.implementation_type == null:
		errors.append("生成するクラスが指定されていません。")
		return errors

	if registration.service_type == null:
		errors.append("公開するクラスが指定されていません。")
		return errors

	if not ScriptTypeCompatibility.is_same_or_derived_from(
			actual_type,
			registration.implementation_type,
	):
		errors.append(
			"外部インスタンスの型が登録型と互換性がありません: 実際の型=%s, 指定された実装型=%s, 公開型=%s" % [
				_get_displayable_name(actual_type),
				_get_displayable_name(registration.implementation_type),
				_get_displayable_name(registration.service_type),
			]
		)
		return errors

	if not ScriptTypeCompatibility.is_same_or_derived_from(
			registration.implementation_type,
			registration.service_type,
	):
		errors.append(
			"生成するクラス %s は公開するクラス %s を継承していません（指定された実装型=%s, 公開型=%s）。" % [
				_get_displayable_name(registration.implementation_type),
				_get_displayable_name(registration.service_type),
				_get_displayable_name(registration.implementation_type),
				_get_displayable_name(registration.service_type),
			]
		)
		return errors

	return errors


## 診断に利用できるスクリプト名を返す
static func _get_displayable_name(type: Script) -> String:
	var global_name := type.get_global_name()
	return global_name if not global_name.is_empty() else type.resource_path
