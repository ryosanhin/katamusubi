extends RefCounted
class_name ServiceRegistration

## 実際に生成するインスタンスのクラスのスクリプト
var implementation_type: Script

## 注入先から参照される公開クラスのスクリプト
var service_type: Script

## 注入先から参照される契約型のクラス名
var service_name: StringName:
	get:
		return service_type.get_global_name()

## 同じ契約型を複数登録するときに利用する任意のID[br]
## 注入時に引数名として使う
var key: StringName = &""

## インスタンスの生成規則
var lifecycle: Lifecycle.Type = Lifecycle.Type.SINGLETON

## 外部インスタンス
var instance: Variant

## 外部インスタンスを利用する登録かどうか
var _is_instance_registration := false

## シーンに存在するインスタンスを登録
static func create_instance_registration(
	provided_instance: Variant,
	type: Script,
) -> ServiceRegistration:
	var registration := ServiceRegistration.new()
	registration.instance = provided_instance
	registration._is_instance_registration = true
	registration.implementation_type = type
	registration.service_type = type
	registration.lifecycle = Lifecycle.Type.SINGLETON
	return registration


## クラスを登録
static func create_class_registration(
	type: Script,
	lifecycle_type: Lifecycle.Type,
) -> ServiceRegistration:
	var registration := ServiceRegistration.new()
	registration.implementation_type = type
	registration.service_type = type
	registration.lifecycle = lifecycle_type
	return registration

## インスタンスのクラスを別の抽象型・基底型として公開
func as_type(new_service_type: Script) -> ServiceRegistration:
	service_type = new_service_type
	return self


## 登録へ任意のIDを付与
func with_key(new_key: StringName) -> ServiceRegistration:
	key = new_key
	return self


## 登録情報に不備がないか検証し、問題一覧を返す
func validate() -> PackedStringArray:
	var errors := PackedStringArray()

	if implementation_type == null:
		errors.append("生成するクラスが指定されていません。")
		return errors

	if service_type == null:
		errors.append("公開するクラスが指定されていません。")
		return errors

	if _is_instance_registration:
		if instance == null:
			errors.append("外部インスタンスに null は指定できません。")
			return errors

		if not (instance is Object) or not is_instance_valid(instance):
			errors.append("外部インスタンスが有効な Object ではありません。")
			return errors

		var actual_type: Script = instance.get_script()
		if actual_type == null:
			errors.append("外部インスタンスにスクリプトがアタッチされていません。")
			return errors

		if not _check_inheritance(actual_type, implementation_type) \
				or not _check_inheritance(actual_type, service_type):
			errors.append(
				"外部インスタンスの型が登録型と互換性がありません: 実際の型=%s, 指定された実装型=%s, 公開型=%s" % [
					_display_script_name(actual_type),
					_display_script_name(implementation_type),
					_display_script_name(service_type),
				]
			)

	if not Lifecycle.is_valid(lifecycle):
		errors.append("ライフサイクルが不正です: %s" % Lifecycle.to_display_name(lifecycle))

	if not _check_inheritance(implementation_type, service_type):
		errors.append(
			"生成するクラス %s は公開するクラス %s を継承していません。" % [
				implementation_type.get_global_name(),
				service_type.get_global_name(),
			]
		)

	return errors


## 診断に利用できるスクリプト名を返す
func _display_script_name(type: Script) -> String:
	var global_name := type.get_global_name()
	return global_name if not global_name.is_empty() else type.resource_path


## 生成するクラスが公開するクラス自身か派生型であるか調べる[br]
## [param inherits]: サブクラス[br]
## [param inherited]: スーパークラス
func _check_inheritance(inherits: Script, inherited: Script) -> bool:
	var current: Script = inherits

	while current != null:
		if current == inherited:
			return true
		current = current.get_base_script()

	return false
