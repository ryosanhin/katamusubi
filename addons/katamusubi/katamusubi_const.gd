@tool
extends RefCounted
class_name Katamusubi

#region クラス定義
const ArgumentData := preload(
		"res://addons/katamusubi/runtime/argument_data.gd"
)

const Lifecycle := preload(
		"res://addons/katamusubi/runtime/lifecycle.gd"
)

const ScopeDefinition := preload(
		"res://addons/katamusubi/runtime/scope_definition.gd"
)

const ScopeDefinitionList := preload(
		"res://addons/katamusubi/runtime/scope_definition_list.gd"
)

const MethodReader := preload(
		"res://addons/katamusubi/runtime/method_reader.gd"
)

const ServiceRegistration := preload(
		"res://addons/katamusubi/runtime/service_registration.gd"
)

const ResolveEntry := preload(
		"res://addons/katamusubi/runtime/resolve_entry.gd"
)

const InjectionContainer := preload(
		"res://addons/katamusubi/runtime/injection_container.gd"
)


const InstanceInjector := preload(
		"res://addons/katamusubi/runtime/instance_injector.gd"
)

const ContainerScope := preload(
		"res://addons/katamusubi/runtime/container_scope.gd"
)

#endregion

#region プロパティ
const DEFINITION_LIST_PATH := "res://addons/katamusubi/scope_definition_list.tres"

const DEFINITION_LIST := preload(DEFINITION_LIST_PATH)  

#endregion

class Editor extends RefCounted:
	const ContainerScopeInspectorPlugin := preload(
			"res://addons/katamusubi/editor/container_scope_inspector_plugin.gd"
	)

	const RandomID := preload(
			"res://addons/katamusubi/editor/random_id.gd"
	)
	
	const RollbackAction := preload(
			"res://addons/katamusubi/editor/rollback_action.gd"
	)

	const TscnScanner := preload(
			"res://addons/katamusubi/editor/tscn_scanner.gd"
	)
