@tool
extends RefCounted
class_name RandomID

const chars := "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

static func get_random_id(length: int) -> String:
	var str_list: PackedStringArray = []
	var max_index := chars.length()-1
	for i in length:
		var index := randi_range(0, max_index)
		str_list.append(chars[index])
	
	return "".join(str_list)
