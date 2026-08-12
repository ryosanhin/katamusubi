extends RefCounted
class_name ResolveEntry

var _registration: ServiceRegistration

func _init(
	registration: ServiceRegistration
) -> void:
	_registration = registration

## ライフサイクルに従ってインスタンスを返す
func resolve():
	pass


## 登録情報と生成済みインスタンスへの参照を解放
func clear() -> void:
	_registration = null
