extends RefCounted
## インスタンス生成のための情報

const Lifecycle := preload("res://addons/katamusubi/runtime/lifecycle.gd")
const ServiceRegistration := preload("res://addons/katamusubi/runtime/service_registration.gd")

var _registration: ServiceRegistration
var _singleton_instance: Variant

func _init(
	registration: ServiceRegistration
) -> void:
	_registration = registration

## ライフサイクルに従ってインスタンスを返す
func resolve() -> Variant:
	if _registration.instance != null:
		return _registration.instance

	if _registration.lifecycle == Lifecycle.Type.SINGLETON:
		if _singleton_instance == null:
			_singleton_instance = _registration.implementation_type.new()
		return _singleton_instance

	return _registration.implementation_type.new()


## 登録情報と生成済みインスタンスへの参照を解放
func clear() -> void:
	_singleton_instance = null
	_registration = null
