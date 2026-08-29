@tool
extends RefCounted

var removed: Array[StringName]
var retained: Array[StringName]
var added: Array[StringName]

func _init(
	init_removed: Array[StringName],
	init_retained: Array[StringName],
	init_added: Array[StringName],
) -> void:
	removed = init_removed
	retained = init_retained
	added = init_added
