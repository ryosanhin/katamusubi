extends RefCounted
class_name InjectionContainer

const ResolveEntryMap := preload("resolve_entry_map.gd")
const RegistrationValidator := preload("../registration/service_registration_validator.gd")

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
	if not _validate_registration(registration):
		_has_registration_errors = true
		return false

	if not _entry_maps_by_service_type.has(registration.service_type):
		_entry_maps_by_service_type[registration.service_type] = ResolveEntryMap.new()

	var entry_map := _entry_maps_by_service_type[registration.service_type]

	entry_map.register(registration.key, registration.instance)
	return true


## 登録情報の検証
func _validate_registration(registration: ServiceRegistration) -> bool:
	var error_code := RegistrationValidator.validate(registration)
	if error_code != RegistrationValidator.ErrorCode.OK:
		var error_message := RegistrationValidator.format_error(error_code, registration)
		push_error("登録情報が不正です:\n%s" % error_message)
		return false

	# キーの存在確認
	# キーが存在しないときは重複確認の必要は無いのでtrueで早期リターン
	if not _entry_maps_by_service_type.has(registration.service_type):
		return true

	# 重複確認
	var entry_map := _entry_maps_by_service_type[registration.service_type]
	if entry_map.has(registration.key):
		push_error(
			"登録が重複しています: 型=%s, id=%s" % [
				registration.service_type.get_global_name(),
				_display_id(registration.key),
			]
		)
		return false
	
	return true


func resolve(
	service_type: Script,
	key: StringName,
) -> Variant:
	# キー一致を祖先まで検索した後、キーなしを祖先まで検索します。
	var lookup_keys: Array[StringName] = [key]
	if not key.is_empty():
		lookup_keys.append(&"")

	for lookup_key in lookup_keys:
		var container := self
		while container != null:
			if container._entry_maps_by_service_type.has(service_type):
				var entry_map := container._entry_maps_by_service_type[service_type]
				# 解放済みNodeも登録として扱い、別の登録へフォールバックしません。
				if entry_map.has(lookup_key):
					return entry_map.resolve(lookup_key)
			container = container._parent_container

	push_error(
		"登録が見つかりません: 型=%s, id=%s" % [
			service_type.get_global_name(),
			_display_id(key),
		]
	)
	return null


## ローカル登録と親コンテナ参照を解除します。Nodeや注入済み参照は破棄しません。
func clear() -> void:
	for entries: ResolveEntryMap in _entry_maps_by_service_type.values():
		entries.clear()
	_entry_maps_by_service_type.clear()
	_parent_container = null


## 空IDをログ上で判別しやすい文字列に変換
static func _display_id(id: StringName) -> String:
	return "<none>" if id.is_empty() else String(id)
