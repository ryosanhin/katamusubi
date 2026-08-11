extends RefCounted
class_name ServiceRegistration

var _service_type: Script
## 実際に生成するインスタンスのクラスのスクリプト
var service_type: Script:
	get:
		return _service_type

var _implementation_type: Script
## 注入先から参照される公開クラスのスクリプト
var implementation_type: Script:
	get:
		return _implementation_type

## 注入先から参照される契約型のクラス名
var implementation_name: StringName:
	get:
		return _implementation_type.get_global_name()

var _id: StringName = &""
## 同じ契約型を複数登録するときに利用する任意のID[br]
## 注入時に引数名として使う
var id: StringName:
	get:
		return _id

var _lifecycle: Lifecycle.Type = Lifecycle.Type.SINGLETON
## インスタンスの生成規則
var lifecycle: Lifecycle.Type:
	get:
		return _lifecycle

var _instance: Variant
## 外部インスタンス
var instance: Variant:
	get:
		return instance

## インスタンスを登録
static func create_instance_registration(
	type: Script,
) -> ServiceRegistration:
	var registration := ServiceRegistration.new()
	registration._service_type = type
	registration._implementation_type = type
	registration._lifecycle = Lifecycle.Type.SINGLETON
	return registration


## クラスを登録
static func create_class_registration(
	type: Script,
	lifecycle_type: Lifecycle.Type,
) -> ServiceRegistration:
	var registration := ServiceRegistration.new()
	registration._service_type = type
	registration._implementation_type = type
	registration._lifecycle = lifecycle_type
	return registration

## インスタンスのクラスを別の抽象型・基底型として公開
func convert_as(type: Script) -> ServiceRegistration:
	_implementation_type = type
	return self


## 登録へ任意のIDを付与
func with_id(new_id: StringName) -> ServiceRegistration:
	_id = new_id
	return self


## 登録情報に不備がないか検証し、問題一覧を返す
func validate() -> PackedStringArray:
	var errors := PackedStringArray()

	if _service_type == null:
		errors.append("生成するクラスが指定されていません。")
		return errors

	if _implementation_type == null:
		errors.append("公開するクラスが指定されていません。")
		return errors

	if not Lifecycle.is_valid(_lifecycle):
		errors.append("ライフサイクルが不正です: %s" % Lifecycle.to_display_name(_lifecycle))

	if _service_type.get_global_name().is_empty():
		errors.append("生成するクラスにはclass_nameが必要です: %s" % _service_type.resource_path)

	if _implementation_type.get_global_name().is_empty():
		errors.append("公開するクラスにはclass_nameが必要です: %s" % _implementation_type.resource_path)

	if not check_inheritance(_service_type, _implementation_type):
		errors.append(
			"生成するクラス %s は公開するクラス %s を継承していません。" % [
				_service_type.get_global_name(),
				_implementation_type.get_global_name(),
			]
		)

	return errors


## 生成するクラスが公開するクラス自身か派生型であるか調べる
static func check_inheritance(inherits: Script, inherited: Script) -> bool:
	var current: Script = inherits

	while current != null:
		if current == inherited:
			return true
		current = current.get_base_script()

	return false
