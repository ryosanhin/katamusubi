extends RefCounted

var _registration: ServiceRegistration

func _init(
	registration: ServiceRegistration
) -> void:
	_registration = registration

## インスタンスを返す
func resolve() -> Variant:
	return _registration.instance


## 登録情報と生成済みインスタンスへの参照を解放
func clear() -> void:
	_registration = null
