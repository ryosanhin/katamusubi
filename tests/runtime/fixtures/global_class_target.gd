extends Node

var injected_service: InjectionTestGlobalService


func inject_dependency(service: InjectionTestGlobalService) -> void:
	injected_service = service
