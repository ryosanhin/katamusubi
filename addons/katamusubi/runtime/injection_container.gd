extends RefCounted

const ResolveEntry := preload("res://addons/katamusubi/runtime/resolve_entry.gd")
const ServiceRegistration := preload("res://addons/katamusubi/runtime/service_registration.gd")

## 親スコープのコンテナです。ローカルで見つからない依存を親へ問い合わせ
var _parent: RefCounted

## 「公開型class_name + ID」をキーにしたローカル登録
var _entries: Dictionary[String, ResolveEntry] = {}

## 任意の親コンテナを指定してスコープを生成
func _init(parent: RefCounted) -> void:
	_parent = parent


## 登録情報をローカルスコープへ追加
func register(registration: ServiceRegistration) -> void:
	var validation_errors := registration.validate()
	if not validation_errors.is_empty():
		var errors := "\n".join(validation_errors)
		push_error("登録情報が不正です:\n%s" % errors)
		return

	# 同じ契約型とIDの組み合わせは一意である必要
	var key := _make_key(registration.service_name, registration.key)
	if _entries.has(key):
		push_error(
			"登録が重複しています: 型=%s, id=%s" % [
				registration.service_name,
				_display_id(registration.key),
			]
		)
		return

	_entries[key] = ResolveEntry.new(registration)


func resolve_with_string_name(
	service_name: StringName,
	key: StringName,
) -> Variant:
	# 引数名などで明示されたKeyを最優先する
	if not key.is_empty():
		var keyed_entry_key := _make_key(service_name, key)
		if _entries.has(keyed_entry_key):
			return _entries[keyed_entry_key].resolve()

	# Key付き登録がなければ、このコンテナのデフォルト登録を利用する
	var default_entry_key := _make_key(service_name, &"")
	if _entries.has(default_entry_key):
		return _entries[default_entry_key].resolve()

	# ローカル登録を調べ終わった後に同じ解決条件を親へ引き継ぐ
	if _parent != null:
		return _parent.resolve_with_string_name(service_name, key)

	push_error(
		"登録が見つかりません: 型=%s, id=%s" % [
			service_name,
			_display_id(key),
		]
	)
	return null

## 公開型とIDに対応するインスタンスを解決
func resolve_with_script(
	service_type: Script,
	key: StringName = &"",
) -> Variant:
	var service_name := service_type.get_global_name()
	return resolve_with_string_name(service_name, key)


## Singleton参照とローカル登録を解放します。
func clear() -> void:
	for entry: ResolveEntry in _entries.values():
		entry.clear()
	_entries.clear()
	_parent = null


## 公開型とIDからDictionary用の一意キーを生成
static func _make_key(type_name: StringName, id: StringName) -> String:
	return "%s::%s" % [String(type_name), String(id)]


## 空IDをログ上で判別しやすい文字列に変換
static func _display_id(id: StringName) -> String:
	return "<none>" if id.is_empty() else String(id)
