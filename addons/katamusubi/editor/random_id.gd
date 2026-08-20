@tool
extends RefCounted
## ランダムでIDを生成するクラス

const CHARS := "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

const UID_LENGTH := 8

static func get_random_id() -> String:
	var str_list: PackedStringArray = []
	var max_index := CHARS.length()-1
	for i in UID_LENGTH:
		var index := randi_range(0, max_index)
		str_list.append(CHARS[index])
	
	return "".join(str_list)
