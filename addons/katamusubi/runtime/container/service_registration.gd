extends RefCounted
class_name ServiceRegistration

const ServiceRegistrationValidator := preload("service_registration_validator.gd")

## 実際に生成するインスタンスのクラスのスクリプト
var implementation_type: Script

## 注入先から参照される公開クラスのスクリプト
var service_type: Script

## 同じ契約型を複数登録するときに利用する任意のID[br]
## 注入時に引数名として使う
var key: StringName = &""

## 外部インスタンス
var instance: Variant


## シーンに存在するインスタンスを登録
static func create_instance_registration(
		provided_instance: Variant,
) -> ServiceRegistration:
	var registration := ServiceRegistration.new()
	registration.instance = provided_instance
	if provided_instance != null:
		registration.implementation_type = provided_instance.get_script()
		registration.service_type = provided_instance.get_script()
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
