@tool
extends RefCounted

## 登録した依存オブジェクトの生成規則です。
enum Type {
	## コンテナ内で一度だけ生成し、以後は同じ参照を返します。
	SINGLETON,
	## 解決要求のたびに新しいインスタンスを生成します。
	TRANSIENT,
}


## 指定された値が利用可能なライフサイクルかを返します。
static func is_valid(value: int) -> bool:
	return value in Type.values()


## ライフサイクルをエラーメッセージ用の文字列へ変換します。
static func to_display_name(value: int) -> String:
	match value:
		Type.SINGLETON:
			return "SINGLETON"
		Type.TRANSIENT:
			return "TRANSIENT"
		_:
			return "UNKNOWN(%s)" % value
