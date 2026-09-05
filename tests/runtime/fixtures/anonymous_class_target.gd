extends Node

const AnonymousService := preload("anonymous_service.gd")

var injected_service: AnonymousService


func inject_dependency(service: AnonymousService) -> void:
	injected_service = service


func get_inject_type_overrides() -> Dictionary[StringName, Script]:
	return {&"service": AnonymousService}
