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


func _register_instance(container: InjectionContainer) -> bool:
	registration_count += 1
	registered_service = DerivedService.new()
	var succeeded := container.register(
		ServiceRegistration.create_instance_registration(
			registered_service,
			DerivedService,
		).as_type(BaseService).with_key(registration_key)
	)
	if add_invalid_registration:
		succeeded = container.register(ServiceRegistration.new()) and succeeded
	if add_duplicate_registration:
		succeeded = container.register(
			ServiceRegistration.create_instance_registration(
				DerivedService.new(),
				DerivedService,
			).as_type(BaseService).with_key(registration_key)
		) and succeeded
	if add_valid_registration_after_failure:
		succeeded = container.register(
			ServiceRegistration.create_instance_registration(
				DerivedService.new(),
				DerivedService,
			).as_type(BaseService).with_key(&"after_failure")
		) and succeeded
	return succeeded
