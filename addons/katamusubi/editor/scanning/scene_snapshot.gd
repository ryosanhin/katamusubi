@tool
extends RefCounted

## A successful scan may contain zero entries; failure is represented separately.
var succeeded: bool
var scene_uid: StringName
var entries: Array[ScopeSnapshot] = []
var error_message: String


func _init(init_succeeded: bool, init_scene_uid: StringName, init_entries: Array[ScopeSnapshot] = [], init_error := "") -> void:
	succeeded = init_succeeded
	scene_uid = init_scene_uid
	entries.assign(init_entries)
	error_message = init_error


func get_entries(scope_id: StringName) -> Array[ScopeSnapshot]:
	var matches: Array[ScopeSnapshot] = []
	for entry in entries:
		if entry.scope_id == scope_id:
			matches.append(entry)
	return matches
