extends RefCounted
class_name InjectionContainer

const ResolveEntry := preload("resolve_entry.gd")
const ResolveEntryMap := preload("resolve_entry_map.gd")


class RegistrationRequestValidation extends RefCounted:
	var can_register: bool
	var error_message: String

	func _init(init_can_register: bool, init_error_message := "") -> void:
		can_register = init_can_register
		error_message = init_error_message

## 親スコープのコンテナです。このコンテナ内で見つからない依存を親へ問い合わせ
var _parent_container: InjectionContainer

## 公開型ごとのこのコンテナ内での登録コレクション
var _entry_maps_by_service_type: Dictionary[Script, ResolveEntryMap] = {}

var _has_registration_errors := false

## このコンテナで登録エラーが一度でも発生したか
var has_registration_errors: bool:
	get:
		return _has_registration_errors

## 任意の親コンテナを指定してスコープを生成
func _init(init_parent_container: InjectionContainer) -> void:
	_parent_container = init_parent_container


## 登録情報をローカルスコープへ追加し、登録できたかを返します。
func register(registration: ServiceRegistration) -> bool:
	var validation := _validate_registration_request(registration)
	if not validation.can_register:
		_has_registration_errors = true
		push_error(validation.error_message)
		return false

	_store_registration(registration)
	return true


## 登録要求を検証し、登録可否と失敗理由を返します。
func _validate_registration_request(
	registration: ServiceRegistration,
) -> RegistrationRequestValidation:
	if registration == null:
		return RegistrationRequestValidation.new(
			false,
			"登録情報が不正です:\nServiceRegistration に null は指定できません。",
		)

	var validation_errors := registration.validate()
	if not validation_errors.is_empty():
		return RegistrationRequestValidation.new(
			false,
			"登録情報が不正です:\n%s" % "\n".join(validation_errors),
		)

	if _entry_maps_by_service_type.has(registration.service_type):
		var entry_map: ResolveEntryMap = _entry_maps_by_service_type[registration.service_type]
		if entry_map.has(registration.key):
			return RegistrationRequestValidation.new(
				false,
				"登録が重複しています: 型=%s, id=%s" % [
					registration.service_name,
					_display_id(registration.key),
				],
			)

	return RegistrationRequestValidation.new(true)


## 検証済みの登録情報をローカルスコープへ格納します。
func _store_registration(registration: ServiceRegistration) -> void:
	if not _entry_maps_by_service_type.has(registration.service_type):
		_entry_maps_by_service_type[registration.service_type] = ResolveEntryMap.new()

	var entry_map: ResolveEntryMap = _entry_maps_by_service_type[registration.service_type]
	entry_map.register(registration.key, ResolveEntry.new(registration))


func resolve(
	service_type: Script,
	key: StringName,
) -> Variant:
	var resolve_entry: ResolveEntry = null

	if not key.is_empty():
		resolve_entry = find_resolve_entry(service_type, key)
	
	if resolve_entry == null:
		resolve_entry = find_resolve_entry(service_type, &"")

	if resolve_entry != null:
		return resolve_entry.resolve()

	push_error(
		"登録が見つかりません: 型=%s, id=%s" % [
			service_type.get_global_name(),
			_display_id(key),
		]
	)
	return null


func find_resolve_entry(
	service_type: Script,
	key: StringName,
) -> ResolveEntry:
	if _entry_maps_by_service_type.has(service_type):
		var entry_map := _entry_maps_by_service_type[service_type]
		if entry_map.has(key):
			return entry_map.find(key)

	if _parent_container != null:
		return _parent_container.find_resolve_entry(service_type, key)

	return null


## Singleton参照とローカル登録を解放します。
func clear() -> void:
	for entries: ResolveEntryMap in _entry_maps_by_service_type.values():
		entries.clear()
	_entry_maps_by_service_type.clear()
	_parent_container = null


## 空IDをログ上で判別しやすい文字列に変換
static func _display_id(id: StringName) -> String:
	return "<none>" if id.is_empty() else String(id)
