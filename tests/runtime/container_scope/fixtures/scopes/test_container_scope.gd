extends ContainerScope
class_name ContainerScopeTestContainerScope

const BaseService := preload("../services/base_service.gd")
const DerivedService := preload("../services/derived_service.gd")

@export var registration_key: StringName = &""

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


func _register_instance(container: InjectionContainer) -> void:
	registration_count += 1
	registered_service = DerivedService.new()
	container.register(
		ServiceRegistration.create_instance_registration(
			registered_service,
			DerivedService,
		).as_type(BaseService).with_key(registration_key)
	)
