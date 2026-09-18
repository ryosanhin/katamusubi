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
	return ServiceRegistrationValidator.validate(self)
