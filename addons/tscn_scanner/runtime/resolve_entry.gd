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