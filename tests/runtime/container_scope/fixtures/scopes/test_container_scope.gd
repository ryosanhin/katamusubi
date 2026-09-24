extends ContainerScope
class_name ContainerScopeTestContainerScope

const BaseService := preload("../services/base_service.gd")
const DerivedService := preload("../services/derived_service.gd")

@export var registration_key: StringName = &""
@export var add_invalid_registration := false
@export var add_duplicate_registration := false
@export var add_valid_registration_after_failure := false

var registration_count := 0
var registered_service: ContainerScopeTestDerivedService
var _registered_services: Array[Node] = []


func initialize_for_test() -> bool:
	return _initialize_scope()


func has_container() -> bool:
	return _container != null


func resolve_for_test(service_type: Script, key: StringName = &"") -> Variant:
	if _container == null:
		return null
	return _container.resolve(service_type, key)


func parent_container_for_test() -> InjectionContainer:
	if _container == null:
		return null
	return _container._parent_container


func _exit_tree() -> void:
	super()
	for service in _registered_services:
		if is_instance_valid(service):
			service.free()
	_registered_services.clear()
	registered_service = null


func _register_instance(container: InjectionContainer) -> void:
	registration_count += 1
	registered_service = DerivedService.new()
	_registered_services.append(registered_service)
	container.register(
			ServiceRegistration.create_instance_registration(
					registered_service,
			).as_type(BaseService).with_key(registration_key)
	)
	if add_invalid_registration:
		container.register(ServiceRegistration.new())
	if add_duplicate_registration:
		var duplicate_service := DerivedService.new()
		_registered_services.append(duplicate_service)
		container.register(
				ServiceRegistration.create_instance_registration(
						duplicate_service,
				).as_type(BaseService).with_key(registration_key)
		)
	if add_valid_registration_after_failure:
		var service_after_failure := DerivedService.new()
		_registered_services.append(service_after_failure)
		container.register(
				ServiceRegistration.create_instance_registration(
						service_after_failure,
				).as_type(BaseService).with_key(&"after_failure")
		)
