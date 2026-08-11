extends RefCounted
class_name InjectionContainer

## 親スコープのコンテナです。ローカルで見つからない依存を親へ問い合わせ
var _parent: InjectionContainer

## 「公開型class_name + ID」をキーにしたローカル登録
var _entries: Dictionary = {}

## 登録時に検出した問題です。エディタ警告と実行時エラーに利用
var _registration_errors := PackedStringArray()

## 任意の親コンテナを指定してスコープを生成
func _init(parent: InjectionContainer) -> void:
	_parent = parent


## 登録情報をローカルスコープへ追加
func register(profile: InjectionProfile) -> void:
	# 同じ契約型とIDの組み合わせは一意である必要
	var key := _make_key(profile.implementation_name, profile.id)
	if _entries.has(key):
		push_error(
			"登録が重複しています: 型=%s, id=%s" % [
				profile.implementation_name,
				_display_id(profile.id),
			]
		)
		return

	_entries[key] = profile.implementation_type


## Singleton参照とローカル登録を解放します。
func clear() -> void:
	for entry in _entries.values():
		(entry as ServiceEntry).clear()
	_entries.clear()
	_parent = null


## 公開型とIDからDictionary用の一意キーを生成
static func _make_key(type_name: StringName, id: StringName) -> String:
	return "%s::%s" % [String(type_name), String(id)]


## 空IDをログ上で判別しやすい文字列に変換
static func _display_id(id: StringName) -> String:
	return "<none>" if id.is_empty() else String(id)