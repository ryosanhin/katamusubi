extends RefCounted
## 登録キーと外部Node参照を紐づけた辞書のラッパークラス

var _entries: Dictionary[StringName, Node] = {}


## 指定したキーの登録が存在するか調べます。Nodeの有効性は判定しません。
func has(key: StringName) -> bool:
	return _entries.has(key)


## 指定したキーで登録時のNode参照を保持します。
func register(key: StringName, instance: Node) -> void:
	_entries[key] = instance


## 指定したキーに対応するNode参照を返します。[br]
## 解放済み参照もそのまま返せるよう、戻り値はVariantにします。
func resolve(key: StringName) -> Variant:
	return _entries.get(key)


## 登録参照だけを解除します。Node自体は破棄しません。
func clear() -> void:
	_entries.clear()
