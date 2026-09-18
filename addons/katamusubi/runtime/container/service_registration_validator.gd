extends RefCounted
class_name ServiceRegistrationValidator


## 登録情報に不備がないか検証し、問題一覧を返す
static func validate(registration: ServiceRegistration) -> PackedStringArray:
	var errors := PackedStringArray()

	if registration == null:
		errors.append("ServiceRegistration に null は指定できません。")
		return errors

	if registration.implementation_type == null:
		errors.append("生成するクラスが指定されていません。")
		return errors

	if registration.service_type == null:
		errors.append("公開するクラスが指定されていません。")
		return errors

	if registration._is_instance_registration:
		if registration.instance == null:
			errors.append("外部インスタンスに null は指定できません。")
			return errors

		if not (registration.instance is Object) or not is_instance_valid(registration.instance):
			errors.append("外部インスタンスが有効な Object ではありません。")
			return errors

		var actual_type: Script = registration.instance.get_script()
		if actual_type == null:
			errors.append("外部インスタンスにスクリプトがアタッチされていません。")
			return errors

		if not _check_inheritance(actual_type, registration.implementation_type) \
				or not _check_inheritance(actual_type, registration.service_type):
			errors.append(
				"外部インスタンスの型が登録型と互換性がありません: 実際の型=%s, 指定された実装型=%s, 公開型=%s" % [
					_get_displayable_name(actual_type),
					_get_displayable_name(registration.implementation_type),
					_get_displayable_name(registration.service_type),
				]
			)

	if not Lifecycle.is_valid(registration.lifecycle):
		errors.append("ライフサイクルが不正です: %s" % Lifecycle.to_display_name(registration.lifecycle))

	if not _check_inheritance(registration.implementation_type, registration.service_type):
		errors.append(
			"生成するクラス %s は公開するクラス %s を継承していません。" % [
				registration.implementation_type.get_global_name(),
				registration.service_type.get_global_name(),
			]
		)

	return errors


## 診断に利用できるスクリプト名を返す
static func _get_displayable_name(type: Script) -> String:
	var global_name := type.get_global_name()
	return global_name if not global_name.is_empty() else type.resource_path


## 生成するクラスが公開するクラス自身か派生型であるか調べる[br]
## [param inherits]: サブクラス[br]
## [param inherited]: スーパークラス
static func _check_inheritance(inherits: Script, inherited: Script) -> bool:
	var current: Script = inherits

	while current != null:
		if current == inherited:
			return true
		current = current.get_base_script()

	return false
